--
-- SYSTEM
--

SET SCHEMA 'system';

-- system.users

CREATE TABLE IF NOT EXISTS users (
    user_id serial PRIMARY KEY,
    user_name varchar(128) NOT NULL,
    login_type integer NOT NULL DEFAULT 1,
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

CREATE INDEX IF NOT EXISTS addr_fias_parent_guid ON addr_fias(parent_guid);

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
	location geometry(Point, 4326),
	house_state integer NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS house_numbers ON addr_houses(street_guid, house_number);

COMMENT ON TABLE addr_houses IS 'Каталог домов';

-- system.boxes

CREATE TABLE IF NOT EXISTS boxes (
	box_id serial PRIMARY KEY,
	box_location geometry(Point, 4326),
	port_count integer NOT NULL DEFAULT 0
);

-- system.device_models

CREATE TABLE IF NOT EXISTS device_models (
	model_id serial PRIMARY KEY,
	model_code varchar(64) NOT NULL,
	model_name varchar(128) NOT NULL
);

-- system.networks

CREATE TABLE IF NOT EXISTS networks (
	network_id serial PRIMARY KEY,
	network_addr inet NOT NULL,
	addr_start inet NOT NULL,
	addr_stop inet NOT NULL
);

-- system.devices

CREATE TABLE IF NOT EXISTS devices (
	device_id serial PRIMARY KEY,
	device_ip inet NOT NULL,
	device_mac macaddr,
	snmp_community varchar(16),
	network_id integer REFERENCES networks
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

-- system.divisions

CREATE TABLE IF NOT EXISTS divisions (
	division_id serial PRIMARY KEY,
	division_name varchar(128) NOT NULL
);

COMMENT ON TABLE divisions IS 'Отделы предприятия';

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
INSERT INTO service_state_names (service_state, service_state_name) VALUES(3, 'Новый') ON CONFLICT DO NOTHING;

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

CREATE OR REPLACE FUNCTION services_after_update() RETURNS trigger AS $$
DECLARE
	m_session_id bigint;
BEGIN
	IF (NEW.service_state != OLD.service_state) OR (NEW.inet_speed != OLD.inet_speed) THEN
		SELECT session_id INTO m_session_id FROM sessions WHERE service_id = NEW.service_id AND active = 1;
		IF FOUND THEN
			PERFORM pg_notify('radius_coa', m_session_id::text);
		END IF;
	END IF;
	
	RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_update ON services;
CREATE TRIGGER after_update AFTER UPDATE ON services
	FOR EACH ROW EXECUTE PROCEDURE services_after_update();

-- system.services_addr

CREATE TABLE IF NOT EXISTS services_addr (
    addr_id serial PRIMARY KEY,
    service_id integer NOT NULL REFERENCES services ON DELETE CASCADE,
    ip_address inet NOT NULL,
    EXCLUDE USING gist(ip_address inet_ops WITH &&)
);

COMMENT ON TABLE services_addr IS 'IP адреса для услуг';

-- system.sessions

CREATE TABLE IF NOT EXISTS sessions (
	session_id bigserial PRIMARY KEY,
	acct_session_id varchar(64) NOT NULL,
	nas_ip_address inet NOT NULL,
	active integer NOT NULL DEFAULT 1,
	create_time timestamp NOT NULL DEFAULT now(),
	update_time timestamp NOT NULL DEFAULT now(),
	class varchar(64) NOT NULL,
	service_id integer REFERENCES services ON DELETE SET NULL,
	username varchar(64) NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS sessions_acct_id ON sessions(acct_session_id);

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
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(2, 'Проверка возможности подключения') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(3, 'В работе') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(4, 'Выполнена') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(5, 'Отказ оператора') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(6, 'Отказ абонента') ON CONFLICT DO NOTHING;

-- system.ticket_types

CREATE TABLE IF NOT EXISTS ticket_types (
	ticket_type integer NOT NULL PRIMARY KEY,
	ticket_type_name varchar(128) NOT NULL
);

INSERT INTO ticket_types (ticket_type, ticket_type_name) VALUES(1, 'Подключение услуги') ON CONFLICT DO NOTHING;
INSERT INTO ticket_types (ticket_type, ticket_type_name) VALUES(2, 'Отключение услуги') ON CONFLICT DO NOTHING;

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
	time_completed timestamp,
	division_id integer REFERENCES divisions,
	location geometry(Point, 4326)
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

-- system.user_devices

CREATE TABLE IF NOT EXISTS user_devices (
	device_id serial PRIMARY KEY,
	model_id integer NOT NULL REFERENCES device_models,
	serial_no varchar(32) NOT NULL,
	service_id integer REFERENCES services
);

-- Functions

CREATE OR REPLACE FUNCTION addr_set_location(n_house_id integer, n_lon float, n_lat float) RETURNS void AS $$
BEGIN
	UPDATE addr_houses SET location = ST_SetSRID(ST_Point(n_lon, n_lat), 4326) WHERE house_id = n_house_id;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION account_get_next() RETURNS varchar AS $$
DECLARE
	m_account integer;
	m_mod integer;
BEGIN
	SELECT MAX(left(account_number, 5)::integer) + 1 INTO m_account FROM accounts WHERE length(account_number) = 6;

	m_mod = m_account % 11;
	IF m_mod = 10 THEN
		m_mod = 0;
	END IF;

	RETURN m_account::varchar || m_mod::varchar;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_free_ip(ip_start inet, ip_stop inet) RETURNS inet AS $$
DECLARE
	m_ip inet;
BEGIN
	SELECT MAX(ip_address) + 1 INTO m_ip
		FROM services_addr
		WHERE ip_address >= ip_start AND ip_address <= ip_stop;

	RETURN m_ip;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_subscriber() RETURNS varchar AS $$
DECLARE
	m_user_id integer;
	m_account_id integer;
	m_account_number varchar;
BEGIN
	SELECT account_get_next() INTO m_account_number;

    INSERT INTO users (user_name, login_type, login, pass) VALUES(m_account_number, 1, m_account_number, m_account_number);
    SELECT lastval() INTO m_user_id;

    INSERT INTO accounts (user_id, account_number, balance) VALUES(m_user_id, m_account_number, 0);
    SELECT lastval() INTO m_account_id;

    RETURN m_account_number;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_subscriber_service(vc_account_number varchar, n_tarif_id integer, n_house_id integer, n_flat_number integer) RETURNS integer AS $$
DECLARE
	m_account accounts%rowtype;
	m_service_id integer;
BEGIN
	SELECT * INTO m_account FROM accounts WHERE account_number = vc_account_number;

	INSERT INTO services
		(user_id, account_id, service_type, service_name, inet_speed, current_tarif, next_tarif, house_id, flat_number)
		VALUES(m_account.user_id, m_account.account_id, 1, vc_account_number || '-1', 50000, n_tarif_id, n_tarif_id, n_house_id, n_flat_number);
    SELECT lastval() INTO m_service_id;

    RETURN m_service_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
	FOR i IN 1..2 LOOP
		SELECT * INTO m_fias FROM addr_fias WHERE guid = m_guid;
		IF NOT FOUND THEN
			EXIT;
		END IF;
		m_address := m_fias.short_name || ' ' || m_fias.off_name || ', ' || m_address;
		m_guid := m_fias.parent_guid;
	END LOOP;
	
	m_address := m_address || 'д. ' || m_house.house_number;
	IF n_flat IS NOT NULL THEN
		m_address := m_address || ', кв. ' || n_flat;
	END IF;

	RETURN m_address;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION generate_totp(secret bytea, t bigint) RETURNS char(6) AS $$
DECLARE
    buf bytea;
    byte int;
    hash bytea;
    n int;
    code int;
BEGIN
 -- Initialize a 64-bit buffer.
    buf = E'\\x0000000000000000';
 -- Write the time step to the buffer in big-endian format.
    FOR i IN 0..7 LOOP
        byte = t :: bit(8) :: int;
        buf  = set_byte(buf, 7 - i, byte);
        t    = t >> 8;
    END LOOP;
 -- Calculate the passcode.
    hash = hmac(buf, secret, 'sha1');
    n    = get_byte(hash, 19) & 15;
    code = (((get_byte(hash, n + 0) & 127) << 24)|
            ((get_byte(hash, n + 1) & 255) << 16)|
            ((get_byte(hash, n + 2) & 255) << 08)|
            ((get_byte(hash, n + 3) & 255) << 00)) % 1000000;
 -- Return the passcode as a six-character string.
    RETURN LPAD(code :: text, 6, '0');
END;
$$
LANGUAGE plpgsql STRICT IMMUTABLE;
