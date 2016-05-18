
var wsproto;
var wssequence = 1;
var wscallback = [];

var pages = [];


function switchToLoginView()
{
	document.getElementById("divMain").innerHTML = "";

	webix.ui({
		id: "loginView",
		container: "divMain",
		view: 'window',
		hidden: false,
		head: "Вход в личный кабинет",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "loginForm",
			width: 300,
			elements: [
				{view: 'text', label: 'Логин', name: 'login'},
				{view: 'text', label: 'Пароль', name: 'password', type: 'password', id: 'inputPassword'},
				{
					view: "button",
					value: "Войти",
					width: 150,
					align: "center",
					click: doLogin
				}
			]
		}
	});

	webix.extend($$("loginView"), webix.ProgressBar);
	webix.UIManager.addHotKey("enter", doLogin, $$("inputPassword"));
	
	$$("loginForm").setValues({login: '', password: ''});
	webix.UIManager.setFocus($$("loginForm"));
}

function switchToMainView()
{
	document.getElementById("divMain").innerHTML = "";

	webix.ui({
		id: "mainView",
		container: "divMain",
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: "label",
				label: "Личный кабинет"
			},{},{
				view: "button",
				id: "userFullName",
				type: "icon",
				icon: "angle-down",
				label: "Пользователь",
				width: 150,
				click: function() {
				}
			},{
				view: "button",
				type: "icon",
				icon: "sign-out",
				label: "Выход",
				width: 100,
				click: function() {
					ws.close();
				}
			}]
		},{
			cols: [{
				view: "tree",
				id: "sidebar",
				width: 200,
				type: "menuTree2",
				css: "menu",
				activeTitle: true,
				select: true,
				on: {
					onBeforeSelect: function(id) {
						if(this.getItem(id).$count) {
							return false;
						}
					},
					onAfterSelect: function(id) {
						if (pages[id] != undefined) {
							var pageui = webix.ui(pages[id].def, $$("panel"));
							pages[id].oncreate(pageui);
						}
					}
				},
				data: [{
					id: "user",
					value: "Абонент",
					open: true,
					data: [{
						id: "user-home",
						value: "Главная",
						icon: "home",
					}]
				}]
			},{
				id: "panel",
				template: ""
			}]
		}]
	});
	
	$$("sidebar").select("user-home");
}

function wsSendMessage(data, callback)
{
	data.sequence = wssequence++;
	if (callback) {
		wscallback.push({sequence: data.sequence, func: callback});
	}

	var msg = new wsproto.ClientMessage(data);
	var buf = msg.encode();
	ws.send(buf.toArrayBuffer());
}

function wsCreate()
{
	ws = new WebSocket(cfgServerURL);
	ws.binaryType = 'arraybuffer';
	ws.onopen = wsOpen;
	ws.onclose = wsClose;
	ws.onmessage = wsMessage;
}

function wsOpen()
{
	wsSendMessage({
		'loginrequest': $$("loginForm").getValues()
	});
}

function wsClose()
{
	$$("loginView").hideProgress();
	switchToLoginView();
	webix.message("Соединение с сервером прервано.");
}

function wsMessage(evt)
{
	var msg = wsproto.ServerMessage.decode(evt.data);

	$$("loginView").hideProgress();
	
	if (msg.sequence) {
		for (var i in wscallback) {
			if (wscallback[i].sequence == msg.sequence) {
				wscallback[i].func(msg);
				wscallback.splice(i, 1);
				break;
			}
		}
	}

	if (msg.error) {
		var txt = "Ошибка " + msg.error.code;
		if (msg.error.message) txt = txt + "<br/>" + msg.error.message;
		webix.message(txt);
		
		if (msg.error.fatal) {
			ws.close();
			return;
		}
	}

	if (msg.loginresponse) {
		if (msg.loginresponse.status == 0) {
			webix.message("Неверный логин или пароль.");
			ws.close();
			return;
		}
		switchToMainView();

		return;
	}

}

function parseSelectResponse(resp)
{
	var res = [];

	var colcount = resp.columns.length;
	var row = 0;
	for (var i in resp.data) {
		if ((i % colcount) == 0) row++;
		if (res[row-1] == undefined) res[row-1] = {};
		res[row-1][resp.columns[i % colcount]] = resp.data[i];
	}

	return res;
}

function doLogin()
{
	$$("loginView").showProgress();
	wsCreate();
}

