--
-- ADMIN
--

SET SCHEMA 'admin';

-- Functions

CREATE OR REPLACE FUNCTION login(vc_login varchar, vc_pass varchar) RETURNS integer AS $$
DECLARE
    m_oper_id integer;
BEGIN
    SELECT operator_id INTO m_oper_id FROM system.operators WHERE login = vc_login AND pass = md5(vc_pass);
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    CREATE TEMPORARY TABLE sessions (
        oper_id integer NOT NULL
    );
    INSERT INTO sessions (oper_id) VALUES(m_oper_id);


    CREATE TEMPORARY VIEW accounts AS
        SELECT * FROM system.accounts;

    GRANT SELECT ON accounts TO admin;


    CREATE TEMPORARY VIEW account_logs AS
        SELECT * FROM system.account_logs;

    GRANT SELECT ON account_logs TO admin;

	CREATE TEMPORARY VIEW payments AS
		SELECT payments.*, accounts.account_number
		FROM system.payments
		LEFT JOIN system.accounts ON accounts.account_id = payments.account_id;
	
	GRANT SELECT ON payments TO admin;


    CREATE TEMPORARY VIEW services AS
        SELECT services.*,
        	service_state_name,
        	t1.tarif_name,
        	user_name,
            array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list,
            services_get_addr(house_id, flat_number) AS postaddr,
            accounts.balance
        FROM system.services
        LEFT JOIN system.service_state_names ON service_state_names.service_state = services.service_state
        LEFT JOIN system.tarifs AS t1 ON t1.tarif_id = services.current_tarif
        LEFT JOIN system.users ON users.user_id = services.user_id
        LEFT JOIN system.accounts ON accounts.account_id = services.account_id;

    GRANT SELECT ON services TO admin;


	CREATE TEMPORARY VIEW radius_sessions AS
		SELECT sessions.*, services.service_name, devices.device_ip, device_ports.port_name
		FROM system.sessions
		LEFT JOIN system.services ON services.service_id = sessions.service_id
		LEFT JOIN system.device_ports ON device_ports.port_id = services.port_id
		LEFT JOIN system.devices ON devices.device_id = device_ports.device_id
		WHERE active = 1;

	GRANT SELECT ON radius_sessions TO admin;


	CREATE TEMPORARY VIEW tickets AS
		SELECT tickets.*,
			ticket_type_name,
			ticket_status_name,
			addr_fias.off_name || ' ' || addr_fias.short_name AS street_name,
			(select round(ST_DistanceSphere(addr_houses.location, tickets.location)) AS dist from addr_houses order by dist limit 1)
		FROM system.tickets
		LEFT JOIN system.ticket_types ON ticket_types.ticket_type = tickets.ticket_type
		LEFT JOIN system.ticket_statuses ON ticket_statuses.ticket_status = tickets.ticket_status
		LEFT JOIN system.addr_fias ON addr_fias.guid = tickets.street_guid
		WHERE time_completed IS NULL;

	GRANT SELECT ON tickets TO admin;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION change_password(vc_pass varchar) RETURNS integer AS $$
DECLARE
    m_oper_id integer;
BEGIN
	SELECT oper_id INTO m_oper_id FROM sessions;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

	UPDATE system.operators SET pass = md5(vc_pass) WHERE operator_id = m_oper_id;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- GRANT TO cabinet

GRANT USAGE ON SCHEMA admin TO admin;
GRANT SELECT ON ALL TABLES IN SCHEMA admin TO admin;
