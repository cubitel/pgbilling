
var wsproto;

function switchToLoginView()
{
}

function switchToMainView()
{
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
	webix.message("Connection closed");
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
		}
	}

	if (msg.loginresponse) {
		alert(JSON.stringify(msg.loginresponse));
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
		view: 'window',
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
	}).show();
};

webix.ready(function() {
	init();
});
