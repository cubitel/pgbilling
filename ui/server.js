'use strict';

var config = require("./config.js");

const { Client } = require("pg");
var express = require("express");
var app = express();
var expressWs = require('express-ws')(app);

var commands = require("./modules/commands.js");

var port = process.env.PORT || 5000;


app.use(express.static(__dirname + "/html"));

app.ws('/ws/:section', async function(ws, req) {

	try {
		const { section } = req.params;
		if (!config.ws[section]) throw new Error("Неверный ID сервера");

		var client = {};
		client.db = new Client(config.ws[section]);
		client.authenticated = false;
		await client.db.connect();

		ws.on('close', async function() {
			await client.db.end();
			client = undefined;
		});

		ws.on('message', async function(data) {
			var req_id = undefined;
			try {
				var request = JSON.parse(data);
				var response = {};
				if (request.id != undefined) {
					response.id = request.id;
					req_id = request.id;
				}

				if (request.cmd == 'login') {
					const { rows } = await client.db.query("SELECT login($1, $2);", [request.login, request.password]);
					if (rows[0].login == 1) {
						client.authenticated = true;
						ws.send(JSON.stringify(response));
						return;
					} else {
						throw new Error("Вход не удался");
					}
				}

				if (!client.authenticated) throw new Error("Клиент не авторизован");

				if (!commands[request.cmd]) throw new Error("Неверная команда");

				response.response = await commands[request.cmd](client, request.params);

				ws.send(JSON.stringify(response));
			} catch (e) {
				let msg = {error: e.message};
				if (req_id != undefined) msg.id = req_id;
				ws.send(JSON.stringify(msg));
			}
		});

		ws.send(JSON.stringify({event: 'ready'}));

	} catch (e) {
		ws.send(JSON.stringify({error: e.message}));
		ws.close();
	}

});

app.use(function(req, res, next) {
	res.status(404).send('Page not found');
});

app.listen(port);

console.log("http server listening on %d", port);
