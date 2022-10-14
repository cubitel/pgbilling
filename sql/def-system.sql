--
-- SYSTEM
--

SET SCHEMA 'system';

-- system.acl_privileges

CREATE TABLE IF NOT EXISTS acl_privileges (
	priv_name text NOT NULL PRIMARY KEY,
	description text NOT NULL,
	default_group_ids integer[]
);

COMMENT ON TABLE acl_privileges IS 'Список существующих в системе привилегий';

-- system.acl_groups

CREATE TABLE IF NOT EXISTS acl_groups (
	group_id integer PRIMARY KEY,
	parent_group_id integer REFERENCES acl_groups(group_id),
	group_name text NOT NULL,
	priv_granted text[] NOT NULL DEFAULT '{}',
	priv_revoked text[] NOT NULL DEFAULT '{}',
	UNIQUE(group_name)
);

-- default system acl groups

CREATE OR REPLACE FUNCTION acl_privileges_insert() RETURNS trigger AS $$
BEGIN
	UPDATE system.acl_groups SET priv_granted = priv_granted || NEW.priv_name WHERE ARRAY[group_id] && NEW.default_group_ids;
	RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS insert ON acl_privileges;
CREATE TRIGGER insert AFTER INSERT ON acl_privileges
	FOR EACH ROW EXECUTE PROCEDURE acl_privileges_insert();

INSERT INTO acl_groups (group_id, parent_group_id, group_name) VALUES(1, NULL, 'Операторы') ON CONFLICT DO NOTHING;
INSERT INTO acl_groups (group_id, parent_group_id, group_name) VALUES(2, 1, 'Администраторы') ON CONFLICT DO NOTHING;

INSERT INTO acl_privileges (priv_name, description, default_group_ids) VALUES('change_password', 'Смена пароля оператора', '{1}') ON CONFLICT DO NOTHING;
INSERT INTO acl_privileges (priv_name, description, default_group_ids) VALUES('report.finance', 'Просмотр финансовых отчетов', '{2}') ON CONFLICT DO NOTHING;
INSERT INTO acl_privileges (priv_name, description, default_group_ids) VALUES('ticket.view', 'Просмотр заявок', '{2}') ON CONFLICT DO NOTHING;
INSERT INTO acl_privileges (priv_name, description, default_group_ids) VALUES('ticket.edit', 'Редактирование заявок', '{2}') ON CONFLICT DO NOTHING;
INSERT INTO acl_privileges (priv_name, description, default_group_ids) VALUES('service.view', 'Просмотр услуг пользователей', '{2}') ON CONFLICT DO NOTHING;
INSERT INTO acl_privileges (priv_name, description, default_group_ids) VALUES('service.edit', 'Редактирование услуг пользователей', '{2}') ON CONFLICT DO NOTHING;

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
    acl_groups integer[] NOT NULL DEFAULT '{}',
	priv_granted text[] NOT NULL DEFAULT '{}',
	priv_revoked text[] NOT NULL DEFAULT '{}',
    UNIQUE(login)
);

COMMENT ON TABLE operators IS 'Операторы';
COMMENT ON COLUMN operators.operator_id IS 'Идентификатор оператора';
COMMENT ON COLUMN operators.operator_name IS 'Читабельное имя пользователя';
COMMENT ON COLUMN operators.login_type IS 'Метод авторизации оператора';
COMMENT ON COLUMN operators.login IS 'Логин оператора';
COMMENT ON COLUMN operators.pass IS 'Пароль оператора';
COMMENT ON COLUMN operators.totp_key IS 'Секретный ключ для TOTP авторизации';

-- system.agreements

CREATE TABLE IF NOT EXISTS agreements (
	agreement_id serial PRIMARY KEY,
	agrm_number text NOT NULL,
	start_date date NOT NULL,
	end_date date,
	confirmed int NOT NULL DEFAULT 0,
	UNIQUE(agrm_number,start_date)
);

-- system.accounts

CREATE TABLE IF NOT EXISTS accounts (
    account_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_number varchar(32) NOT NULL,
    balance numeric(10,2) NOT NULL,
    time_created timestamp,
    promised_end_date timestamp,
    agreement_id integer REFERENCES agreements,
    promised_count integer NOT NULL DEFAULT 0,
    UNIQUE(account_number)
);

COMMENT ON TABLE accounts IS 'Лицевые счета';
COMMENT ON COLUMN accounts.account_id IS 'Идентификатор лицевого счета';
COMMENT ON COLUMN accounts.user_id IS 'Идентификатор абонента';
COMMENT ON COLUMN accounts.account_number IS 'Номер лицевого счета';
COMMENT ON COLUMN accounts.balance IS 'Баланс лицевого счета';

-- system.cash_flows

CREATE TABLE IF NOT EXISTS cash_flows (
	cash_flow_type SERIAL PRIMARY KEY,
	cash_flow_name text NOT NULL
);

