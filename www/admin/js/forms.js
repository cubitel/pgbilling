
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
			template: "<div class='page-header'>Платежи</div>",
			autoheight: true
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
	}, function() {
		wsSendMessage({
			selectrequest: {table: 'payments'}
		}, function(resp) {
			var rows = parseSelectResponse(resp.selectresponse);
			$$("payments-list").parse(rows);
		});
	}
);


/* Sessions page */

initPage("sessions", "Активные сессии", {
		rows: [{
			template: "<div class='page-header'>Активные сессии</div>",
			autoheight: true
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
			}],
			select: 'row'
		}]
	}, function() {
		wsSendMessage({
			selectrequest: {table: 'radius_sessions'}
		}, function(resp) {
			var rows = parseSelectResponse(resp.selectresponse);
			$$("session-list").parse(rows);
		});
	}
);


/* Services page */

initPage("services", "Услуги", {
		rows: [{
			template: "<div class='page-header'>Услуги</div>",
			autoheight: true
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
				map: '#user_name#',
				header: "Абонент",
				width: 180,
			},{
				map: '#postaddr#',
				header: "Адрес оказания услуги",
				fillspace: true,
				sort: 'string'
			}],
			select: 'row'
		}]
	}, function() {
		wsSendMessage({
			selectrequest: {table: 'services'}
		}, function(resp) {
			var rows = parseSelectResponse(resp.selectresponse);
			$$("services-list").parse(rows);
		});
	}
);


/* Tickets page */

initPage("tickets", "Заявки", {
		rows: [{
			template: "<div class='page-header'>Заявки</div>",
			autoheight: true
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
				width: 150
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
	}, function() {
		wsSendMessage({
			selectrequest: {table: 'tickets'}
		}, function(resp) {
			var rows = parseSelectResponse(resp.selectresponse);
			$$("tickets-list").parse(rows);
		});
	});
