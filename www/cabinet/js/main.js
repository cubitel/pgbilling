
var wsproto;

function switchToLoginView()
{
	$("#mainView").hide();
	$("#loginView").show();
}

function switchToMainView()
{
	$("#loginView").hide();
	$("#mainView").show();
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
		'loginrequest': {
			'login': "test"
		}
	});
	var buf = msg.encode();
	ws.send(buf.toArrayBuffer());
}

function wsClose()
{
}

function wsMessage(evt)
{
	var msg = wsproto.ServerMessage.decode(evt.data);
	
	if (msg.loginresponse) {
		alert(JSON.stringify(msg.loginresponse));
	}
}

function init()
{
	var wsprotofile = dcodeIO.ProtoBuf.loadProtoFile("wsproto.proto");
	wsproto = wsprotofile.build("WSPROTO");
	
	switchToLoginView();
};

$(function() {
	init();
}
