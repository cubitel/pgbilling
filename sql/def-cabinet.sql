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

    CREATE TEMPORARY VIEW account_logs AS
        SELECT * FROM system.account_logs
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON account_logs TO cabinet;

    CREATE TEMPORARY VIEW services AS
        SELECT
            service_id,
            user_id,
            account_id,
            service_type,
            service_name,
            services.service_state,
            service_state_name,
            current_tarif,
            next_tarif,
            t1.tarif_name AS current_tarif_name,
            t2.tarif_name AS next_tarif_name,
            inet_speed,
            mac_address,
            array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list,
            services_get_addr(house_id, flat_number) AS postaddr
        FROM system.services
        LEFT JOIN system.service_state_names ON service_state_names.service_state = services.service_state
        LEFT JOIN system.tarifs AS t1 ON t1.tarif_id = services.current_tarif
        LEFT JOIN system.tarifs AS t2 ON t2.tarif_id = services.next_tarif
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON services TO cabinet;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION user_change_password(vc_pass varchar) RETURNS integer AS $$
DECLARE
    m_user_id integer;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

	UPDATE system.users SET pass = vc_pass WHERE user_id = m_user_id;
	INSERT INTO system.tasks (user_id, task_name, task_params) VALUES(m_user_id, 'userChangePassword', vc_pass);

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION account_promise_payment(n_account_id integer) RETURNS integer AS $$
DECLARE
	m_user_id integer;
BEGIN
	SELECT user_id INTO m_user_id FROM system.accounts
		WHERE user_id IN (SELECT user_id FROM sessions)
		AND account_id = n_account_id;
	IF NOT FOUND THEN
		RETURN 0;
	END IF;

	INSERT INTO system.tasks (task_name, user_id, account_id) VALUES('accountPromisePayment', m_user_id, n_account_id);

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT TO cabinet

GRANT USAGE ON SCHEMA cabinet TO cabinet;
GRANT SELECT ON ALL TABLES IN SCHEMA cabinet TO cabinet;
