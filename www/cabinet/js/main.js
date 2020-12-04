
var wsproto;
var wssequence = 1;
var wscallback = [];

var pages = [];

var phoneOrEmail = "";


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
					},{
						id: "user-account-log",
						value: "Операции",
						icon: "rub",
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
	data.id = data.id || wssequence++;
	if (callback) {
		wscallback.push({sequence: data.id, func: callback});
	}

	ws.send(JSON.stringify(data));
}

function wsCreate()
{
	ws = new WebSocket(cfgServerURL);
	ws.onopen = wsOpen;
	ws.onclose = wsClose;
	ws.onmessage = wsMessage;
}

function wsOpen()
{
}

function wsClose()
{
	$$("loginView").hideProgress();
	switchToLoginView();
	webix.message("Соединение с сервером прервано.");
}

function wsMessage(evt)
{
	var msg = JSON.parse(evt.data);

	$$("loginView").hideProgress();

	if (msg.id) {
		for (var i in wscallback) {
			if (wscallback[i].sequence == msg.id) {
				wscallback[i].func(msg.response);
				wscallback.splice(i, 1);
				break;
			}
		}
	}

	if (msg.error) {
		var txt = "Ошибка: " + msg.error;
		webix.message(txt);

		if ( (msg.fatal) || (msg.id == 'login') ) {
			ws.close();
			return;
		}
	}

	if (msg.event) {
		if (msg.event == 'ready') {
			var form = $$('loginForm').getValues();
			wsSendMessage({
				'cmd': 'login',
				'id': 'login',
				'login': form.login,
				'password': form.password
			});
		}
	}

	if (msg.id == 'login') {
		switchToMainView();

		phoneOrEmail = "";
		wsSendMessage({
			cmd: 'select', params: {table: "user_contacts"}
		}, function(resp) {
			var contacts = resp.rows;
			for (var i in contacts) {
				if (contacts[i].contact_type == 1) phoneOrEmail = "+7" + contacts[i].contact_value;
			}
		});

		return;
	}

}

function doLogin()
{
	$$("loginView").showProgress();
	wsCreate();
}

function doAccountPay(account, balance)
{
	var minAmount = 100;
	if (balance < -3000) minAmount = 500;
	if (balance < -10000) minAmount = 1000;

	var win = webix.ui({
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
				{view: 'text', label: 'Сумма платежа (мин ' + minAmount + ' руб.)', labelPosition: 'top', name: 'sum'},
				{margin: 5, cols: [
					{
						view: "button",
						value: "Оплатить",
						click: function() {
							var p = $$("yandexForm").getValues();
							if (p.sum < minAmount) {
								alert('Сумма платежа меньше минимально допустимой.');
							} else {
								p.customerNumber = account;
								p.shopId = cfgYandexShopId;
								p.scid = cfgYandexScid;
								p.phoneOrEmail = phoneOrEmail;
								webix.send("https://money.yandex.ru/eshop.xml", p);
							}
						}
					},
					{
						view: "button",
						value: "Отмена",
						click: function() {
							win.close();
						}
					}
				]}
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
				cmd: 'perform',
				params: {
					proc: 'account_promise_payment',
					params: [parseInt(account_id)]
				}
			}, function(resp) {
				webix.alert("Ваша заявка на обещанный платеж зарегистрирована. Вы должны внести платеж в течении суток.");
			});
		}
	});
}

function init()
{
	webix.i18n.setLocale("ru-RU");

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
			cmd: 'select', params: {table: "accounts"}
		}, function(resp) {
			var accounts = resp.rows;

			wsSendMessage({
				cmd: 'select', params: {table: "services"}
			}, function(resp) {
				var services = resp.rows;

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
									"<a class='button' href='javascript:doAccountPay(\"" + data.account_number + "\", " + data.balance + ");'><span class='webix_icon fa-plus'></span>Пополнить счет</a>" +
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
										if (data.postaddr) s += "<div>Адрес: " + data.postaddr + "</div>";
										if (data.current_tarif_name) s += "<div>Тариф: " + data.current_tarif_name + "</div>";
										if (data.inet_speed) s += "<div>Скорость: " + Math.round(data.inet_speed / 1000) + " Мбит/с</div>";
										if (data.next_tarif_name) s += "<div>Следующий тариф: " + data.next_tarif_name + "</div>";
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

	/* Account log */

	page("user-account-log", {
		rows: [{
			template: "<div class='page-header'>Операции по счету</div>",
			autoheight: true
		},{
			view: "datatable",
			id: "payments-list",
			columns: [{
				map: '#oper_time#',
				header: "Дата",
				width: 200,
				format: function (value) {
					return webix.i18n.fullDateFormatStr(new Date(value));
				},
				sort: 'string'
			},{
				map: '#amount#',
				header: "Сумма",
				width: 100
			},{
				map: '#descr#',
				header: "Описание операции",
				fillspace: true
			}],
			select: 'row'
		}]
	}, function() {
		wsSendMessage({
			cmd: 'select', params: {table: "account_logs"}
		}, function(resp) {
			var rows = resp.rows;
			var table = $$("payments-list");
			table.clearAll();
			table.parse(rows);
			table.sort("oper_time", "desc", "string");
		});
	});

	/* Display login dialog */
	switchToLoginView();
};

webix.ready(function() {
	init();
});
