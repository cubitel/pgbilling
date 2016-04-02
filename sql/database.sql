BEGIN TRANSACTION;

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

-- system.services

CREATE TABLE IF NOT EXISTS services (
    service_id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users,
    account_id integer NOT NULL REFERENCES accounts,
    service_type integer NOT NULL,
    service_name varchar(128) NOT NULL,
    service_pass varchar(128),
    service_state integer NOT NULL DEFAULT 1,
    current_tarif integer REFERENCES tarifs(tarif_id),
    next_tarif integer REFERENCES tarifs(tarif_id),
    inet_speed integer,
    mac_address macaddr
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

-- system.tasks

CREATE TABLE IF NOT EXISTS tasks (
    task_id serial PRIMARY KEY,
    system_id integer NOT NULL,
    user_id integer REFERENCES users ON DELETE CASCADE,
    account_id integer REFERENCES accounts ON DELETE CASCADE,
    service_id integer REFERENCES services ON DELETE CASCADE,
    tarif_id integer REFERENCES tarifs ON DELETE CASCADE,
    task_name varchar(128) NOT NULL,
    task_status integer NOT NULL,
    time_created timestamp NOT NULL DEFAULT now(),
    time_completed timestamp NOT NULL
);

COMMENT ON TABLE tasks IS 'Задачи для внешних систем';

CREATE OR REPLACE RULE insert_notify AS
    ON INSERT TO tasks
    DO ALSO NOTIFY tasks_insert;


--
-- BILLING
--

SET SCHEMA 'billing';

-- billing.accounts

CREATE OR REPLACE VIEW accounts AS
    SELECT * FROM system.accounts;

-- billing.account_logs

CREATE OR REPLACE VIEW account_logs AS
    SELECT * FROM system.account_logs;

-- billing.payments

CREATE OR REPLACE VIEW payments AS
    SELECT
        payments.*,
        payagents.agent_name,
        accounts.account_number
    FROM system.payments
    LEFT JOIN system.payagents ON payagents.agent_id = payments.agent_id
    LEFT JOIN system.accounts ON accounts.account_id = payments.account_id;

-- billing.services

CREATE OR REPLACE VIEW services AS
    SELECT
        service_id,
        user_id,
        account_id,
        service_type,
        service_name,
        service_state,
        current_tarif,
        next_tarif,
        inet_speed,
        mac_address,
        array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list
    FROM system.services;

CREATE OR REPLACE FUNCTION services_add_ip(n_service_id integer, n_address inet) RETURNS void AS $$
BEGIN
    INSERT INTO system.services_addr (service_id, ip_address) VALUES(n_service_id, n_address);
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION services_change_password(n_service_id integer, vc_pass varchar) RETURNS void AS $$
BEGIN
    UPDATE system.services SET service_pass = vc_pass WHERE service_id = n_service_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION services_remove_ip(n_service_id integer, n_address inet) RETURNS void AS $$
BEGIN
    DELETE FROM system.services_addr WHERE service_id = n_service_id AND ip_address = n_address;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- billing.tarifs

CREATE OR REPLACE VIEW tarifs AS
    SELECT * FROM system.tarifs;

-- billing.tasks

CREATE OR REPLACE VIEW tasks AS
    SELECT * FROM system.tasks WHERE system_id = 1;

CREATE OR REPLACE RULE tasks_insert AS
    ON INSERT TO tasks
    DO INSTEAD NOTHING;

CREATE OR REPLACE RULE tasks_update AS
    ON UPDATE TO tasks
    DO INSTEAD UPDATE system.tasks SET task_status = NEW.task_status WHERE task_id = OLD.task_id;

CREATE OR REPLACE RULE tasks_delete AS
    ON DELETE TO tasks
    DO INSTEAD NOTHING;

-- billing.users

CREATE OR REPLACE VIEW users AS
    SELECT user_id, user_name, login FROM system.users;

COMMENT ON VIEW users IS 'Абоненты';
COMMENT ON COLUMN users.user_id IS 'Идентификатор абонента';
COMMENT ON COLUMN users.user_name IS 'Читабельное имя пользователя';
COMMENT ON COLUMN users.login IS 'Логин абонента в ЛК';

CREATE OR REPLACE FUNCTION users_modify() RETURNS trigger AS $$
    return;
$$ LANGUAGE plperl;

DROP TRIGGER IF EXISTS trigger_users_modify ON users;
CREATE TRIGGER trigger_users_modify
    INSTEAD OF INSERT OR UPDATE ON users
    FOR EACH ROW
    EXECUTE PROCEDURE users_modify();

CREATE OR REPLACE RULE rule_users_delete AS
    ON DELETE TO users
    DO INSTEAD NOTHING;

-- GRANT to billing

GRANT USAGE ON SCHEMA billing TO billing;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA billing TO billing;


--
-- CABINET
--

SET SCHEMA 'cabinet';

-- Functions

CREATE OR REPLACE FUNCTION login(vc_login varchar, vc_pass varchar) RETURNS integer AS $$
DECLARE
    m_user_id integer;
BEGIN
    SELECT user_id INTO m_user_id FROM system.users WHERE login = vc_login AND pass = vc_pass;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    CREATE TEMPORARY TABLE sessions (
        user_id integer NOT NULL
    );
    INSERT INTO sessions (user_id) VALUES(m_user_id);

    CREATE TEMPORARY VIEW accounts AS
        SELECT * FROM system.accounts
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON accounts TO cabinet;

    CREATE TEMPORARY VIEW services AS
        SELECT
            service_id,
            user_id,
            account_id,
            service_type,
            service_name,
            service_state,
            current_tarif,
            next_tarif,
            inet_speed,
            mac_address,
            array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list
        FROM system.services
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON services TO cabinet;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT TO cabinet

GRANT USAGE ON SCHEMA cabinet TO cabinet;
GRANT SELECT ON ALL TABLES IN SCHEMA cabinet TO cabinet;


--
-- NETWORK
--

SET SCHEMA 'network';

-- GRANT to network

CREATE OR REPLACE FUNCTION rad_check(vc_username varchar, vc_mac macaddr, n_port integer)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
BEGIN
    id := 1;
    username := vc_username;
    attribute := 'Cleartext-Password';
    value := '123';
    op := ':=';
    RETURN NEXT;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT USAGE ON SCHEMA network TO network;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA network TO network;


--
-- payments
--

SET SCHEMA 'payments';

CREATE OR REPLACE FUNCTION payment_check(n_agent_id integer, vc_account_number varchar) RETURNS integer AS $$
DECLARE
    m_account_id integer;
BEGIN
    SELECT account_id INTO m_account_id FROM system.accounts WHERE account_number = vc_account_number;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    RETURN m_account_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION payment_pay(n_agent_id integer, vc_account_number varchar, n_amount numeric,
    vc_agent_ref varchar, vc_descr varchar) RETURNS integer AS $$
DECLARE
    m_account_id integer;
    m_user_id integer;
    m_payment_id integer;
BEGIN
    SELECT payments.payment_check(n_agent_id, vc_account_number) INTO m_account_id;
    IF m_account_id = 0 THEN
        RETURN 0;
    END IF;

    SELECT payment_id INTO m_payment_id FROM system.payments
        WHERE account_id = m_account_id AND agent_id = n_agent_id AND agent_ref = vc_agent_ref;
    IF FOUND THEN
        RETURN m_payment_id;
    END IF;

    SELECT user_id INTO m_user_id FROM system.accounts WHERE account_id = m_account_id;

    INSERT INTO system.payments
        (user_id, account_id, oper_time, amount, agent_id, agent_ref, descr)
        VALUES(m_user_id, m_account_id, NOW(), n_amount, n_agent_id, vc_agent_ref, vc_descr);

    RETURN lastval();
END
$$ LANGUAGE plpgsql SECURITY DEFINER;


GRANT USAGE ON SCHEMA payments TO payments;


COMMIT;
