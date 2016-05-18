--
-- SYSTEM
--

SET SCHEMA 'system';

-- system.users

CREATE TABLE IF NOT EXISTS users (
    user_id serial PRIMARY KEY,
    user_name varchar(128) NOT NULL,
    login_type integer NOT NULL,
    login varchar(64) NOT NULL,
    pass varchar(64),
    totp_key varchar(128),
    UNIQUE(login)
);

COMMENT ON TABLE users IS 'Абоненты';
COMMENT ON COLUMN users.user_id IS 'Идентификатор абонента';
COMMENT ON COLUMN users.user_name IS 'Читабельное имя пользователя';
COMMENT ON COLUMN users.login_type IS 'Метод авторизации абонента в ЛК';
COMMENT ON COLUMN users.login IS 'Логин абонента в ЛК';
COMMENT ON COLUMN users.pass IS 'Пароль абонента в ЛК';
COMMENT ON COLUMN users.totp_key IS 'Секретный ключ для TOTP авторизации';

-- system.operators

CREATE TABLE IF NOT EXISTS operators (
    operator_id serial PRIMARY KEY,
    operator_name varchar(128) NOT NULL,
    login_type integer NOT NULL,
    login varchar(64) NOT NULL,
    pass varchar(64),
    totp_key varchar(128),
    UNIQUE(login)
);

COMMENT ON TABLE operators IS 'Операторы';
COMMENT ON COLUMN operators.operator_id IS 'Идентификатор оператора';
COMMENT ON COLUMN operators.operator_name IS 'Читабельное имя пользователя';
COMMENT ON COLUMN operators.login_type IS 'Метод авторизации оператора';
COMMENT ON COLUMN operators.login IS 'Логин оператора';
COMMENT ON COLUMN operators.pass IS 'Пароль оператора';
COMMENT ON COLUMN operators.totp_key IS 'Секретный ключ для TOTP авторизации';

-- system.accounts

CREATE TABLE IF NOT EXISTS accounts (
    account_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_number varchar(32) NOT NULL,
    balance numeric(10,2) NOT NULL,
    UNIQUE(account_number)
);

COMMENT ON TABLE accounts IS 'Лицевые счета';
COMMENT ON COLUMN accounts.account_id IS 'Идентификатор лицевого счета';
COMMENT ON COLUMN accounts.user_id IS 'Идентификатор абонента';
COMMENT ON COLUMN accounts.account_number IS 'Номер лицевого счета';
COMMENT ON COLUMN accounts.balance IS 'Баланс лицевого счета';

-- system.account_logs

CREATE TABLE IF NOT EXISTS account_logs (
    log_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_id integer NOT NULL REFERENCES accounts,
    oper_time timestamp NOT NULL,
    amount numeric(10,2) NOT NULL,
    descr varchar(128) NOT NULL
);

COMMENT ON TABLE account_logs IS 'Движения по лицевым счетам';
COMMENT ON COLUMN account_logs.log_id IS 'Идентификатор записи';
COMMENT ON COLUMN account_logs.account_id IS 'Идентификатор лицевого счета';
COMMENT ON COLUMN account_logs.oper_time IS 'Дата и время операции';
COMMENT ON COLUMN account_logs.amount IS 'Сумма операции';
COMMENT ON COLUMN account_logs.descr IS 'Описание операции';

-- system.addr_fias

CREATE TABLE IF NOT EXISTS addr_fias (
	guid varchar(36) NOT NULL PRIMARY KEY,
	parent_guid varchar(36),
	short_name varchar(10) NOT NULL,
	off_name varchar(120) NOT NULL,
	postal_code varchar(6) NOT NULL
);

COMMENT ON TABLE addr_fias IS 'Каталог адресов по ФИАС';

-- system.addr_fias_houses

CREATE TABLE IF NOT EXISTS addr_fias_houses (
	house_guid varchar(36) NOT NULL PRIMARY KEY,
	street_guid varchar(36) NOT NULL REFERENCES addr_fias(guid),
	house_num varchar(10) NOT NULL
);