function doAccountPay(account)
{
	webix.ui({
		view: 'window',
		hidden: false,
		head: "Пополнить счет",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "yandexForm",
			width: 300,
			elements: [
				{view: 'text', label: 'Сумма платежа', labelPosition: 'top', name: 'sum'},
				{
					view: "button",
					value: "Оплатить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("yandexForm").getValues();
						p.customerNumber = account;
						p.shopId = cfgYandexShopId;
						p.scid = cfgYandexScid;
						webix.send("https://money.yandex.ru/eshop.xml", p);
					}
				}
			]
		}
	});

	$$("loginForm").setValues({sum: ''});
	webix.UIManager.setFocus($$("yandexForm"));
}

function doAccountPromise(account_id)
{
	webix.confirm({
		title: "Обещанный платеж",
		ok: "Да",
		cancel: "Нет",
		text: "Отправить заявку на обещанный платеж?",
		callback: function(result) {
			if (!result) return;
			wsSendMessage({
				functionrequest: {
					name: 'account_promise_payment',
					params: [{i: parseInt(account_id)}]
				}
			}, function(resp) {
				webix.alert("Ваша заявка на обещанный платеж зарегистрирована.");
			});
		}
	});
}

function init()
{
	var wsprotofile = dcodeIO.ProtoBuf.loadProtoFile("wsproto.proto?r=" + Math.random(), function(err, builder) {
		wsproto = builder.build("WSPROTO");
	});
	
	webix.type(webix.ui.tree, {
		name:"menuTree2",
		height: 40,

		icon:function(obj, common) {
			var html = "";
			var open = "";
			for (var i=1; i<=obj.$level; i++){
				if (i==obj.$level && obj.$count){
					var dir = obj.open?"down":"right";
					html+="<span class='"+open+" webix_icon fa-angle-"+dir+"'></span>";
			    }
			}
			return html;
		},
		folder:function(obj, common){
			if(obj.icon)
				return "<span class='webix_icon icon fa-"+obj.icon+"'></span>";
			return "";
		}
	});

	var page = function(name, def, oncreate) {
		def.id = "panel";
		pages[name] = {name: name, def: def, oncreate: oncreate};
	}
	
	/* Home page */
	
	page("user-home", {
		rows: [{
			template: "<div class='page-header'>Главная</div>",
			autoheight: true
		},{
			type: "space",
			id: "user-home-list",
			rows: []
		},{}]
	}, function() {
		wsSendMessage({
			selectrequest: {
				table: "accounts"
			}
		}, function(resp) {
			var accounts = parseSelectResponse(resp.selectresponse);
			
			wsSendMessage({
				selectrequest: {
					table: "services"
				}
			}, function(resp) {
				var services = parseSelectResponse(resp.selectresponse);
				
				for (var a in accounts) {
					// Account header
					$$("user-home-list").addView({
						rows: [{
							autoheight: true,
							data: accounts[a],
							template: function(data) {
								var html = "<span class='webix_icon fa-rub'></span>Лицевой счёт № " + data.account_number +
									"<div class='balance'>" + data.balance + "</div>" +
									"<div class='balance-desc'>Баланс, руб.</div>" +
									"<div class='buttons'>" +
									"<a class='button' href='javascript:doAccountPay(\"" + data.account_number + "\");'><span class='webix_icon fa-plus'></span>Пополнить счет</a>" +
									"<a class='button' href='javascript:doAccountPromise(\"" + data.account_id + "\");'><span class='webix_icon fa-plus-square'></span>Обещанный платеж</a>" +
									"</div>";
								return html;
							}
						}]
					});
					
					for (var s in services) {
						if (services[s].account_id == accounts[a].account_id) {
							// Service
							$$("user-home-list").addView({
								rows: [{
									autoheight: true,
									data: services[s],
									template: function(data) {
										var icon = "check";
										if (data.service_state != 1) icon = "close";
										var state = "<span class='webix_icon fa-" + icon + " service-state-" + data.service_state + "'></span>" +
											"<span class='service-state-" + data.service_state + "'>" + data.service_state_name + "</span>";
										return "<span class='webix_icon fa-globe'></span>Доступ в интернет (" + data.service_name + ")" +
											"<div style='float: right;'>" + state + "</div>";
									}
								},{
									autoheight: true,
									data: services[s],
									template: function(data) {
										var s = "";
										if (data.postaddr != "") s += "<div>Адрес: " + data.postaddr + "</div>";
										if (data.current_tarif_name != "") s += "<div>Тариф: " + data.current_tarif_name + "</div>";
										if (data.inet_speed != "") s += "<div>Скорость: " + Math.round(data.inet_speed / 1000) + " Мбит/с</div>";
										if (data.next_tarif_name != "") s += "<div>Следующий тариф: " + data.next_tarif_name + "</div>";
										return s;
									}
								}]
							});
						}
					}
				}
				
			});
		});
	});
	
	/* Display login dialog */
	switchToLoginView();
};

webix.ready(function() {
	init();
});
