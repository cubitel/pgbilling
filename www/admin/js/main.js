
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
				view: "label",
				label: "Кабинет оператора"
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
							var tab = {
								header: id,
								close: true,
								body: pages[id].def
							};
							var pageui = $$("panel").addView(tab);
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
						id: "tickets",
						value: "Заявки",
						icon: "user-plus"
					}]
				}]
			},{
				id: "panel",
				view: "tabview",
				cells: [{
					header: "Главная",
					body: {}
				}]
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
	});
	
	/* Tickets page */
	
	page("tickets", {
		rows: [{
			template: "<div class='page-header'>Заявки</div>",
			autoheight: true
		},{
			view: "datatable",
			id: "tickets-list",
			columns: [{
				map: '#ticket_id#',
				header: "Номер"
			},{
				map: '#time_created#',
				header: "Дата/время",
				width: 170
			},{
				map: '#ticket_type_name#',
				header: "Тип",
				width: 200
			},{
				map: '#ticket_status_name#',
				header: "Статус",
				width: 200
			},{
				map: '#street_name#',
				header: "Улица",
				fillspace: true
			},{
				map: '#house_number#',
				header: "Дом",
				width: 70
			},{
				map: '#phone#',
				header: "Телефон",
				width: 150
			},{
				map: '#dist#',
				header: "Расстояние",
				width: 100
			}],
			select: 'row'
		}]
	}, function() {
		wsSendMessage({
			selectrequest: {table: 'tickets'}
		}, function(resp) {
			var rows = parseSelectResponse(resp.selectresponse);
			$$("tickets-list").parse(rows);
		});
	});
	
	/* Display login dialog */
	switchToLoginView();
};

webix.ready(function() {
	init();
});