-- system.account_logs

CREATE TABLE IF NOT EXISTS account_logs (
    log_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_id integer NOT NULL REFERENCES accounts,
    oper_time timestamp NOT NULL,
    amount numeric(10,2) NOT NULL,
    descr varchar(128) NOT NULL,
    cash_flow_type integer REFERENCES cash_flows
);

COMMENT ON TABLE account_logs IS 'Движения по лицевым счетам';
COMMENT ON COLUMN account_logs.log_id IS 'Идентификатор записи';
COMMENT ON COLUMN account_logs.account_id IS 'Идентификатор лицевого счета';
COMMENT ON COLUMN account_logs.oper_time IS 'Дата и время операции';
COMMENT ON COLUMN account_logs.amount IS 'Сумма операции';
COMMENT ON COLUMN account_logs.descr IS 'Описание операции';

CREATE OR REPLACE FUNCTION account_logs_change() RETURNS trigger AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		UPDATE accounts SET balance = balance + NEW.amount WHERE account_id = NEW.account_id;
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF OLD.account_id != NEW.account_id THEN
			UPDATE accounts SET balance = balance - OLD.amount WHERE account_id = OLD.account_id;
			UPDATE accounts SET balance = balance + NEW.amount WHERE account_id = NEW.account_id;
		ELSE
			UPDATE accounts SET balance = balance + NEW.amount - OLD.amount WHERE account_id = NEW.account_id;
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		UPDATE accounts SET balance = balance - OLD.amount WHERE account_id = OLD.account_id;
		RETURN OLD;
	END IF;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS change ON account_logs;
CREATE TRIGGER change AFTER INSERT OR UPDATE OR DELETE ON account_logs
	FOR EACH ROW EXECUTE PROCEDURE account_logs_change();

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
	location public.geometry(Point, 4326),
	house_state integer NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS house_numbers ON addr_houses(street_guid, house_number);

COMMENT ON TABLE addr_houses IS 'Каталог домов';

-- system.place_types

CREATE TABLE IF NOT EXISTS place_types (
	place_type serial PRIMARY KEY,
	place_type_name text NOT NULL
);

COMMENT ON TABLE place_types IS 'Типы мест (локаций)';

-- system.places

CREATE TABLE IF NOT EXISTS places (
	place_id serial PRIMARY KEY,
	place_type integer NOT NULL REFERENCES place_types,
	name text NOT NULL DEFAULT '',
	house_id integer REFERENCES addr_houses,
	location public.geometry(Point, 4326)
);

COMMENT ON TABLE places IS 'Места (локации)';

-- system.optic_cables

CREATE TABLE IF NOT EXISTS optic_cables (
	cable_id serial PRIMARY KEY,
	cable_type integer,
	cable_length integer
);

COMMENT ON TABLE optic_cables IS 'Кабели';

-- system.optic_box_types

CREATE TABLE IF NOT EXISTS optic_box_types (
	box_type serial PRIMARY KEY,
	box_type_name text NOT NULL
);

COMMENT ON TABLE optic_box_types IS 'Типы мест сварок';

-- system.optic_boxes

CREATE TABLE IF NOT EXISTS optic_boxes (
	box_id serial PRIMARY KEY,
	box_type integer NOT NULL REFERENCES optic_box_types,
	place_id integer NOT NULL REFERENCES places,
	cables integer[] NOT NULL,
	splices jsonb
);

COMMENT ON TABLE optic_boxes IS 'Места сварок';

-- system.device_models

CREATE TABLE IF NOT EXISTS device_models (
	model_id serial PRIMARY KEY,
	model_code varchar(64) NOT NULL,
	model_name varchar(128) NOT NULL
);

-- system.vlans

CREATE TABLE IF NOT EXISTS vlans (
	vlan_id serial PRIMARY KEY,
	vlan_tag integer NOT NULL,
	vlan_name text NOT NULL,
	UNIQUE(vlan_tag)
);

-- system.networks

CREATE TABLE IF NOT EXISTS networks (
	network_id serial PRIMARY KEY,
	network_addr inet NOT NULL,
	addr_start inet NOT NULL,
	addr_stop inet NOT NULL,
	interface_name text
);

-- system.devices