COMMENT ON TABLE addr_fias_houses IS 'Каталог домов по ФИАС';

-- system.addr_houses

CREATE TABLE IF NOT EXISTS addr_houses (
	house_id serial PRIMARY KEY,
	street_guid varchar(36) NOT NULL REFERENCES addr_fias(guid),
	house_number varchar(10) NOT NULL,
	location geometry(Point, 4326)
);

COMMENT ON TABLE addr_houses IS 'Каталог домов';

-- system.addr_connected

CREATE TABLE IF NOT EXISTS addr_connected (
	record_id serial PRIMARY KEY,
	street_guid varchar(36) NOT NULL REFERENCES addr_fias(guid),
	odd_min integer NOT NULL,
	odd_max integer NOT NULL,
	even_min integer NOT NULL,
	even_max integer NOT NULL
);

COMMENT ON TABLE addr_connected IS 'Зона охвата';

-- system.devices

CREATE TABLE IF NOT EXISTS devices (
	device_id serial PRIMARY KEY,
	device_ip inet NOT NULL,
	device_mac macaddr,
	snmp_community varchar(16)
);

COMMENT ON TABLE devices IS 'Сетевые устройства';

-- system.device_ports

CREATE TABLE IF NOT EXISTS device_ports (
	port_id serial PRIMARY KEY,
	device_id integer NOT NULL REFERENCES devices,
	snmp_index integer NOT NULL,
	port_name varchar(32) NOT NULL
);

COMMENT ON TABLE device_ports IS 'Порты сетевых устройств';

-- system.tarifs

CREATE TABLE IF NOT EXISTS tarifs (
    tarif_id serial PRIMARY KEY,
    group_id integer NOT NULL,
    tarif_name varchar(64) NOT NULL,
    active integer NOT NULL DEFAULT 1
);

COMMENT ON TABLE tarifs IS 'Тарифные планы';
COMMENT ON COLUMN tarifs.tarif_id IS 'Идентификатор тарифа';
COMMENT ON COLUMN tarifs.group_id IS 'Группа тарифов';
COMMENT ON COLUMN tarifs.tarif_name IS 'Наименование тарифа';
COMMENT ON COLUMN tarifs.active IS 'Признак возможности перехода на тариф';

-- system.payagents

CREATE TABLE IF NOT EXISTS payagents (
    agent_id serial PRIMARY KEY,
    agent_name varchar(128) NOT NULL
);

-- system.payments

CREATE TABLE IF NOT EXISTS payments (
    payment_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_id integer NOT NULL REFERENCES accounts,
    oper_time timestamp NOT NULL,
    amount numeric(10,2) NOT NULL,
    agent_id integer NOT NULL REFERENCES payagents,
    agent_ref varchar(128) NOT NULL,
    descr varchar(128) NOT NULL,
    external_id varchar(128)
);

CREATE UNIQUE INDEX IF NOT EXISTS payments_external_id ON payments(external_id);
CREATE UNIQUE INDEX IF NOT EXISTS payments_agent_ref ON payments(agent_ref, agent_id);

CREATE OR REPLACE RULE insert_notify AS
    ON INSERT TO payments
    DO ALSO NOTIFY payments_insert;

-- system.radius_attrs

CREATE TABLE IF NOT EXISTS radius_attrs (
	attr_id serial PRIMARY KEY,
	service_state integer NOT NULL,
	attr_name varchar(128) NOT NULL,
	attr_value varchar(128) NOT NULL
);

-- system.service_states

CREATE TABLE IF NOT EXISTS service_state_names (
	service_state integer PRIMARY KEY,
	service_state_name varchar(128) NOT NULL
);

INSERT INTO service_state_names (service_state, service_state_name) VALUES(1, 'Активно') ON CONFLICT DO NOTHING;
INSERT INTO service_state_names (service_state, service_state_name) VALUES(2, 'Заблокировано') ON CONFLICT DO NOTHING;

-- system.service_types

