
function initFramework(section)
{
	var ws = {};
	var seq = 1;
	var callbacks = [];
	var rnd = Math.random();

	var obj = {};

	var getSocketURL = function () {
		var host = window.location.host || "127.0.0.1:5000";
		var proto = "ws:";
		if (window.location.protocol == "https:") proto = "wss:";
		return proto + "//" + host + "/ws/" + section;
	}

	var showPage = async function (html, params) {
		try {
			pageInit = undefined;
			$('#page').html(html);
			await pageInit(params);
		} catch (e) {
			obj.pageError(e.message);
		}
	}

	var formatMoney = function (amount, decimalCount = 2, decimal = ".", thousands = " ") {
		try {
			decimalCount = Math.abs(decimalCount);
			decimalCount = isNaN(decimalCount) ? 2 : decimalCount;

			const negativeSign = amount < 0 ? "-" : "";

			let i = parseInt(amount = Math.abs(Number(amount) || 0).toFixed(decimalCount)).toString();
			let j = (i.length > 3) ? i.length % 3 : 0;

			return negativeSign + (j ? i.substr(0, j) + thousands : '') + i.substr(j).replace(/(\d{3})(?=\d)/g, "$1" + thousands) + (decimalCount ? decimal + Math.abs(amount - i).toFixed(decimalCount).slice(2) : "");
		} catch (e) {
		}
	}

	var onstatechange = function() {
	}

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
		$.get("pages/" + url + ".html?rnd=" + rnd)
			.done(function(html) {
				showPage(html, params);
			})
			.fail(function() {
				obj.pageError("Ошибка загрузки страницы.");
			});
	};

	obj.render = function(dest, template, params) {
		var source = $(template).html();
		var tmpl = Handlebars.compile(source);
		$(dest).html(tmpl(params));
	};

	obj.pageError = function (text) {
		$('#page').html('<div class="alert alert-danger"><strong>Ошибка</strong><div><pre>' + text + '</pre></div></div>');
	}

	moment.locale('ru');
	Handlebars.registerHelper('df', function(dateTime) {
		return moment(dateTime).format('D MMM YYYY HH:mm');
	});

	Handlebars.registerHelper('money', function(amount) {
		return formatMoney(amount);
	});

	Handlebars.registerHelper('div', function(arg1, arg2) {
		return arg1 / arg2;
	});

	Handlebars.registerHelper('faServiceType', function(type_id) {
		if (type_id == 1) return 'fa fa-globe-asia';
		if (type_id == 2) return 'fa fa-tv';
		return '';
	});

	Handlebars.registerHelper('faServiceState', function(state_id) {
		if (state_id == 1) return 'fa fa-check color-green';
		return 'fa fa-times-circle color-red';
	});

	return obj;
}