CREATE TABLE IF NOT EXISTS devices (
	device_id serial PRIMARY KEY,
	device_ip inet NOT NULL,
	device_mac macaddr,
	snmp_community varchar(16),
	network_id integer REFERENCES networks,
	port_offset int NOT NULL DEFAULT 0,
	device_description text
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

-- system.service_types

CREATE TABLE IF NOT EXISTS service_types (
	service_type integer PRIMARY KEY,
	service_type_name varchar(128) NOT NULL
);

INSERT INTO service_types (service_type, service_type_name) VALUES(1, 'Доступ в интернет') ON CONFLICT DO NOTHING;
INSERT INTO service_types (service_type, service_type_name) VALUES(2, 'Цифровое ТВ') ON CONFLICT DO NOTHING;

-- system.tarif_calc_types

CREATE TABLE IF NOT EXISTS tarif_calc_types (
	calc_type_id integer PRIMARY KEY,
	calc_type_name text NOT NULL
);

INSERT INTO tarif_calc_types (calc_type_id, calc_type_name) VALUES(1, 'Пропорционально точному времени') ON CONFLICT DO NOTHING;
INSERT INTO tarif_calc_types (calc_type_id, calc_type_name) VALUES(2, 'По количеству суток') ON CONFLICT DO NOTHING;

-- system.tarifs

CREATE TABLE IF NOT EXISTS tarifs (
    tarif_id serial PRIMARY KEY,
    group_id integer NOT NULL,
    tarif_name varchar(64) NOT NULL,
    active integer NOT NULL DEFAULT 1,
    abon numeric(10,2) NOT NULL DEFAULT 0,
    inet_speed integer NOT NULL DEFAULT 0,
    connect_price numeric(10,2) NOT NULL DEFAULT 0,
    external_id text,
    tarif_description text,
    calc_type_id integer NOT NULL DEFAULT 1 REFERENCES tarif_calc_types,
    service_type integer NOT NULL DEFAULT 1 REFERENCES service_types
);

COMMENT ON TABLE tarifs IS 'Тарифные планы';
COMMENT ON COLUMN tarifs.tarif_id IS 'Идентификатор тарифа';
COMMENT ON COLUMN tarifs.group_id IS 'Группа тарифов';
COMMENT ON COLUMN tarifs.tarif_name IS 'Наименование тарифа';
COMMENT ON COLUMN tarifs.active IS 'Признак возможности перехода на тариф';

-- system.tarif_options

CREATE TABLE IF NOT EXISTS tarif_options (
	option_id serial PRIMARY KEY,
	option_name text NOT NULL,
	external_id text,
	default_abon numeric(10,2) NOT NULL DEFAULT 0,
	allowed_tarifs integer[] NOT NULL DEFAULT '{}',
	cash_flow_type integer REFERENCES cash_flows,
	user_controlled integer NOT NULL DEFAULT 0
);

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
    external_id varchar(128),
	check_data text
);

CREATE UNIQUE INDEX IF NOT EXISTS payments_external_id ON payments(external_id);
CREATE UNIQUE INDEX IF NOT EXISTS payments_agent_ref ON payments(agent_ref, agent_id);

CREATE OR REPLACE RULE insert_notify AS
    ON INSERT TO payments
    DO ALSO NOTIFY payments_insert;

-- system.pon_ont_types

CREATE TABLE IF NOT EXISTS pon_ont_types (
	ont_type serial PRIMARY KEY,
	ont_type_name text NOT NULL,
	ont_profile text,
	ont_default_services jsonb
);

COMMENT ON TABLE pon_ont_types IS 'Модели ONT';

-- system pon_ont_states

CREATE TABLE IF NOT EXISTS pon_ont_states (
	ont_state integer PRIMARY KEY,
	ont_state_name text NOT NULL
);

COMMENT ON TABLE pon_ont_states IS 'Состояния ONT';

INSERT INTO pon_ont_states (ont_state, ont_state_name) VALUES(1, 'Активна') ON CONFLICT DO NOTHING;
INSERT INTO pon_ont_states (ont_state, ont_state_name) VALUES(2, 'Неактивна') ON CONFLICT DO NOTHING;
INSERT INTO pon_ont_states (ont_state, ont_state_name) VALUES(3, 'На удаление') ON CONFLICT DO NOTHING;
INSERT INTO pon_ont_states (ont_state, ont_state_name) VALUES(4, 'Удалена') ON CONFLICT DO NOTHING;

-- system.pon_services

CREATE TABLE IF NOT EXISTS pon_services (
	service_id serial PRIMARY KEY,
	service_name text NOT NULL,
	config_template jsonb NOT NULL
);

COMMENT ON TABLE pon_services IS 'Шаблоны конфигураций услуг PON';

-- system.pon_ont

