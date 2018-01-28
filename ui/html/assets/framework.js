
function initFramework(section)
{
	var ws = {};
	var seq = 1;
	var callbacks = [];
	var rnd = Math.random();

	var getSocketURL = function () {
		var host = window.location.host || "127.0.0.1:5000";
		var proto = "ws:";
		if (window.location.protocol == "https:") proto = "wss:";
		return proto + "//" + host + "/ws/" + section;
	}

	var onstatechange = function() {
	}

	var obj = {};

	obj.cmd = function (cmd, params) {
		return new Promise(function(resolve, reject) {
			params = params || {};
			var next_id = seq++;
			callbacks[next_id] = function(response) {
				callbacks[next_id] = undefined;
				if (response.error != undefined) {
					return reject(new Error(response.error));
				} else {
					return resolve(response.response);
				}
			}
			ws.send(JSON.stringify({cmd: cmd, id: next_id, params: params}));
		});
	};

	obj.login = function (login, password) {
		return new Promise(function(resolve, reject) {
			callbacks = [];
			callbacks['login'] = function(response) {
				callbacks['login'] = undefined;
				if (response.error != undefined) {
					return reject(new Error(response.error));
				} else {
					onstatechange(true);
					return resolve(response.response);
				}
			}

			ws = new WebSocket(getSocketURL());

			ws.onmessage = function(data) {
				var msg = JSON.parse(data.data);

				if (msg.event != undefined) {
					if (msg.event == "ready") {
						ws.send(JSON.stringify({
							cmd: "login",
							id: "login",
							login: login,
							password: password
						}));
					}
				}

				if ( (msg.id != undefined) && (callbacks[msg.id] != undefined) ) {
					callbacks[msg.id](msg);
					callbacks[msg.id] = undefined;
				}

			};

			ws.onerror = function(error) {
				onstatechange(false);
				return reject(new Error(error.message));
			};

			ws.onclose = function() {
				onstatechange(false);
			}
		});
	};

	obj.logout = function () {
		ws.close();
	};

	obj.stateChangeCallback = function(callback) {
		onstatechange = callback;
	};

	obj.page = function(url, params) {
		var el = $("#page");
		el.html("Загрузка...");
		$.get("pages/" + url + ".html?" + rnd)
			.done(function(html) {
				el.html(html);
			})
			.fail(function() {
				el.html("Ошибка загрузки страницы.");
			});
	};

	obj.render = function(dest, template, params) {
		var source = $(template).html();
		var tmpl = Handlebars.compile(source);
		$(dest).html(tmpl(params));
	};

	return obj;
}
