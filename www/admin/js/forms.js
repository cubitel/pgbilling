
/* Change password */

initPage("changePassword", "Изменить пароль", undefined, function() {
	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Изменить пароль",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formChangePassword",
			width: 300,
			elements: [
				{view: 'text', type: 'password', label: 'Новый пароль', labelPosition: 'top', name: 'pass1'},
				{view: 'text', type: 'password', label: 'Повторите пароль', labelPosition: 'top', name: 'pass2'},
				{
					view: "button",
					value: "Изменить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formChangePassword").getValues();
						if (p.pass1 == '') {
							webix.alert("Пароль не должен быть пустым.");
							return;
						}
						if (p.pass1 != p.pass2) {
							webix.alert("Пароли не совпадают.");
							return;
						}
						wsSendMessage({
							functionrequest: {
								name: 'change_password',
								params: [{s: p.pass1}]
							}
						}, function(resp) {
							win.close();
							webix.alert("Пароль успешно изменен.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formChangePassword"));
});

/* Payments */

initPage("payments", "Платежи", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "payments-list",
			columns: [{
				map: '#payment_id#',
				header: "ID",
				width: 50,
				sort: 'int'
			},{
				map: '#oper_time#',
				header: "Время платежа",
				width: 200,
				sort: 'string'
			},{
				map: '#account_number#',
				header: "Лицевой счет",
				width: 200
			},{
				map: '#amount#',
				header: "Сумма",
				width: 200
			},{
				map: '#descr#',
				header: "Описание платежа",
				fillspace: true
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				selectrequest: {table: 'payments'}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var table = $$(uid).$$("payments-list");
				table.clearAll();
				table.parse(rows);
				table.sort("payment_id", "desc", "int");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});

		update();
	}
);

/* Map */

initPage("map", "Карта сети", {
		rows: [{
			template: "<div class='page-header'>Карта сети</div>",
			autoheight: true
		},{
			view: "open-map",
			id: "map",
			zoom: 13,
			center: [45.0404, 38.9781]
		}]
	}, function(pageui, uid, params) {
		wsSendMessage({
			selectrequest: {table: 'tickets'}
		}, function(resp) {
			var rows = parseSelectResponse(resp.selectresponse);
			var map = $$(uid).$$("map").map;
			for (var i in rows) {
				var row = rows[i];
				if (row.geopoint != "") {
					var point = JSON.parse(row.geopoint);
					L.marker([point.coordinates[1], point.coordinates[0]]).addTo(map).bindPopup(row.ticket_id + ': ' + row.street_name + ' ' + row.house_number);
				}
			}
		});
	}
);


/* Sessions page */

initPage("sessions", "Активные сессии", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "session-list",
			columns: [{
				map: '#acct_session_id#',
				header: "ID сессии",
				width: 220
			},{
				map: '#create_time#',
				header: "Время подключения",
				width: 200,
				sort: 'string'
			},{
				map: '#username#',
				header: "Имя пользователя",
				width: 200
			},{
				map: '#service_name#',
				header: "Имя услуги",
				fillspace: true,
				sort: 'string'
			},{
				map: '#class#',
				header: "Класс",
				width: 150
			},{
				map: '#device_ip#',
				header: "IP устройства",
				width: 150,
				sort: 'string'
			},{
				map: '#port_name#',
				header: "Порт устройства",
				width: 150
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				selectrequest: {table: 'radius_sessions'}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var table = $$(uid).$$("session-list");
				table.clearAll();
				table.parse(rows);
				table.sort("create_time", "desc", "string");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});

		update();
	}
);


/* Services page */

initPage("services", "Услуги", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			},{
				view: 'button',
				id: 'userAdd',
				label: "Создать",
				type: 'icon',
				icon: 'user',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "services-list",
			columns: [{
				map: '#service_id#',
				header: "ID Услуги",
				width: 70,
				sort: 'int'
			},{
				map: '#service_name#',
				header: "Имя услуги",
				width: 150,
				sort: 'string'
			},{
				map: '#service_state_name#',
				header: "Состояние",
				width: 150,
			},{
				map: '#tarif_name#',
				header: "Тариф",
				width: 120,
			},{
				map: '#balance#',
				header: "Баланс",
				width: 100,
			},{
				map: '#user_name#',
				header: "Абонент",
				width: 220,
			},{
				map: '#postaddr#',
				header: "Адрес оказания услуги",
				fillspace: true,
				sort: 'string'
			},{
				map: '#contacts#',
				header: "Контакты",
				width: 120,
			}],
			select: 'row',
			on: {
				onItemDblClick: function(id, e, node) {
					var row = this.getItem(id);
					openPage("userSummary", row.user_id);
				}
			}
		}]
	}, function(pageid, uid, params) {
		var update = function() {
			wsSendMessage({
				selectrequest: {table: 'services'}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var table = $$(uid).$$("services-list");
				table.clearAll();
				table.parse(rows);
				table.sort("service_id", "desc", "int");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});
		$$(uid).$$("userAdd").attachEvent("onItemClick", function() {
			openPage("userAdd");
		});

		update();
	}
);