CREATE TABLE IF NOT EXISTS pon_ont (
	ont_id serial PRIMARY KEY,
	ont_serial text,
	ont_next_serial text,
	ont_old_serial text,
	ont_type integer NOT NULL REFERENCES pon_ont_types,
	ont_state integer NOT NULL REFERENCES pon_ont_states,
	device_id integer REFERENCES devices,
	device_port text,
	api_fail_count integer NOT NULL DEFAULT 0,
	api_fail_message text,
	box_id integer REFERENCES optic_boxes,
	place_id integer REFERENCES places,
	services jsonb NOT NULL,
	create_time timestamptz NOT NULL,
	modify_time timestamptz,
	delete_time timestamptz,
	description text,
	current_config_id integer NOT NULL DEFAULT 0,
	next_config_id integer NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS pon_ont_serial ON pon_ont(ont_serial);
CREATE UNIQUE INDEX IF NOT EXISTS pon_ont_nextserial ON pon_ont(ont_next_serial);

COMMENT ON TABLE pon_ont IS 'Список обслуживаемых ONT';

-- system.radius_attrs

CREATE TABLE IF NOT EXISTS radius_attrs (
	attr_id serial PRIMARY KEY,
	service_state integer NOT NULL,
	attr_name varchar(128) NOT NULL,
	attr_value varchar(128) NOT NULL,
	in_coa integer NOT NULL DEFAULT 0,
	nas_ip text NOT NULL DEFAULT '%'
);

-- system.service_states

CREATE TABLE IF NOT EXISTS service_state_names (
	service_state integer PRIMARY KEY,
	service_state_name varchar(128) NOT NULL
);

INSERT INTO service_state_names (service_state, service_state_name) VALUES(1, 'Активно') ON CONFLICT DO NOTHING;
INSERT INTO service_state_names (service_state, service_state_name) VALUES(2, 'Заблокировано') ON CONFLICT DO NOTHING;
INSERT INTO service_state_names (service_state, service_state_name) VALUES(3, 'Новый') ON CONFLICT DO NOTHING;
INSERT INTO service_state_names (service_state, service_state_name) VALUES(4, 'Приостановлено') ON CONFLICT DO NOTHING;

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
    user_port integer,
    invoice_start timestamp,
    invoice_end timestamp,
    invoice_log_id integer REFERENCES account_logs(log_id),
    ont_id integer REFERENCES pon_ont,
    CHECK(service_type != 1 OR service_state != 1 OR (inet_speed IS NOT NULL AND inet_speed > 0))
);

CREATE UNIQUE INDEX IF NOT EXISTS services_mac ON services (mac_address);
CREATE UNIQUE INDEX IF NOT EXISTS services_name ON services(service_name, service_type);
CREATE UNIQUE INDEX IF NOT EXISTS services_serial_no ON services (serial_no, user_port);

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

CREATE TABLE IF NOT EXISTS service_invoices (
	invoice_id SERIAL PRIMARY KEY,
	service_id integer NOT NULL REFERENCES services ON DELETE CASCADE,
	option_id integer NOT NULL REFERENCES tarif_options,
	invoice_active integer NOT NULL DEFAULT 0,
	invoice_descr text NOT NULL,
	invoice_abon numeric(10,2) NOT NULL,
    invoice_start timestamp,
    invoice_end timestamp,
    invoice_log_id integer REFERENCES account_logs(log_id),
    cash_flow_type integer REFERENCES cash_flows
);

CREATE OR REPLACE FUNCTION services_update_invoice(n_service_id integer) RETURNS void AS $$
DECLARE
	m_service system.services%rowtype;
	m_service_invoice system.service_invoices%rowtype;
	m_account system.accounts%rowtype;
	m_tarif system.tarifs%rowtype;
	m_abon numeric(10,2);
	m_period_text text;
	m_notify record;
	m_end_time timestamp;
	m_start_time timestamp;
	m_invoice_start timestamp;
