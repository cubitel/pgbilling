
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
		head: "Вход в кабинет оператора",
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
				view: "menu",
				autowidth: true,
				data: [{
					id: 'operator',
					value: "Оператор",
					submenu: [{
						id: 'changePassword',
						value: "Изменить пароль..."
					}]
				},{
					id: 'users',
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

function initPage(id, name, def, oncreate)
{
	pages[id] = {id: id, name: name, def: def, oncreate: oncreate};
}

function openPage(id)
{
	if (pages[id] != undefined) {
		if (pages[id].def != undefined) {
			var tab = {
				id: 'tab-' + id,
				header: pages[id].name,
				close: true,
				body: pages[id].def
			};
			var pageui = $$("panel").addView(tab);
		}
		pages[id].oncreate(pageui);
	}
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

	/* Display login dialog */
	switchToLoginView();
};

webix.ready(function() {
	init();
});
