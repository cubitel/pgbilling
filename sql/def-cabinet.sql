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