BEGIN
	SELECT * INTO m_service FROM system.services WHERE service_id = n_service_id AND current_tarif IS NOT NULL;
	IF NOT FOUND THEN
		RETURN;
	END IF;

	m_end_time = now();
	m_start_time = m_end_time;
	IF extract(day from m_end_time) != extract(day from (m_end_time - interval '1 min')) THEN
		-- Align to midnight
		m_start_time = date_trunc('day', m_end_time);
		m_end_time = m_start_time - interval '1 usec';
	END IF;

	SELECT * INTO m_account FROM system.accounts WHERE account_id = m_service.account_id;

	IF m_service.invoice_start IS NOT NULL THEN
		SELECT * INTO m_tarif FROM system.tarifs WHERE tarif_id = m_service.current_tarif;
		--
		IF m_tarif.calc_type_id = 1 THEN
			-- Type: Flat
			m_abon := m_tarif.abon * extract(epoch from (m_end_time - m_service.invoice_start)) / extract(epoch from ((m_service.invoice_start + interval '1 month') - m_service.invoice_start));
		ELSIF m_tarif.calc_type_id = 2 THEN
			-- Type: Day count (full or not)
			m_invoice_start = date_trunc('day', m_service.invoice_start);
			IF m_service.invoice_end > m_invoice_start THEN
				-- Don't count day twice if another period closed in that day
				m_invoice_start = m_invoice_start + interval '1 day';
			END IF;
			IF m_end_time > m_invoice_start THEN
				m_abon := m_tarif.abon * extract(day from ((m_end_time + interval '23:59:59') - m_invoice_start)) / extract(day from ((m_invoice_start + interval '1 month') - m_invoice_start));
			ELSE
				m_abon = 0;
			END IF;
		ELSE
			m_abon = 0;
		END IF;
		--
		m_period_text := to_char(m_service.invoice_start, 'DD.MM HH24:MI') || ' - ' || to_char(m_end_time, 'DD.MM HH24:MI');
		UPDATE system.account_logs
			SET amount = - m_abon, oper_time = m_end_time,
				descr = 'Абонентская плата по тарифу ' || m_tarif.tarif_name || ' [' || m_period_text || ']'
			WHERE log_id = m_service.invoice_log_id;

		FOR m_service_invoice IN SELECT * FROM system.service_invoices
			WHERE service_id = m_service.service_id AND invoice_log_id IS NOT NULL
		LOOP
			--
			IF m_tarif.calc_type_id = 1 THEN
				-- Type: Flat
				m_abon := m_service_invoice.invoice_abon * extract(epoch from (m_end_time - m_service_invoice.invoice_start)) / extract(epoch from ((m_service_invoice.invoice_start + interval '1 month') - m_service_invoice.invoice_start));
			ELSIF m_tarif.calc_type_id = 2 THEN
				-- Type: Day count (full or not)
				m_invoice_start = date_trunc('day', m_service_invoice.invoice_start);
				IF m_service_invoice.invoice_end > m_invoice_start THEN
					-- Don't count day twice if another period closed in that day
					m_invoice_start = m_invoice_start + interval '1 day';
				END IF;
				IF m_end_time > m_invoice_start THEN
					m_abon := m_service_invoice.invoice_abon * extract(day from ((m_end_time + interval '23:59:59') - m_invoice_start)) / extract(day from ((m_invoice_start + interval '1 month') - m_invoice_start));
				ELSE
					m_abon = 0;
				END IF;
			ELSE
				m_abon = 0;
			END IF;
			--
			m_period_text := to_char(m_service_invoice.invoice_start, 'DD.MM HH24:MI') || ' - ' || to_char(m_end_time, 'DD.MM HH24:MI');
			UPDATE system.account_logs
				SET amount = - m_abon, oper_time = m_end_time,
					descr = m_service_invoice.invoice_descr || ' [' || m_period_text || ']'
				WHERE log_id = m_service_invoice.invoice_log_id;
		END LOOP;

		-- Get updated balance
		SELECT * INTO m_account FROM system.accounts WHERE account_id = m_service.account_id;

		IF m_account.balance < 0 AND (m_account.promised_end_date < m_start_time OR m_account.promised_end_date IS NULL) THEN
			-- No money -- Close period
			UPDATE system.services SET service_state = 2, invoice_start = NULL, invoice_end = m_end_time, invoice_log_id = NULL WHERE service_id = n_service_id;
			-- Deactivate all tarif options
			UPDATE system.service_invoices SET invoice_active = 0, invoice_start = NULL, invoice_end = m_end_time, invoice_log_id = NULL WHERE service_id = n_service_id;
		END IF;

		IF m_service.service_state = 4 THEN
			-- Service suspended
			UPDATE system.services SET invoice_start = NULL, invoice_end = m_end_time, invoice_log_id = NULL WHERE service_id = n_service_id;
			-- Deactivate all tarif options
			UPDATE system.service_invoices SET invoice_active = 0, invoice_start = NULL, invoice_end = m_end_time, invoice_log_id = NULL WHERE service_id = n_service_id;
		END IF;

		IF extract(month from m_service.invoice_start) != extract(month from m_start_time) OR m_service.next_tarif IS NOT NULL THEN
			-- New month: create new log line (set invoice_start to null to force it)
			m_service.invoice_start := NULL;
		END IF;
	END IF;

	IF m_service.invoice_start IS NULL THEN
		-- Period closed, check if we can start new period
		IF m_service.service_state != 4 AND
			(m_account.balance >= 1 OR m_account.promised_end_date > m_start_time OR m_service.invoice_log_id IS NOT NULL)
		THEN
			IF m_service.next_tarif IS NOT NULL THEN
				SELECT * INTO m_tarif FROM system.tarifs WHERE tarif_id = m_service.next_tarif;
				-- Set invoice_end to NULL to count this half-day because of new tarif
				UPDATE system.services SET invoice_end = NULL WHERE service_id = m_service.service_id;
			ELSE
				SELECT * INTO m_tarif FROM system.tarifs WHERE tarif_id = m_service.current_tarif;
			END IF;

			-- Start new period
			m_service.invoice_start = m_start_time;
			INSERT INTO system.account_logs (user_id, account_id, oper_time, amount, descr)
				VALUES(m_account.user_id, m_account.account_id, m_service.invoice_start, 0, 'Абонентская плата по тарифу ' || m_tarif.tarif_name);
			UPDATE system.services SET invoice_start = m_service.invoice_start, invoice_log_id = lastval(),
				service_state = 1, inet_speed = m_tarif.inet_speed, current_tarif = m_tarif.tarif_id, next_tarif = NULL
				WHERE service_id = m_service.service_id;
			UPDATE system.service_invoices SET invoice_active = 1, invoice_start = m_service.invoice_start
				WHERE service_id = m_service.service_id;

			FOR m_service_invoice IN SELECT * FROM system.service_invoices
				WHERE service_id = m_service.service_id AND invoice_start IS NOT NULL AND invoice_log_id IS NULL AND invoice_abon > 0
			LOOP
				INSERT INTO system.account_logs (user_id, account_id, oper_time, amount, descr, cash_flow_type)
					VALUES(m_account.user_id, m_account.account_id, m_service.invoice_start, 0, m_service_invoice.invoice_descr, m_service_invoice.cash_flow_type);
				UPDATE system.service_invoices SET invoice_log_id = lastval() WHERE invoice_id = m_service_invoice.invoice_id;
			END LOOP;
		END IF;
	END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION services_after_update() RETURNS trigger AS $$
