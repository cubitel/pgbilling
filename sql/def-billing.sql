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

-- billing.addr_fias

CREATE OR REPLACE VIEW addr_fias AS
    SELECT * FROM system.addr_fias;

-- billing.addr_houses

CREATE OR REPLACE VIEW addr_houses AS
    SELECT * FROM system.addr_houses;

-- billing.addr_connected

CREATE OR REPLACE VIEW addr_connected AS
    SELECT * FROM system.addr_connected;

-- billing.payments

CREATE OR REPLACE VIEW payments AS
    SELECT
        payments.*,
        payagents.agent_name,
        accounts.account_number
    FROM system.payments
    LEFT JOIN system.payagents ON payagents.agent_id = payments.agent_id
    LEFT JOIN system.accounts ON accounts.account_id = payments.account_id;

-- billing.service_state_names

CREATE OR REPLACE VIEW service_state_names AS
    SELECT * FROM system.service_state_names;

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
        array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list,
        house_id,
        flat_number,
        service_pass,
        serial_no
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

-- billing.task_status_names

CREATE OR REPLACE VIEW task_status_names AS
    SELECT * FROM system.task_status_names;

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
    SELECT user_id, user_name, login, pass FROM system.users;

COMMENT ON VIEW users IS 'Абоненты';
COMMENT ON COLUMN users.user_id IS 'Идентификатор абонента';
COMMENT ON COLUMN users.user_name IS 'Читабельное имя пользователя';
COMMENT ON COLUMN users.login IS 'Логин абонента в ЛК';

CREATE OR REPLACE RULE rule_users_delete AS
    ON DELETE TO users
    DO INSTEAD NOTHING;

CREATE OR REPLACE FUNCTION users_change_password(n_user_id integer, vc_pass varchar) RETURNS void AS $$
BEGIN
    UPDATE system.users SET pass = vc_pass WHERE user_id = n_user_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- billing.user_contact_types

CREATE OR REPLACE VIEW user_contact_types AS
    SELECT * FROM system.user_contact_types;

-- billing.user_contacts

CREATE OR REPLACE VIEW user_contacts AS
    SELECT * FROM system.user_contacts;


-- GRANT to billing

GRANT USAGE ON SCHEMA billing TO billing;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA billing TO billing;