CREATE TABLE IF NOT EXISTS service_types (
	service_type integer PRIMARY KEY,
	service_type_name varchar(128) NOT NULL
);

INSERT INTO service_types (service_type, service_type_name) VALUES(1, 'Доступ в интернет') ON CONFLICT DO NOTHING;

-- system.services

CREATE TABLE IF NOT EXISTS services (
    service_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_id integer NOT NULL REFERENCES accounts,
    service_type integer NOT NULL REFERENCES service_types,
    service_name varchar(128) NOT NULL,
    service_pass varchar(128),
    service_state integer NOT NULL REFERENCES service_state_names DEFAULT 1,
    current_tarif integer REFERENCES tarifs(tarif_id),
    next_tarif integer REFERENCES tarifs(tarif_id),
    inet_speed integer,
    mac_address macaddr,
    house_id integer REFERENCES addr_houses,
    flat_number integer,
    serial_no varchar(32),
    port_id integer REFERENCES device_ports ON DELETE SET NULL,
    CHECK(service_type != 1 OR service_state != 1 OR (inet_speed IS NOT NULL AND inet_speed > 0))
);

CREATE UNIQUE INDEX IF NOT EXISTS services_mac ON services (mac_address);
CREATE UNIQUE INDEX IF NOT EXISTS services_name ON services(service_name, service_type);
CREATE UNIQUE INDEX IF NOT EXISTS services_serial_no ON services (serial_no);

COMMENT ON TABLE services IS 'Услуги';
COMMENT ON COLUMN services.service_id IS 'Идентификатор услуги';
COMMENT ON COLUMN services.user_id IS 'Идентификатор абонента';
COMMENT ON COLUMN services.account_id IS 'Идентификатор лицевого счета';
COMMENT ON COLUMN services.service_type IS 'Тип услуги';
COMMENT ON COLUMN services.service_name IS 'Имя услуги (логин)';
COMMENT ON COLUMN services.service_pass IS 'Пароль на услугу';
COMMENT ON COLUMN services.service_state IS 'Состояние услуги';
COMMENT ON COLUMN services.current_tarif IS 'Идентификатор текущего тарифного плана';
COMMENT ON COLUMN services.next_tarif IS 'Идентификатор следующего тарифного плана';
COMMENT ON COLUMN services.inet_speed IS 'Ограничение скорости доступа в интернет в кбит/с';

-- system.services_addr

CREATE TABLE IF NOT EXISTS services_addr (
    addr_id serial PRIMARY KEY,
    service_id integer NOT NULL REFERENCES services ON DELETE CASCADE,
    ip_address inet NOT NULL,
    EXCLUDE USING gist(ip_address inet_ops WITH &&)
);

COMMENT ON TABLE services_addr IS 'IP адреса для услуг';

-- system.task_status_names

CREATE TABLE IF NOT EXISTS task_status_names (
	task_status integer PRIMARY KEY,
	task_status_name varchar(128) NOT NULL
);

INSERT INTO task_status_names (task_status, task_status_name) VALUES(1, 'В очереди') ON CONFLICT DO NOTHING;
INSERT INTO task_status_names (task_status, task_status_name) VALUES(2, 'Выполняется') ON CONFLICT DO NOTHING;
INSERT INTO task_status_names (task_status, task_status_name) VALUES(3, 'Выполнено') ON CONFLICT DO NOTHING;
INSERT INTO task_status_names (task_status, task_status_name) VALUES(4, 'Отменено') ON CONFLICT DO NOTHING;
INSERT INTO task_status_names (task_status, task_status_name) VALUES(5, 'Ошибка') ON CONFLICT DO NOTHING;

-- system.tasks

CREATE TABLE IF NOT EXISTS tasks (
    task_id serial PRIMARY KEY,
    system_id integer NOT NULL DEFAULT 1,
    user_id integer REFERENCES users ON DELETE CASCADE,
    account_id integer REFERENCES accounts ON DELETE CASCADE,
    service_id integer REFERENCES services ON DELETE CASCADE,
    tarif_id integer REFERENCES tarifs ON DELETE CASCADE,
    task_name varchar(128) NOT NULL,
    task_params varchar(128),
    task_status integer NOT NULL REFERENCES task_status_names DEFAULT 1,
    time_created timestamp NOT NULL DEFAULT now(),
    time_completed timestamp
);