DECLARE
	m_session_id bigint;
	m_notify record;
BEGIN
	IF (NEW.service_state != OLD.service_state) OR (NEW.inet_speed != OLD.inet_speed) OR (NEW.current_tarif != OLD.current_tarif) THEN
		SELECT session_id INTO m_session_id FROM system.sessions WHERE service_id = NEW.service_id AND active = 1;
		IF FOUND THEN
			PERFORM pg_notify('radius_coa', m_session_id::text);
		END IF;
		-- Send invoice change notification
		SELECT service_id, service_type INTO m_notify FROM system.services WHERE service_id = NEW.service_id;
		PERFORM pg_notify('service_invoices_change', row_to_json(m_notify)::text);
	END IF;

	RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_update ON services;
CREATE TRIGGER after_update AFTER UPDATE ON services
	FOR EACH ROW EXECUTE PROCEDURE services_after_update();

CREATE OR REPLACE FUNCTION service_invoices_before_insert() RETURNS trigger AS $$
DECLARE
	m_service system.services%rowtype;
	m_option system.tarif_options%rowtype;
BEGIN
	SELECT * INTO m_service FROM system.services WHERE service_id = NEW.service_id;

	SELECT * INTO m_option FROM system.tarif_options WHERE option_id = NEW.option_id AND m_service.current_tarif = ANY(allowed_tarifs);
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Указанная тарифная опция не найдена или недопустима для данного тарифа';
	END IF;

	NEW.invoice_active = 0;
	NEW.invoice_start = NULL;
	NEW.invoice_end = NULL;
	NEW.invoice_log_id = NULL;
	NEW.invoice_descr = m_option.option_name;
	NEW.invoice_abon = m_option.default_abon;
	NEW.cash_flow_type = m_option.cash_flow_type;

	IF m_service.invoice_start IS NOT NULL THEN
		-- Activate option if parent service is active
		NEW.invoice_start = now();
		NEW.invoice_active = 1;
		IF NEW.invoice_abon > 0 THEN
			INSERT INTO system.account_logs (user_id, account_id, oper_time, amount, descr, cash_flow_type)
				VALUES(m_service.user_id, m_service.account_id, NEW.invoice_start, 0, NEW.invoice_descr, NEW.cash_flow_type);
			NEW.invoice_log_id = lastval();
		END IF;
	END IF;

	RETURN NEW;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS before_insert ON service_invoices;
CREATE TRIGGER before_insert BEFORE INSERT ON service_invoices
	FOR EACH ROW EXECUTE PROCEDURE service_invoices_before_insert();

CREATE OR REPLACE FUNCTION service_invoices_before_delete() RETURNS trigger AS $$
BEGIN
	IF OLD.invoice_log_id IS NOT NULL THEN
		PERFORM system.services_update_invoice(OLD.service_id);
	END IF;
	RETURN OLD;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS before_delete ON service_invoices;
CREATE TRIGGER before_delete BEFORE DELETE ON service_invoices
	FOR EACH ROW EXECUTE PROCEDURE service_invoices_before_delete();

CREATE OR REPLACE FUNCTION service_invoices_after_update() RETURNS trigger AS $$
DECLARE
	m_payload record;
BEGIN
	IF TG_OP = 'INSERT' THEN
		SELECT service_id, service_type INTO m_payload FROM system.services WHERE service_id = NEW.service_id;
		PERFORM pg_notify('service_invoices_change', row_to_json(m_payload)::text);
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		IF NEW.invoice_active != OLD.invoice_active THEN
			SELECT service_id, service_type INTO m_payload FROM system.services WHERE service_id = NEW.service_id;
			PERFORM pg_notify('service_invoices_change', row_to_json(m_payload)::text);
		END IF;
		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		SELECT service_id, service_type INTO m_payload FROM system.services WHERE service_id = OLD.service_id;
		PERFORM pg_notify('service_invoices_change', row_to_json(m_payload)::text);
		RETURN OLD;
	END IF;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_update ON service_invoices;
