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


	CREATE TEMPORARY VIEW report_payments AS
		SELECT date(oper_time) AS dt, agent_id, sum(amount) AS cost
		FROM system.payments
		GROUP BY dt, agent_id;

	GRANT SELECT ON report_payments TO admin;

	CREATE TEMPORARY VIEW report_invoices AS
		SELECT date(date_trunc('month', oper_time - interval '1 hour')) as dt, sum(-amount) as cost
		FROM account_logs
		WHERE amount < 0
		GROUP BY dt;

	GRANT SELECT ON report_invoices TO admin;

    CREATE TEMPORARY VIEW services AS
        SELECT services.*,
        	service_state_name,
        	t1.tarif_name,
        	user_name,
            array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list,
            array(SELECT contact_value FROM system.user_contacts WHERE user_contacts.user_id = services.user_id) AS contacts,
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
			(select round(ST_DistanceSphere(addr_houses.location, tickets.location)) AS dist from addr_houses order by dist limit 1),
			ST_AsGeoJson(tickets.location) AS geopoint
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


CREATE OR REPLACE FUNCTION user_add(vc_params text) RETURNS integer AS $$
DECLARE
    m_oper_id integer;
    m_params jsonb;
	m_user_id integer;
	m_account_id integer;
	m_service_id integer;
	m_user_login text;
	m_user_password text;
	m_inet_speed integer;
	m_device_ip text;
	m_device_port text;
	m_device_id integer;
	m_port_id integer;
BEGIN
	SELECT oper_id INTO m_oper_id FROM sessions;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

	m_params = vc_params::jsonb;
	m_user_login = m_params->>'user_login';
	m_user_password = m_params->>'user_password';
	m_inet_speed = (m_params->>'inet_speed')::integer * 1000;

    INSERT INTO system.users (user_name, login_type, login, pass) VALUES(m_user_login, 1, m_user_login, m_user_password);
    SELECT lastval() INTO m_user_id;

    INSERT INTO system.accounts (user_id, account_number, balance) VALUES(m_user_id, system.account_get_next(), 0);
    SELECT lastval() INTO m_account_id;

	INSERT INTO system.services
		(user_id, account_id, service_type, service_name, service_state, inet_speed)
		VALUES(m_user_id, m_account_id, 1, m_user_login, 1, m_inet_speed);
    SELECT lastval() INTO m_service_id;

	m_device_ip = m_params->>'device_ip';
	m_device_port = m_params->>'device_port';
	IF m_device_ip != '' AND m_device_port != '' THEN
		SELECT device_id INTO m_device_id FROM system.devices WHERE device_ip = m_device_ip::inet;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'Коммутатор не найден';
		END IF;

		SELECT port_id INTO m_port_id FROM system.device_ports WHERE device_id = m_device_id AND port_name = m_device_port;
		IF NOT FOUND THEN
			INSERT INTO system.device_ports (device_id, port_name, snmp_index) VALUES(m_device_id, m_device_port, 0);
		    SELECT lastval() INTO m_port_id;
		END IF;

		UPDATE system.services SET port_id = m_port_id WHERE service_id = m_service_id;
	END IF;

    RETURN m_user_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION user_delete(vc_params text) RETURNS integer AS $$
DECLARE
    m_oper_id integer;
    m_params jsonb;
	m_user_id integer;
	m_user_login text;
BEGIN
	SELECT oper_id INTO m_oper_id FROM sessions;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

	m_params = vc_params::jsonb;
	m_user_login = m_params->>'user_login';

	SELECT user_id INTO m_user_id FROM system.users WHERE login = m_user_login;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Пользователь не найден.';
		RETURN 0;
	END IF;

	DELETE FROM system.services WHERE user_id = m_user_id;
	DELETE FROM system.accounts WHERE user_id = m_user_id;
	DELETE FROM system.users WHERE user_id = m_user_id;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION user_get_summary(n_user_id integer) RETURNS jsonb AS $$
DECLARE
    m_oper_id integer;
    m_user record;
    m_summary jsonb;
    m_row record;
    m_list jsonb[];
BEGIN
	SELECT oper_id INTO m_oper_id FROM sessions;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

	SELECT user_id, user_name, login INTO m_user FROM system.users WHERE user_id = n_user_id;

	m_summary = row_to_json(m_user);

	m_list = '{}'::jsonb[];
	FOR m_row IN SELECT accounts.*
		FROM system.accounts
		WHERE user_id = n_user_id
	LOOP
		m_list = m_list || row_to_json(m_row)::jsonb;
	END LOOP;
	m_summary = jsonb_set(m_summary, '{accounts}', array_to_json(m_list)::jsonb, true);

	m_list = '{}'::jsonb[];
	FOR m_row IN SELECT services.*,
		system.services_get_addr(services.house_id, flat_number) AS postaddr,
		service_state_name, t1.tarif_name,
		port_name, device_ip, device_mac
		FROM system.services
		LEFT JOIN system.device_ports ON device_ports.port_id = services.port_id
		LEFT JOIN system.devices ON devices.device_id = device_ports.device_id
		LEFT JOIN system.service_state_names ON service_state_names.service_state = services.service_state
		LEFT JOIN system.tarifs AS t1 ON t1.tarif_id = services.current_tarif
		WHERE user_id = n_user_id
	LOOP
		m_list = m_list || row_to_json(m_row)::jsonb;
	END LOOP;
	m_summary = jsonb_set(m_summary, '{services}', array_to_json(m_list)::jsonb, true);

    RETURN m_summary;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- GRANT TO cabinet

GRANT USAGE ON SCHEMA admin TO admin;
GRANT SELECT ON ALL TABLES IN SCHEMA admin TO admin;
