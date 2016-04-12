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
    CHECK(service_type != 1 OR service_state != 1 OR (inet_speed IS NOT NULL AND inet_speed > 0))
);

CREATE UNIQUE INDEX IF NOT EXISTS services_mac ON services (mac_address);
CREATE UNIQUE INDEX IF NOT EXISTS services_name ON services(service_name, service_type);

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
    system_id integer NOT NULL,
    user_id integer REFERENCES users ON DELETE CASCADE,
    account_id integer REFERENCES accounts ON DELETE CASCADE,
    service_id integer REFERENCES services ON DELETE CASCADE,
    tarif_id integer REFERENCES tarifs ON DELETE CASCADE,
    task_name varchar(128) NOT NULL,
    task_status integer NOT NULL REFERENCES task_status_names DEFAULT 1,
    time_created timestamp NOT NULL DEFAULT now(),
    time_completed timestamp NOT NULL
);

COMMENT ON TABLE tasks IS 'Задачи для внешних систем';

CREATE OR REPLACE RULE insert_notify AS
    ON INSERT TO tasks
    DO ALSO NOTIFY tasks_insert;