CREATE TRIGGER after_update AFTER INSERT OR UPDATE OR DELETE ON service_invoices
	FOR EACH ROW EXECUTE PROCEDURE service_invoices_after_update();

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
	ticket_status_name varchar(128) NOT NULL,
	final_status integer NOT NULL DEFAULT 0
);

INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(1, 'Новая') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(2, 'Проверка возможности подключения') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(3, 'В работе') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(4, 'Выполнена') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(5, 'Отказ оператора') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(6, 'Отказ абонента') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(7, 'Подготовка') ON CONFLICT DO NOTHING;
INSERT INTO ticket_statuses (ticket_status, ticket_status_name) VALUES(8, 'Ожидание') ON CONFLICT DO NOTHING;

-- system.ticket_types

CREATE TABLE IF NOT EXISTS ticket_types (
	ticket_type integer NOT NULL PRIMARY KEY,
	ticket_type_name varchar(128) NOT NULL
);

INSERT INTO ticket_types (ticket_type, ticket_type_name) VALUES(1, 'Подключение услуги') ON CONFLICT DO NOTHING;
INSERT INTO ticket_types (ticket_type, ticket_type_name) VALUES(2, 'Отключение услуги') ON CONFLICT DO NOTHING;
INSERT INTO ticket_types (ticket_type, ticket_type_name) VALUES(3, 'Ремонт') ON CONFLICT DO NOTHING;

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
	location public.geometry(Point, 4326),
	flat_number integer,
	last_comment text,
	create_oper_id integer REFERENCES operators(operator_id) ON DELETE SET NULL
);

-- system tikcet_comments

