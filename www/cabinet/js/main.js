
var wsproto;

function switchToLoginView()
{
	document.getElementById("divLogin").style.display = "block";
	document.getElementById("divMain").style.display = "none";
}

function switchToMainView()
{
	document.getElementById("divLogin").style.display = "none";
	document.getElementById("divMain").style.display = "block";
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
	var msg = new wsproto.ClientMessage({
		'loginrequest': $$("loginForm").getValues()
	});
	var buf = msg.encode();
	ws.send(buf.toArrayBuffer());
}

function wsClose()
{
	switchToLoginView();
	webix.message("Соединение с сервером прервано.");
}

function wsMessage(evt)
{
	var msg = wsproto.ServerMessage.decode(evt.data);

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
	}
}

function doLogin()
{
	wsCreate();
}

function init()
{
	var wsprotofile = dcodeIO.ProtoBuf.loadProtoFile("wsproto.proto");
	wsproto = wsprotofile.build("WSPROTO");

	webix.ui({
		id: "loginView",
		container: "divLogin",
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
				{view: 'text', label: 'Пароль', name: 'password', type: 'password'},
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
	
	webix.ui({
		id: "mainView",
		container: "divMain",
		rows: [
			{type: 'header', template: "Личный кабинет"}
		]
	});

	switchToLoginView();
};

webix.ready(function() {
	init();
});
