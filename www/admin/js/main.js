
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
		head: "Вход в кабинет оператора",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "loginForm",
			width: 300,
			elements: [
				{view: 'text', label: 'Логин', name: 'login', id: 'inputLogin'},
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
				view: "menu",
				autowidth: true,
				data: [{
					value: "Оператор",
					submenu: [{
						id: 'changePassword',
						value: "Изменить пароль..."
					}]
				},{
					value: "Абоненты",
					submenu: [{
						id: 'tickets',
						value: "Заявки"
					},{
						id: 'services',
						value: "Услуги"
					},{
						id: 'sessions',
						value: "Активные сессии"
					},{
						id: 'payments',
						value: "Платежи"
					}]
				},{
					value: "Сеть",
					submenu: [{
						id: 'map',
						value: "Карта сети"
					},{
						id: 'ponONT',
						value: "Устройства PON"
					}]
				},{
					value: "Отчеты",
					submenu: [{
						id: 'report-payments',
						value: "Платежи по дням"
					},{
						id: 'report-invoices',
						value: "Отчет по услугам"
					}]
				}],
				on: {
					onMenuItemClick: function(id) {
						openPage(id);
					}
				}
			},{},{
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
				id: "panel",
				view: "tabview",
				tabbar: { optionWidth: 250 },
				cells: [{
					header: "Главная",
					body: {}
				}]
			}]
		}]
	});
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
	console.log(msg)

	$$("loginView").hideProgress();

	if (msg.id) {
		for (var i in wscallback) {
			if (wscallback[i].sequence == msg.id) {
				if (!msg.error) wscallback[i].func(msg.response);
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
		return;
	}

}

function sendRequest(request)
{
	return new Promise(function(resolve, reject) {
		wsSendMessage(request, function(response) {
			if (response.error) {
				return reject(new Error(response.error));
			} else {
				return resolve(response);
			}
		});
	});
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

function initPage(id, name, def, oncreate)
{
	pages[id] = {id: id, name: name, def: def, oncreate: oncreate};
}

function openPage(id, params)
{
	var uid = webix.uid();

	if (pages[id] != undefined) {
		if (pages[id].def != undefined) {
			var viewcfg = pages[id].def;
			viewcfg.id = uid;
			viewcfg.view = 'ui-tab-content';
			var tab = {
				id: 'tab-' + uid,
				header: pages[id].name,
				close: true,
				body: viewcfg
			};
			var pageui = $$("panel").addView(tab);
			$$(viewcfg.id).show();
		}
		pages[id].oncreate(pageui, uid, params);
	}
}

function init()
{
	webix.i18n.setLocale("ru-RU");
	webix.protoUI({name: "ui-tab-content"}, webix.IdSpace, webix.ui.layout);

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

	/* Display login dialog */
	switchToLoginView();
};

webix.ready(function() {
	init();
});