CREATE TABLE IF NOT EXISTS ticket_comments (
	comment_id serial PRIMARY KEY,
	ticket_id integer NOT NULL REFERENCES tickets ON DELETE CASCADE,
	oper_id integer REFERENCES operators(operator_id) ON DELETE SET NULL,
	time_created timestamptz NOT NULL DEFAULT now(),
	comment_text text NOT NULL
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

-- system.user_doc_types

CREATE TABLE IF NOT EXISTS user_doc_types (
	doc_type integer PRIMARY KEY,
	doc_type_name varchar(128) NOT NULL
);

INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(1, 'Паспорт гражданина СССР') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(2, 'Загранпаспорт гражданина СССР') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(3, 'Свидетельство о рождении') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(4, 'Удостоверение личности') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(5, 'Справка об освобождении') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(6, 'Паспорт Минморфлота') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(7, 'Военный билет') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(9, 'Дипломатический паспорт гражданина РФ') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(10, 'Иностранный паспорт') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(11, 'Свидетельство о регистрации ходатайства иммигранта о признании его беженцем') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(12, 'Вид на жительство') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(13, 'Удостоверение беженца') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(14, 'Временное удостоверение личности гражданина РФ') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(21, 'Паспорт гражданина РФ') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(22, 'Загранпаспорт гражданина РФ') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(23, 'Свидетельство о рождении, выданное уполномоченным органом иностранного государства') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(26, 'Паспорт моряка') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(27, 'Военный билет офицера запаса') ON CONFLICT DO NOTHING;
INSERT INTO user_doc_types (doc_type, doc_type_name) VALUES(91, 'Иные документы, выдаваемые органами МВД') ON CONFLICT DO NOTHING;

-- system.user_data

CREATE TABLE IF NOT EXISTS user_data (
	user_id integer PRIMARY KEY REFERENCES users,
	namef varchar(128) NOT NULL,
	namei varchar(128) NOT NULL,
	nameo varchar(128) NOT NULL,
	birthdate date NOT NULL,
	birthplace varchar(256),
	doc_type integer DEFAULT 21 REFERENCES user_doc_types,
	doc_number varchar(128),
	doc_date date,
	doc_auth varchar(256),
	doc_auth_code varchar(16),
	reg_address text,
	change_time timestamptz
);

-- system.user_devices

CREATE TABLE IF NOT EXISTS user_devices (
	device_id serial PRIMARY KEY,
	model_id integer NOT NULL REFERENCES device_models,
	serial_no varchar(32) NOT NULL,
	service_id integer REFERENCES services,
	oper_id integer REFERENCES operators
);

-- Functions

CREATE OR REPLACE FUNCTION acl_merge_privileges(vc_priv_list text[], vc_priv_grant text[], vc_priv_revoke text[]) RETURNS text[] AS $$
DECLARE
	m_result text[];
BEGIN
	SELECT array_agg(x) INTO m_result FROM (
		SELECT DISTINCT unnest(vc_priv_list || vc_priv_grant) AS x
	) s WHERE NOT x = ANY(vc_priv_revoke);
	RETURN coalesce(m_result, '{}'::text[]);
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION acl_get_privileges(n_group_id integer) RETURNS text[] AS $$
DECLARE
	m_acl_group system.acl_groups%rowtype;
	m_priv_list text[];
BEGIN
	m_priv_list := '{}'::text[];

	SELECT * INTO m_acl_group FROM system.acl_groups WHERE group_id = n_group_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Не найден указанный список доступа.';
	END IF;
	IF m_acl_group.parent_group_id IS NOT NULL THEN
		SELECT system.acl_get_privileges(m_acl_group.parent_group_id) INTO m_priv_list;
	END IF;

	SELECT system.acl_merge_privileges(m_priv_list, m_acl_group.priv_granted, m_acl_group.priv_revoked) INTO m_priv_list;

	RETURN m_priv_list;
END
$$ LANGUAGE plpgsql;

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

	IF m_ip IS NULL THEN
		RETURN ip_start;
	END IF;

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

CREATE OR REPLACE FUNCTION format_postaddr(vc_street_guid text, vc_house_number text, vc_flat_number text) RETURNS varchar AS $$
DECLARE
	m_address varchar;
	m_fias addr_fias%rowtype;
	m_guid varchar;
	i integer;
BEGIN
	IF vc_street_guid IS NULL THEN
		RETURN '';
	END IF;

	m_guid := vc_street_guid;
	m_address := '';
	FOR i IN 1..2 LOOP
		SELECT * INTO m_fias FROM addr_fias WHERE guid = m_guid;
		IF NOT FOUND THEN
			EXIT;
		END IF;
		m_address := m_fias.short_name || ' ' || m_fias.off_name || ', ' || m_address;
		m_guid := m_fias.parent_guid;
	END LOOP;

	m_address := m_address || 'д. ' || vc_house_number;
	IF vc_flat_number IS NOT NULL THEN
		m_address := m_address || ', кв. ' || vc_flat_number;
	END IF;

	RETURN m_address;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION services_get_addr(n_house_id integer, n_flat integer) RETURNS varchar AS $$
DECLARE
	m_house addr_houses%rowtype;
BEGIN
	IF n_house_id IS NULL THEN
		RETURN '';
	END IF;

	SELECT * INTO m_house FROM addr_houses WHERE house_id = n_house_id;

	RETURN system.format_postaddr(m_house.street_guid, m_house.house_number, n_flat::text);
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION services_get_tarifs(n_service_id integer, n_current_tarif integer) RETURNS jsonb AS $$
DECLARE
	m_tarif system.tarifs%rowtype;
	m_allowed_tarifs jsonb;
	m_allowed_options jsonb;
	m_result jsonb;
BEGIN
	SELECT * INTO m_tarif FROM system.tarifs WHERE tarif_id = n_current_tarif;
	IF NOT FOUND THEN
		RETURN NULL;
	END IF;

	m_result = '{}'::jsonb;

	SELECT coalesce(json_agg(tarifs.*), '{}') INTO m_allowed_tarifs FROM system.tarifs
		WHERE group_id = m_tarif.group_id AND group_id != 0 AND active > 0 AND tarif_id != n_current_tarif;
	m_result = jsonb_set(m_result, '{allowed_tarifs}', m_allowed_tarifs, true);

	SELECT coalesce(json_agg(tarif_options.*), '{}') INTO m_allowed_options FROM system.tarif_options
		WHERE m_tarif.tarif_id = ANY(allowed_tarifs) AND user_controlled = 1
		AND NOT (array[option_id] && array(SELECT option_id FROM system.service_invoices WHERE service_id = n_service_id));
	m_result = jsonb_set(m_result, '{allowed_options}', m_allowed_options, true);

	RETURN m_result;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION generate_password() RETURNS varchar AS $$
DECLARE
	m_pass varchar;
BEGIN
	SELECT string_agg(substr('0123456789', ceil (random() * 10)::integer, 1), '') INTO m_pass
	FROM generate_series(1, 6);
	RETURN m_pass;
END
$$ LANGUAGE plpgsql;

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

CREATE OR REPLACE FUNCTION cron_job() RETURNS void AS $$
DECLARE
	m_service_id integer;
BEGIN
	UPDATE sessions SET active = 0 WHERE active = 1 AND update_time < (now() - interval '1 hour');
	UPDATE accounts SET promised_end_date = NULL WHERE promised_end_date < now();

	FOR m_service_id IN SELECT service_id FROM services WHERE current_tarif IS NOT NULL
	LOOP
		PERFORM services_update_invoice(m_service_id);
	END LOOP;
END;
$$
LANGUAGE plpgsql;
