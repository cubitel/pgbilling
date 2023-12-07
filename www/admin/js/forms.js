
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
							cmd: 'perform',
							params: {
								proc: 'change_password',
								params: [p.pass1]
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
				sort: 'string',
				format: function (value) {
					return webix.i18n.fullDateFormatStr(new Date(value));
				}
			},{
				map: '#account_number#',
				header: ["Лицевой счет", {content:"textFilter"}],
				width: 200
			},{
				map: '#amount#',
				header: ["Сумма", {content:"numberFilter"}],
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
				cmd: 'select', params: {table: 'payments'}
			}, function(resp) {
				var rows = resp.rows;
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
			view: "open-map",
			id: "map",
			zoom: 13,
			center: [45.0404, 38.9781]
		}]
	}, async function(pageui, uid, params) {
		var boxIcon = L.icon({
			iconUrl: 'js/images/marker-red.png',
			iconSize: [24, 24],
			iconAnchor: [12, 24],
			popupAnchor: [0, -12]
		});
		var onuIcon = L.icon({
			iconUrl: 'js/images/marker-green.png',
			iconSize: [24, 24],
			iconAnchor: [12, 24],
			popupAnchor: [0, -12]
		});
		var ticketIcon = L.icon({
			iconUrl: 'js/images/marker-blue-land.png',
			iconSize: [24, 24],
			iconAnchor: [12, 24],
			popupAnchor: [0, -12]
		});

		var map = $$(uid).$$("map").map;
		var popup = L.popup();

		map.on('click', function(e) {
			popup.setLatLng(e.latlng)
				.setContent(e.latlng.toString() + "<br/>"
					+ "<a href=\"javascript:openPage('boxAdd', {lat: " + e.latlng.lat + ", long: " + e.latlng.lng + "});\">Добавить бокс</a>")
				.openOn(map);
		});

		var resp = await sendRequest({cmd: 'select', params: {table: 'tickets'}});
		for (var i in resp.rows) {
			var row = resp.rows[i];
			if (row.geopoint != "") {
				var point = JSON.parse(row.geopoint);
				if (point != null) L.marker([point.coordinates[1], point.coordinates[0]], {icon: ticketIcon})
					.addTo(map)
					.bindPopup(row.ticket_id + ': ' + row.street_name + ' ' + row.house_number);
			}
		}

		var resp = await sendRequest({cmd: 'select', params: {table: 'optic_boxes'}});
		for (var i in resp.rows) {
			var row = resp.rows[i];
			if (row.geopoint != "") {
				var point = JSON.parse(row.geopoint);
				if (point != null) L.marker([point.coordinates[1], point.coordinates[0]], {icon: boxIcon})
					.addTo(map)
					.bindPopup(row.box_type_name + ' #' + row.box_id);
			}
		}

		var resp = await sendRequest({cmd: 'select', params: {
			table: 'pon_ont',
			condition: {ont_state: {$ne: 4}}
		}});
		for (var i in resp.rows) {
			var row = resp.rows[i];
			if (row.geopoint != "") {
				var point = JSON.parse(row.geopoint);
				if (point != null) L.marker([point.coordinates[1], point.coordinates[0]], {icon: onuIcon})
					.addTo(map)
					.bindPopup(row.ont_serial + '<br/>' + row.description);
			}
		}
	}
);


/* PON ONT */