initPage("userAdd", "Добавить пользователя", undefined, function() {
	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Добавить пользователя",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formUserAdd",
			width: 300,
			elements: [
				{view: 'text', type: 'text', label: 'Логин пользователя', labelPosition: 'top', name: 'user_login'},
				{
					view: "button",
					value: "Добавить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formUserAdd").getValues();
						wsSendMessage({
							functionrequest: {
								name: 'user_add',
								params: [{
									's': JSON.stringify(p)
								}]
							}
						}, function(resp) {
							win.close();
							webix.alert("Пользователь создан.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formUserAdd"));
});


/* User summary page */

initPage("userSummary", "Абонент", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			}]
		},{
			view: 'template',
			id: 'summary'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				functionrequest: {name: 'user_get_summary', params: [{i: parseInt(params)}]}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var summary = JSON.parse(rows[0].user_get_summary);

				var txt = "";
				txt += "Абонент: " + summary.login + "\n";
				txt += summary.user_name + "\n";
				txt += "\n";

				for (var i in summary.accounts) {
					var account = summary.accounts[i];
					txt += "Лицевой счет: " + account.account_number + "\n";
					txt += "Баланс: " + account.balance + "\n";
					txt += "\n";
				}

				for (var i in summary.services) {
					var service = summary.services[i];
					txt += "Услуга: " + service.service_name + "\n";
					txt += "Состояние: " + service.service_state_name + "\n";
					if (service.tarif_name) {
						txt += "Тариф: " + service.tarif_name + "\n";
					}
					if (service.postaddr) {
						txt += "Адрес: " + service.postaddr + "\n";
					}
					if (service.port_name) {
						txt += "Порт: " + service.port_name + " / " + service.device_ip + "\n";
					}
					if (service.serial_no) {
						txt += "Серийный №: " + service.serial_no + "\n";
					}
					txt += "\n";
				}

				$$(uid).$$("summary").setHTML("<pre>" + txt + "</pre>");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});

		update();
});

/* Tickets page */

initPage("tickets", "Заявки", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "tickets-list",
			columns: [{
				map: '#ticket_id#',
				header: "Номер",
				width: 70,
				sort: 'int'
			},{
				map: '#time_created#',
				header: "Дата",
				width: 110,
				sort: 'string'
			},{
				map: '#ticket_type_name#',
				header: "Тип",
				width: 200
			},{
				map: '#ticket_status_name#',
				header: "Статус",
				width: 150,
				sort: 'string'
			},{
				map: '#street_name#',
				header: "Улица",
				fillspace: true,
				sort: 'string'
			},{
				map: '#house_number#',
				header: "Дом",
				width: 70
			},{
				map: '#flat_number#',
				header: "Кв",
				width: 70
			},{
				map: '#phone#',
				header: "Телефон",
				width: 150
			},{
				map: '#dist#',
				header: "Расстояние",
				width: 100,
				sort: 'int'
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				selectrequest: {table: 'tickets'}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var table = $$(uid).$$("tickets-list");
				table.clearAll();
				table.parse(rows);
				table.sort("ticket_id", "desc", "int");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});

		update();
	});

/* Report: Payments */

initPage("report-payments", "Отчет по платежам", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "payments-list",
			columns: [{
				map: '#dt#',
				header: "Дата",
				width: 100,
				sort: 'string'
			},{
				map: '#cost#',
				header: "Сумма",
				fillspace: true
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				selectrequest: {table: 'report_payments'}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var table = $$(uid).$$("payments-list");
				table.clearAll();
				table.parse(rows);
				table.sort("dt", "desc", "string");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});

		update();
	}
);

/* Report: Invoices */

initPage("report-invoices", "Отчет по услугам", {
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'refresh',
				label: "Обновить",
				type: 'icon',
				icon: 'refresh',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "payments-list",
			columns: [{
				map: '#dt#',
				header: "Дата",
				width: 100,
				sort: 'string'
			},{
				map: '#cost#',
				header: "Сумма",
				fillspace: true
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				selectrequest: {table: 'report_invoices'}
			}, function(resp) {
				var rows = parseSelectResponse(resp.selectresponse);
				var table = $$(uid).$$("payments-list");
				table.clearAll();
				table.parse(rows);
				table.sort("dt", "desc", "string");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});

		update();
	}
);

