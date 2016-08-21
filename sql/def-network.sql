--
-- NETWORK
--

SET SCHEMA 'network';

-- network.addr_houses

CREATE OR REPLACE VIEW addr_houses AS
    SELECT *, system.services_get_addr(house_id, NULL) AS postaddr FROM system.addr_houses;

-- network.services

CREATE OR REPLACE VIEW services AS
	SELECT *, system.services_get_addr(house_id, flat_number) AS postaddr FROM system.services;

-- network.sessions

CREATE OR REPLACE VIEW sessions AS
	SELECT * FROM system.sessions;

-- network.users

CREATE OR REPLACE VIEW users AS
	SELECT * FROM system.users;

-- network.user_data

CREATE OR REPLACE VIEW user_data AS
	SELECT * FROM system.user_data;

-- Functions

CREATE OR REPLACE FUNCTION rad_check(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_password varchar;
	m_circuitid varchar;
	m_remoteid varchar;
BEGIN
	IF vc_remoteid = '' THEN
		-- login/password scheme
		SELECT service_pass INTO m_password FROM system.services WHERE service_name = vc_username;
		IF NOT FOUND THEN
			RETURN;
		END IF;

	    id := 1;
	    username := vc_username;
	    attribute := 'Cleartext-Password';
	    value := m_password;
	    op := ':=';
	    RETURN NEXT;
	ELSE
		-- option82 scheme
		SELECT convert_from(decode(vc_remoteid, 'hex'), 'utf-8') INTO m_remoteid;
		SELECT convert_from(decode(vc_circuitid, 'hex'), 'utf-8') INTO m_circuitid;

		SELECT device_id::varchar INTO m_password FROM system.devices WHERE device_ip = m_remoteid::inet;
		IF NOT FOUND THEN
			RETURN;
		END IF;

	    id := 1;
	    username := vc_username;
	    attribute := 'Auth-Type';
	    value := 'Accept';
	    op := ':=';
	    RETURN NEXT;
	END IF;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rad_attrs(n_service_id integer)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_service system.services%rowtype;
	m_attr system.radius_attrs%rowtype;
	m_ip inet;
BEGIN
	SELECT * INTO m_service FROM system.services WHERE service_id = n_service_id;
	IF NOT FOUND THEN
		RETURN;
	END IF;

	id := 0;
	op := ':=';
	username := '';

	FOR m_attr IN SELECT * FROM system.radius_attrs WHERE service_state = m_service.service_state
	LOOP
		attribute := m_attr.attr_name;
		value := m_attr.attr_value;
		SELECT replace(value, '{kbps}', m_service.inet_speed::varchar) INTO value;
		SELECT replace(value, '{Bps}', (m_service.inet_speed * 125)::varchar) INTO value;
		RETURN NEXT;
	END LOOP;

	attribute := 'Class';
	value := m_service.service_id::varchar || '-' || m_service.service_state::varchar || '-' || m_service.inet_speed::varchar;
	RETURN NEXT;

	SELECT ip_address INTO m_ip FROM system.services_addr WHERE service_id = m_service.service_id AND family(ip_address) = 4;
	IF FOUND THEN
		attribute := 'Framed-IP-Address';
		value := m_ip;
		RETURN NEXT;
	END IF;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rad_reply(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_service system.services%rowtype;
	m_attr system.radius_attrs%rowtype;
	m_device system.devices%rowtype;
	m_network system.networks%rowtype;
	m_circuitid varchar;
	m_remoteid varchar;
	m_ip inet;
	m_port_id integer;
BEGIN
	IF vc_remoteid = '' THEN
		-- login/password scheme
		SELECT * INTO m_service FROM system.services WHERE service_name = vc_username;
		IF NOT FOUND THEN
			RETURN;
		END IF;
	ELSE
		-- Option82 scheme
		SELECT convert_from(decode(vc_remoteid, 'hex'), 'utf-8') INTO m_remoteid;
		SELECT convert_from(decode(vc_circuitid, 'hex'), 'utf-8') INTO m_circuitid;

		-- Find network device
		SELECT * INTO m_device FROM system.devices WHERE device_ip = m_remoteid::inet;
		IF NOT FOUND THEN
			RETURN;
		END IF;

		-- Find device port
		SELECT * INTO m_service FROM system.services
			LEFT JOIN system.device_ports ON services.port_id = device_ports.port_id
			WHERE device_ports.device_id = m_device.device_id AND device_ports.port_name = m_circuitid;
		IF NOT FOUND THEN
			-- Create port if not exist
			SELECT port_id INTO m_port_id FROM system.device_ports WHERE device_id = m_device.device_id AND port_name = m_circuitid;
			IF NOT FOUND THEN
				INSERT INTO system.device_ports (device_id, port_name, snmp_index) VALUES(m_device.device_id, m_circuitid, 0);
				SELECT lastval() INTO m_port_id;
			END IF;
			-- Create default service if not exist
			INSERT INTO system.services (user_id, account_id, service_type, service_name, service_state, port_id, inet_speed)
				VALUES(1, 1, 1, m_remoteid || ' / ' || m_circuitid, 3, m_port_id, 0);
			SELECT * INTO m_service FROM system.services WHERE port_id = m_port_id;
			IF NOT FOUND THEN
				RETURN;
			END IF;
		END IF;

		-- Get networks attached to device
		SELECT * INTO m_network FROM system.networks WHERE network_id = m_device.network_id;
	END IF;

	id := 0;
	op := ':=';
	username := vc_username;

	FOR m_attr IN SELECT * FROM system.radius_attrs WHERE service_state = m_service.service_state AND in_coa = 0
	LOOP
		attribute := m_attr.attr_name;
		value := m_attr.attr_value;
		SELECT replace(value, '{kbps}', m_service.inet_speed::varchar) INTO value;
		SELECT replace(value, '{Bps}', (m_service.inet_speed * 125)::varchar) INTO value;
		RETURN NEXT;
	END LOOP;

	attribute := 'Class';
	value := m_service.service_id::varchar || '-' || m_service.service_state::varchar || '-' || m_service.inet_speed::varchar;
	RETURN NEXT;

	SELECT ip_address INTO m_ip FROM system.services_addr WHERE service_id = m_service.service_id AND family(ip_address) = 4;
	IF FOUND THEN
		attribute := 'Framed-IP-Address';
		value := m_ip;
		RETURN NEXT;
	ELSE
		IF m_network IS NOT NULL THEN
			SELECT system.get_free_ip(m_network.addr_start, m_network.addr_stop) INTO m_ip;
			INSERT INTO system.services_addr (service_id, ip_address) VALUES(m_service.service_id, m_ip);
			attribute := 'Framed-IP-Address';
			value := m_ip;
			RETURN NEXT;
		END IF;
	END IF;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rad_acct(vc_type varchar, vc_nas varchar, vc_session_id varchar, vc_class varchar, vc_username varchar) RETURNS integer AS $$
DECLARE
	m_session_id bigint;
	m_class varchar;
	m_class_array varchar[];
	m_service_id integer;
BEGIN
	SELECT convert_from(decode(vc_class, 'hex'), 'utf-8') INTO m_class;

	m_service_id = NULL;
	SELECT regexp_split_to_array(m_class, E'-') INTO m_class_array;
	IF m_class_array[1] != '' THEN
		m_service_id = m_class_array[1]::integer;
	END IF;

	IF vc_type = 'Start' THEN
		INSERT INTO sessions (acct_session_id, nas_ip_address, class, service_id, username) VALUES(vc_session_id, vc_nas::inet, m_class, m_service_id, vc_username);
	END IF;

	IF vc_type = 'Interim-Update' THEN
		SELECT session_id INTO m_session_id FROM sessions WHERE acct_session_id = vc_session_id AND active = 1;
		IF FOUND THEN
			UPDATE sessions SET update_time = now(), class = m_class WHERE session_id = m_session_id;
		ELSE
			INSERT INTO sessions (acct_session_id, nas_ip_address, class, service_id, username) VALUES(vc_session_id, vc_nas::inet, m_class, m_service_id, vc_username);
		END IF;
	END IF;

	IF vc_type = 'Stop' THEN
		UPDATE sessions SET active = 0, update_time = now() WHERE acct_session_id = vc_session_id AND active = 1;
	END IF;

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT to network

GRANT USAGE ON SCHEMA network TO network;
GRANT SELECT ON ALL TABLES IN SCHEMA network TO network;