COMMENT ON TABLE tasks IS 'Задачи для внешних систем';

CREATE OR REPLACE RULE insert_notify AS
    ON INSERT TO tasks
    DO ALSO NOTIFY tasks_insert;

-- system.ticket_statuses

CREATE TABLE IF NOT EXISTS ticket_statuses (
	ticket_status integer NOT NULL PRIMARY KEY,
	ticket_status_name varchar(128) NOT NULL
);

INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(1, 'Новая') ON CONFLICT DO NOTHING;

-- system.ticket_types

CREATE TABLE IF NOT EXISTS ticket_types (
	ticket_type integer NOT NULL PRIMARY KEY,
	ticket_type_name varchar(128) NOT NULL
);

INSERT INTO ticket_types (ticket_type, ticket_type_name) VALUES(1, 'Подключение услуги') ON CONFLICT DO NOTHING;

-- system.tickets

CREATE TABLE IF NOT EXISTS tickets (
	ticket_id serial PRIMARY KEY,
	ticket_type integer NOT NULL REFERENCES ticket_types,
	ticket_status integer NOT NULL REFERENCES ticket_statuses DEFAULT 1,
	user_id integer REFERENCES users ON DELETE CASCADE,
	service_id integer REFERENCES services ON DELETE CASCADE,
	service_type integer REFERENCES service_types,
	house_id integer REFERENCES addr_houses,
	street_guid varchar(36) REFERENCES addr_fias(guid),
	house_number varchar(10),
	phone varchar(10) CHECK(phone SIMILAR TO '[0-9]{10}'),
	time_created timestamp NOT NULL DEFAULT now(),
	time_completed timestamp
);

-- system.user_contact_types

CREATE TABLE IF NOT EXISTS user_contact_types (
	contact_type integer NOT NULL PRIMARY KEY,
	contact_type_name varchar(128) NOT NULL
);

INSERT INTO user_contact_types (contact_type, contact_type_name) VALUES(1, 'Телефон') ON CONFLICT DO NOTHING;

-- system.user_contacts

CREATE TABLE IF NOT EXISTS user_contacts (
	contact_id serial PRIMARY KEY,
	user_id integer NOT NULL REFERENCES users,
	contact_type integer NOT NULL REFERENCES user_contact_types,
	contact_value varchar(128) NOT NULL
	CHECK(contact_type != 1 OR (contact_value SIMILAR TO '[0-9]{10}'))
);

-- Functions

CREATE OR REPLACE FUNCTION addr_set_location(n_house_id integer, n_lon float, n_lat float) RETURNS void AS $$
BEGIN
	UPDATE addr_houses SET location = ST_SetSRID(ST_Point(n_lon, n_lat), 4326) WHERE house_id = n_house_id;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION services_get_addr(n_house_id integer, n_flat integer) RETURNS varchar AS $$
DECLARE
	m_address varchar;
	m_house addr_houses%rowtype;
	m_fias addr_fias%rowtype;
	m_guid varchar;
	i integer;
BEGIN
	IF n_house_id IS NULL THEN
		RETURN '';
	END IF;

	SELECT * INTO m_house FROM addr_houses WHERE house_id = n_house_id;

	m_guid := m_house.street_guid;
	m_address := '';
	FOR i IN 1..3 LOOP
		SELECT * INTO m_fias FROM addr_fias WHERE guid = m_guid;
		IF NOT FOUND THEN
			EXIT;
		END IF;
		m_address := m_fias.short_name || ' ' || m_fias.off_name || ', ' || m_address;
		m_guid := m_fias.parent_guid;
	END LOOP;
	
	m_address := m_address || 'д. ' || m_house.house_number;

	RETURN m_address;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;