initPage("ponONT", "Устройства PON", {
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
				id: 'ponAddONU',
				label: "Добавить ONU",
				type: 'icon',
				icon: 'user',
				autowidth: true
			}]
		},{
			view: "datatable",
			id: "ponont-list",
			columns: [{
				map: '#ont_serial#',
				header: ["Серийный номер", {content:"textFilter"}],
				width: 180,
				sort: 'string'
			},{
				map: '#ont_state_name#',
				header: ["Управление", {content:"selectFilter"}],
				width: 150
			},{
				map: '#ont_type_name#',
				header: ["Тип ONT", {content:"selectFilter"}],
				width: 200
			},{
				map: '#device_description#',
				header: ["OLT", {content:"selectFilter"}],
				width: 240,
			},{
				map: '#device_port#',
				header: ["OLT ONU ID", {content:"textFilter"}],
				width: 150
			},{
				map: '#box_id#',
				header: ["Бокс", {content:"numberFilter"}],
				width: 120
			},{
				map: '#description#',
				header: ["Описание", {content:"textFilter"}],
				fillspace: true,
			},{
				map: '#rssi#',
				header: "Статус",
				width: 120,
				template: '<input class="rssi" type="button" value="RSSI">'
			}],
			select: 'row',
			on: {
				onItemDblClick: function(id, e, node) {
					var row = this.getItem(id);
					openPage("ponEditONU", row.ont_id);
				}
			},
			onClick: {
				'rssi': function (e, id, trg) {
					var grid = this
					var item = this.getItem(id)
					$.get(cfgNetapiURL + 'device/' + item.device_ip + '/ont/' + item.device_port + '/status', {}, function (status) {
						alert(JSON.stringify(status))
					})
					return false
				}
			}
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				cmd: 'select', params: {table: 'pon_ont', condition: {ont_state: {$ne: 4}}}
			}, function(resp) {
				var rows = resp.rows;
				var table = $$(uid).$$("ponont-list");
				table.clearAll();
				table.parse(rows);
				table.sort("create_time", "desc", "string");
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});
		$$(uid).$$("ponAddONU").attachEvent("onItemClick", function() {
			openPage("ponAddONU");
		});

		update();
	}
);

/* Add PON ONU */

initPage("ponAddONU", "Добавить ONU", undefined, function(pageui, uid, params) {

	var ticket_id = parseInt(params);

	wsSendMessage({
		cmd: 'select', params: {table: 'pon_ont_types'}
	}, function(resp) {
		var rows = resp.rows;
		var ont_types = [];

		for (var i in rows) {
			ont_types.push({id: rows[i].ont_type, value: rows[i].ont_type_name});
		}

		var win = webix.ui({
			view: 'window',
			hidden: false,
			head: "Добавить ONU",
			move: true,
			position: 'center',
			body: {
				view: 'form',
				id: "formAddONU",
				width: 300,
				elements: [
					{view: 'text', type: 'text', label: 'FSAN', labelPosition: 'top', name: 'ont_serial'},
					{view: 'select', type: 'text', label: 'Сервис', labelPosition: 'top', name: 'ont_type', options: ont_types},
					{view: 'text', type: 'text', label: 'Комментарий', labelPosition: 'top', name: 'description'},
					{
						view: "button",
						value: "Добавить",
						width: 150,
						align: "center",
						click: function() {
							var p = $$("formAddONU").getValues();
							wsSendMessage({
								cmd: 'perform',
								params: {
									proc: 'pon_ont_add',
									params: [JSON.stringify(p)]
								}
							}, function(resp) {
								win.close();
								webix.alert("Данные сохранены.");
							});
						}
					}
				]
			}
		});

		webix.UIManager.setFocus($$("formAddONU"));
	});
});

/* Edit ONT */

initPage("ponEditONU", "Редактировать ONU", undefined, async function(pageui, uid, params) {

	var ont_id = parseInt(params);

	var resp = await sendRequest({cmd: 'select', params: {table: 'pon_ont', condition: {ont_id: ont_id}}});
	var ont = resp.rows[0];

	var resp = await sendRequest({cmd: 'select', params: {table: 'pon_ont_states'}});

	var statusOptions = [];
	for (var i in resp.rows) {
		if (resp.rows[i].ont_state == 4) continue;
		statusOptions.push({id: resp.rows[i].ont_state, value: resp.rows[i].ont_state_name});
	}

	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Редактировать ONU",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formEditONU",
			width: 700,
			elements: [
				{cols: [
					{rows: [
						{view: 'fieldset', label: 'FSAN', body: {rows: [
							{view: 'text', label: 'FSAN', labelPosition: 'top', value: ont.ont_serial, disabled: true},
							{view: 'select', label: 'Управление ONU', labelPosition: 'top', options: statusOptions, name: 'ont_state', value: ont.ont_state},
							{view: 'text', label: 'Новый FSAN', labelPosition: 'top', name: 'ont_next_serial', value: ont.ont_next_serial},
						]}
					}]},
					{rows: [
						{view: 'fieldset', label: 'Оборудование', body: {rows: [
							{view: 'text', label: 'Ошибка API', labelPosition: 'top', value: ont.api_fail_message, disabled: true},
							{view: 'text', label: 'OLT', labelPosition: 'top', value: ont.device_description, disabled: true},
							{view: 'text', label: 'ONU ID', labelPosition: 'top', value: ont.device_port, disabled: true},
						]}
					}]},
				]},
				{view: 'text', type: 'text', label: 'Краткий комментарий', labelPosition: 'top', name: 'description', value: ont.description},
				{
					view: "button",
					value: "Сохранить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formEditONU").getValues();
						p.ont_id = ont_id;
						wsSendMessage({
							cmd: 'perform',
							params: {
								proc: 'pon_ont_edit',
								params: [JSON.stringify(p)]
							}
						}, function(resp) {
							win.close();
							webix.alert("Данные обновлены.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formEditONU"));
});


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
				sort: 'string',
				format: function (value) {
					return webix.i18n.fullDateFormatStr(new Date(value));
				}
			},{
				map: '#username#',
				header: ["Имя пользователя", {content:"textFilter"}],
				width: 200
			},{
				map: '#service_name#',
				header: ["Имя услуги", {content:"textFilter"}],
				fillspace: true,
				sort: 'string'
			},{
				map: '#class#',
				header: "Класс",
				width: 150
			},{
				map: '#device_ip#',
				header: ["IP устройства", {content:"textFilter"}],
				width: 150,
				sort: 'string'
			},{
				map: '#port_name#',
				header: ["Порт устройства", {content:"textFilter"}],
				width: 150
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				cmd: 'select', params: {table: 'radius_sessions'}
			}, function(resp) {
				var rows = resp.rows;
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
			},{
				view: 'button',
				id: 'userDelete',
				label: "Удалить",
				type: 'icon',
				icon: 'user',
				autowidth: true
			},{
				view: 'button',
				id: 'serviceEdit',
				label: "Изменить",
				type: 'icon',
				icon: 'edit',
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
				header: ["Имя услуги", {content:"textFilter"}],
				width: 150,
				sort: 'string'
			},{
				map: '#service_state_name#',
				header: ["Состояние", {content:"selectFilter"}],
				width: 150,
			},{
				map: '#tarif_name#',
				header: ["Тариф", {content:"selectFilter"}],
				width: 120,
			},{
				map: '#balance#',
				header: ["Баланс", {content:"numberFilter"}],
				width: 100,
			},{
				map: '#user_name#',
				header: ["Абонент", {content:"textFilter"}],
				width: 220,
			},{
				map: '#postaddr#',
				header: ["Адрес оказания услуги", {content:"textFilter"}],
				fillspace: true,
				sort: 'string'
			},{
				map: '#contacts#',
				header: ["Контакты", {content:"textFilter"}],
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
				cmd: 'select', params: {table: 'services'}
			}, function(resp) {
				var rows = resp.rows;
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
		$$(uid).$$("userDelete").attachEvent("onItemClick", function() {
			openPage("userDelete");
		});

		$$(uid).$$("services-list").attachEvent("onItemClick", function(id, e, node) {
			var row = this.getItem(id);


			$$(uid).$$("serviceEdit").detachEvent("service-edit-click");
			$$(uid).$$("serviceEdit").attachEvent("onItemClick", function() {
				openPage("serviceEdit", row.service_id);
			}, 'service-edit-click');
		});

		update();
	}
);

/* Edit ONT */

initPage("serviceEdit", "Редактировать сервис", undefined, async function(pageui, uid, params) {

	var service_id = parseInt(params);

	var resp = await sendRequest({cmd: 'select', params: {table: 'services', condition: {service_id: service_id}}});
	var service = resp.rows[0];

	var states = await sendRequest({cmd: 'select', params: {table: 'service_states'}});
	var stateOptions = [];
	stateOptions.push({id: '', value: 'Без изменений (' + service.service_state_name + ')'});
	for (var i in states.rows) {
		stateOptions.push({id: states.rows[i].service_state, value: states.rows[i].service_state_name});
	}

	var tarifs = await sendRequest({cmd: 'select', params: {table: 'tarifs', condition: {service_type: service.service_type}}});
	var tarifOptions = [];
	tarifOptions.push({id: '', value: ''});
	for (var i in tarifs.rows) {
		tarifOptions.push({id: tarifs.rows[i].tarif_id, value: tarifs.rows[i].tarif_name});
	}

	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: service.service_name,
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formEditService",
			width: 700,
			elements: [
				{cols: [
					{rows: [
						{view: 'fieldset', label: 'Сервис', body: {rows: [
							{view: 'text', label: 'Имя сервиса', labelPosition: 'top', value: service.service_name, name: 'service_name'},
							{view: 'select', label: 'Состояние', labelPosition: 'top', options: stateOptions, name: 'service_state'},
						]}
					}]},
					{rows: [
						{view: 'fieldset', label: 'Тариф', body: {rows: [
							{view: 'text', label: 'Текущий тариф', labelPosition: 'top', name: 'current_tarif', value: service.tarif_name, disabled: true},
							{view: 'select', label: 'Изменить тариф на', labelPosition: 'top', options: tarifOptions, name: 'next_tarif', value: service.next_tarif},
							{view: 'text', label: 'Ограничение скорости, кбит/с', labelPosition: 'top', value: service.inet_speed, name: 'inet_speed', disabled: (service.current_tarif != undefined)},
						]}
					}]},
				]},
				{view: 'fieldset', label: 'Адрес', body: {rows: [
					{view: 'text', name: 'postaddr', value: service.postaddr, disabled: true},
				]}},
				{
					view: "button",
					value: "Сохранить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formEditService").getValues();
						p.service_id = service_id;
						if (p.service_state == '') p.service_state = undefined;
						if (p.next_tarif == '') p.next_tarif = undefined;
						wsSendMessage({
							cmd: 'perform',
							params: {
								proc: 'service_edit',
								params: [JSON.stringify(p)]
							}
						}, function(resp) {
							win.close();
							webix.alert("Данные обновлены.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formEditService"));
});


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
				{view: 'text', type: 'text', label: 'Пароль пользователя', labelPosition: 'top', name: 'user_password'},
				{view: 'text', type: 'text', label: 'Скорость интернета (Мбит/с)', labelPosition: 'top', name: 'inet_speed'},
				{view: 'text', type: 'text', label: 'IP адрес коммутатора', labelPosition: 'top', name: 'device_ip'},
				{view: 'text', type: 'text', label: 'Порт коммутатора', labelPosition: 'top', name: 'device_port'},
				{
					view: "button",
					value: "Добавить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formUserAdd").getValues();
						wsSendMessage({
							cmd: 'perform',
							params: {
								proc: 'user_add',
								params: [JSON.stringify(p)]
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


initPage("userDelete", "Удалить пользователя", undefined, function() {
	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Удалить пользователя",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formUserDelete",
			width: 300,
			elements: [
				{view: 'text', type: 'text', label: 'Имя пользователя', labelPosition: 'top', name: 'user_login'},
				{
					view: "button",
					value: "Удалить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formUserDelete").getValues();
						wsSendMessage({
							cmd: 'perform',
							params: {
								proc: 'service_delete',
								params: [JSON.stringify(p)]
							}
						}, function(resp) {
							win.close();
							webix.alert("Пользователь удален.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formUserDelete"));
});


/* User summary page */

initPage("userSummary", "Абонент", {
	cols: [{
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
				id: 'password',
				label: "Пароль",
				type: 'icon',
				icon: 'key',
				autowidth: true
			}]
		},{
			view: 'template',
			id: 'summary',
			height: 200
		},{
			view: "datatable",
			id: "services-list",
			columns: [{
				map: '#service_state_name#',
				header: "Состояние",
				width: 100
			},{
				map: '#service_name#',
				header: "Имя",
				width: 180
			},{
				map: '#postaddr#',
				header: "Адрес оказания услуги",
				fillspace: true
			}],
			select: 'row'
		}]
	},{
		rows: [{
			view: "toolbar",
			padding: 3,
			elements: [{
				view: 'button',
				id: 'status',
				label: "Текущее состояние",
				type: 'icon',
				icon: 'signal',
				autowidth: true
			},{
				view: 'button',
				id: 'serviceEdit',
				label: "Изменить",
				type: 'icon',
				icon: 'edit',
				autowidth: true
			}]
		},{
			view: 'template',
			id: 'info'
		}]
	}]

	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				cmd: 'perform', params: {proc: 'user_get_summary', params: [parseInt(params)]}
			}, function(resp) {
				var rows = resp.rows;
				var summary = rows[0].user_get_summary;

				var txt = "";
				txt += "Абонент: " + summary.login + "\n";
				txt += summary.user_name + "\n";
				txt += "\n";

				var rows = [];

				for (var i in summary.accounts) {
					var account = summary.accounts[i];
					txt += "Лицевой счет: " + account.account_number + "\n";
					txt += "Дата создания: " + account.time_created + "\n";
					txt += "Баланс: " + account.balance + "\n";
					txt += "\n";
				}

/*
				for (var i in summary.services) {
					var service = summary.services[i];

					var descr = service.service_type_name + "<br/>";
					if (service.tarif_name) {
						descr += "Тариф: " + service.tarif_name + "<br/>";
					}
					if (service.postaddr) {
						descr += "Адрес: " + service.postaddr + "<br/>";
					}
					if (service.port_name) {
						descr += "Порт: " + service.port_name + " / " + service.device_ip +
						" <a href='" + cfgNetapiURL + "device/" + service.device_ip + "/ont/" + service.port_name + "/status'>Статус</a>" +
						"<br/>";
					}
					if (service.serial_no) {
						descr += "Серийный №: " + service.serial_no + "<br/>";
					}
					if (service.ip_list[0]) {
						descr += "IP: " + service.ip_list[0] + "<br/>";
					}
					rows.push({
						service_name: service.service_name + "<br/>" + service.service_state_name,
						summary: descr
					});
				}
*/

				var table = $$(uid).$$("services-list");
				table.clearAll();
				table.parse(summary.services);
				$$(uid).$$("summary").setHTML("<pre>" + txt + "</pre>");
			});
		}


		var getPassword = function() {
			wsSendMessage({
				cmd: 'perform', params: {proc: 'user_get_password', params: [parseInt(params)]}
			}, function(resp) {
				var rows = resp.rows;
				var info = rows[0].user_get_password;
				alert(info.pass);
			});
		}

		$$(uid).$$("refresh").attachEvent("onItemClick", function() {
			update();
		});
		$$(uid).$$("password").attachEvent("onItemClick", function() {
			getPassword();
		});
		$$(uid).$$("services-list").attachEvent("onItemClick", function(id, e, node) {
			var row = this.getItem(id);

			var descr = row.service_type_name + "<br/>";
			if (row.tarif_name) {
				descr += "Тариф: " + row.tarif_name + "<br/>";
			}
			if (row.postaddr) {
				descr += "Адрес: " + row.postaddr + "<br/>";
			}
			if (row.port_name) {
				descr += "Порт: " + row.port_name + " / " + row.device_ip +
				" <a href='" + cfgNetapiURL + "device/" + row.device_ip + "/ont/" + row.port_name + "/status' target='_blank'>Статус</a>" +
				"<br/>";
			}
			if (row.serial_no) {
				descr += "Серийный №: " + row.serial_no + "<br/>";
			}
			if (row.ip_list[0]) {
				descr += "IP: " + row.ip_list[0] + "<br/>";
			}
			$$(uid).$$("info").setHTML("<pre>" + descr + "</pre>");

			$$(uid).$$("status").detachEvent("user-service-status-click");
			$$(uid).$$("status").attachEvent("onItemClick", function() {
				openPage("userServiceStatus", row.service_id);
			}, "user-service-status-click");
			$$(uid).$$("serviceEdit").detachEvent("user-service-edit-click");
			$$(uid).$$("serviceEdit").attachEvent("onItemClick", function() {
				openPage("serviceEdit", row.service_id);
			}, "user-service-edit-click");
		});

		update();
});

/* User service status */

initPage("userServiceStatus", "Текущее состояние сервиса", undefined, async function(pageui, uid, params) {

	var service_id = parseInt(params);

	var resp = await sendRequest({cmd: 'select', params: {table: 'service_sessions', condition: {service_id: service_id}}});
	var sessions = resp.rows;

	var drawOnline = function() {
		var cellStartX = 40;
		var cellStartY = 20;
		var cellHeight = 14;
		var cellWidth = 25;

		var ctx = document.getElementById("canvasOnline" + uid).getContext("2d");

		ctx.font = '10px Verdana';
		ctx.fillStyle = '#000000';
		ctx.lineWidth = 1;

		ctx.textAlign = 'center';
		for (var h = 0; h < 24; h++) {
			ctx.fillText(h, cellStartX + h * cellWidth + cellWidth / 2, cellStartY - 2);
		}

		ctx.textAlign = 'right';
		for (var d = 0; d < 7; d++) {
			var date = new Date();
			date.setDate(date.getDate() - d);
			var day = date.getDate() + '.' + (date.getMonth()+1);

			ctx.fillStyle = '#000000';
			ctx.fillText(day, cellStartX - 2, cellStartY + cellHeight * (d+1) - 2);

			ctx.fillStyle = '#dddddd';
			for (var h = 0; h < 24; h++) {
				ctx.fillRect(cellStartX + cellWidth * h, cellStartY + cellHeight * d, cellWidth-1, cellHeight-1);
			}
		}

		ctx.lineWidth = 5;
		for (var i in sessions) {
			var session = sessions[i];

			ctx.strokeStyle = '#99cc99';
			if (session.active == 1) ctx.strokeStyle = '#669966';

			for (var d = 0; d < 7; d++) {
				var timeStart = new Date(session.create_time);
				var timeEnd = new Date(session.update_time);

				var dateMin = new Date();
				dateMin.setDate(dateMin.getDate() - d);
				dateMin.setHours(0, 0, 0, 0);
				var dateMax = new Date();
				dateMax.setDate(dateMax.getDate() - d);
				dateMax.setHours(23, 59, 59, 0);

				if (timeStart > dateMax) continue;
				if (timeEnd < dateMin) continue;

				if (timeStart < dateMin) timeStart = dateMin;
				if (timeEnd > dateMax) timeEnd = dateMax;

				var startPos = cellStartX + (timeStart.getHours() * 60 + timeStart.getMinutes()) * cellWidth / 60;
				var endPos = cellStartX + (timeEnd.getHours() * 60 + timeEnd.getMinutes()) * cellWidth / 60;
				ctx.moveTo(startPos, cellStartY + d * cellHeight + cellHeight / 2);
				ctx.lineTo(endPos, cellStartY + d * cellHeight + cellHeight / 2);
				ctx.stroke();
			}
		}
	}

	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Текущее состояние сервиса",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formUserServiceStatus",
			width: 800,
			height: 400,
			elements: [{
				template: "<canvas id='canvasOnline" + uid + "' height='170px' width='700px'></canvas>"
			},{
				view: "datatable",
				id: "service-status-sessions",
				columns: [{
					map: '#create_time#',
					header: "Время подключения",
					width: 200,
					sort: 'string',
					format: function (value) {
						return webix.i18n.fullDateFormatStr(new Date(value));
					}
				},{
					map: '#update_time#',
					header: "Время обновления",
					width: 200,
					sort: 'string',
					format: function (value) {
						return webix.i18n.fullDateFormatStr(new Date(value));
					}
				},{
					map: '#username#',
					header: "Имя пользователя",
					fillspace: true,
				}],
				select: 'row'
			}]
		}
	});

	var table = $$("service-status-sessions");
	table.clearAll();
	table.parse(sessions);
	table.sort("update_time", "desc", "string");

	drawOnline();

	webix.UIManager.setFocus($$("formUserServiceStatus"));
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
				header: ["Номер", {content:"numberFilter"}],
				width: 70,
				sort: 'int'
			},{
				map: '#time_created#',
				header: ["Дата", {content:"dateFilter"}],
				width: 110,
				sort: 'string',
				format: function (value) {
					return webix.i18n.dateFormatStr(new Date(value));
				}
			},{
				map: '#ticket_type_name#',
				header: ["Тип", {content:"selectFilter"}],
				width: 120
			},{
				map: '#ticket_status_name#',
				header: ["Статус", {content:"selectFilter"}],
				width: 150,
				sort: 'string'
			},{
				map: '#postaddr#',
				header: ["Адрес", {content:"textFilter"}],
				fillspace: true,
				sort: 'string'
			},{
				map: '#phone#',
				header: ["Телефон", {content:"textFilter"}],
				width: 110
			},{
				map: '#last_comment#',
				header: ["Комментарий", {content:"textFilter"}],
				width: 270
			}],
			select: 'row',
			on: {
				onItemDblClick: function(id, e, node) {
					var row = this.getItem(id);
					openPage("ticketEdit", row.ticket_id);
				}
			}
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				cmd: 'select', params: {table: 'tickets'}
			}, function(resp) {
				var rows = resp.rows;
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


/* Add ticket */

initPage("ticketAdd", "Добавить заявку", undefined, async function(pageui, uid, params) {

	var ticket_id = parseInt(params);

	var resp = await sendRequest({cmd: 'select', params: {table: 'ticket_statuses'}});
	var statuses = resp.rows;

	var statusOptions = [];
	for (var i in statuses) {
		statusOptions.push({id: statuses[i].ticket_status, value: statuses[i].ticket_status_name});
	}

	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Добавить заявку",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formTicketAdd",
			width: 300,
			elements: [
				{view: 'select', label: 'Статус заявки', options: statusOptions, name: 'ticket_status'},
				{view: 'text', type: 'text', label: 'Краткий комментарий', labelPosition: 'top', name: 'comment'},
				{
					view: "button",
					value: "Сохранить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formTicketAdd").getValues();
						p.ticket_id = ticket_id;
						wsSendMessage({
							cmd: 'perform',
							params: {
								proc: 'ticket_add',
								params: [JSON.stringify(p)]
							}
						}, function(resp) {
							win.close();
							webix.alert("Данные обновлены.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formTicketAdd"));
});

/* Edit ticket */

initPage("ticketEdit", "Редактировать заявку", undefined, async function(pageui, uid, params) {

	var ticket_id = parseInt(params);

	var resp = await sendRequest({cmd: 'select', params: {table: 'tickets', condition: {ticket_id: ticket_id}}});
	var ticket = resp.rows[0];

	var resp = await sendRequest({cmd: 'select', params: {table: 'ticket_statuses'}});
	var statuses = resp.rows;

	var statusOptions = [];
	for (var i in statuses) {
		statusOptions.push({id: statuses[i].ticket_status, value: statuses[i].ticket_status_name});
	}

	var win = webix.ui({
		view: 'window',
		hidden: false,
		head: "Редактировать заявку",
		move: true,
		position: 'center',
		body: {
			view: 'form',
			id: "formTicketEdit",
			width: 500,
			elements: [
				{view: 'select', label: 'Статус заявки', options: statusOptions, value: ticket.ticket_status, name: 'ticket_status'},
				{view: 'textarea', type: 'text', label: 'Краткий комментарий', labelPosition: 'top', height: 100, value: ticket.last_comment, name: 'comment'},
				{view: 'text', label: 'Создан', labelPosition: 'top', value: ticket.create_oper_name, disabled: true},
				{
					view: "button",
					value: "Сохранить",
					width: 150,
					align: "center",
					click: function() {
						var p = $$("formTicketEdit").getValues();
						p.ticket_id = ticket_id;
						wsSendMessage({
							cmd: 'perform',
							params: {
								proc: 'ticket_edit',
								params: [JSON.stringify(p)]
							}
						}, function(resp) {
							win.close();
							webix.alert("Данные обновлены.");
						});
					}
				}
			]
		}
	});

	webix.UIManager.setFocus($$("formTicketEdit"));
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
				sort: 'string',
				format: function (value) {
					return webix.i18n.dateFormatStr(new Date(value));
				}
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
				cmd: 'select', params: {table: 'report_payments'}
			}, function(resp) {
				var rows = resp.rows;
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
				width: 200,
				sort: 'string',
				format: function (value) {
					var format = webix.Date.dateToStr("%F %Y");
					return format(new Date(value));
				}
			},{
				map: '#payments#',
				header: "Оплачено",
				width: 200
			},{
				map: '#invoices#',
				header: "Услуг связи",
				width: 200
			},{
				map: '#cost_connect#',
				header: "Подключение",
				fillspace: true
			}],
			select: 'row'
		}]
	}, function(pageui, uid, params) {
		var update = function() {
			wsSendMessage({
				cmd: 'select', params: {table: 'report_invoices'}
			}, function(resp) {
				var rows = resp.rows;
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

