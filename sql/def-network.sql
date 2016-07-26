--
-- NETWORK
--

SET SCHEMA 'network';

-- network.addr_houses

CREATE OR REPLACE VIEW addr_houses AS
    SELECT *, system.services_get_addr(house_id, 0) AS postaddr FROM system.addr_houses;

-- Functions

CREATE OR REPLACE FUNCTION rad_check(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_password varchar;
	m_circuitid varchar;
	m_remoteid varchar;
BEGIN
	SELECT convert_from(decode(vc_remoteid, 'hex'), 'utf-8') INTO m_remoteid;
	SELECT convert_from(decode(vc_circuitid, 'hex'), 'utf-8') INTO m_circuitid;

	SELECT service_pass INTO m_password FROM system.services WHERE service_name = vc_username;
	IF NOT FOUND THEN
		SELECT  service_pass INTO m_password FROM system.services
			LEFT JOIN system.device_ports ON services.port_id = device_ports.port_id
			LEFT JOIN system.devices ON devices.device_id = device_ports.device_id
			WHERE devices.device_ip = m_remoteid::inet AND device_ports.port_name = m_circuitid;
		IF NOT FOUND THEN
			RETURN;
		END IF;

	    id := 1;
	    username := vc_username;
	    attribute := 'Auth-Type';
	    value := 'Accept';
	    op := ':=';
	    RETURN NEXT;
	    RETURN;
	END IF;

    id := 1;
    username := vc_username;
    attribute := 'Cleartext-Password';
    value := m_password;
    op := ':=';
    RETURN NEXT;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rad_reply(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_service system.services%rowtype;
	m_attr system.radius_attrs%rowtype;
	m_circuitid varchar;
	m_remoteid varchar;
	m_ip inet;
BEGIN
	SELECT convert_from(decode(vc_remoteid, 'hex'), 'utf-8') INTO m_remoteid;
	SELECT convert_from(decode(vc_circuitid, 'hex'), 'utf-8') INTO m_circuitid;

	SELECT * INTO m_service FROM system.services WHERE service_name = vc_username;
	IF NOT FOUND THEN
		SELECT  * INTO m_service FROM system.services
			LEFT JOIN system.device_ports ON services.port_id = device_ports.port_id
			LEFT JOIN system.devices ON devices.device_id = device_ports.device_id
			WHERE devices.device_ip = m_remoteid::inet AND device_ports.port_name = m_circuitid;
		IF NOT FOUND THEN
			RETURN;
		END IF;
	END IF;

	FOR m_attr IN SELECT * FROM system.radius_attrs WHERE service_state = m_service.service_state
	LOOP
		value := m_attr.attr_value;
		SELECT replace(value, '{kbps}', m_service.inet_speed::varchar) INTO value;
		SELECT replace(value, '{Bps}', (m_service.inet_speed * 125)::varchar) INTO value;

		id := m_attr.attr_id;
		username := vc_username;
		attribute := m_attr.attr_name;
		op := ':=';
		RETURN NEXT;
	END LOOP;

	id := 0;
	op := ':=';
	username := vc_username;
	attribute := 'Service-Type';
	value := 'Framed-User';
--	RETURN NEXT;

	attribute := 'Class';
	value := m_service.service_id::varchar || '-' || m_service.service_state::varchar || '-' || m_service.inet_speed::varchar;
	RETURN NEXT;

	FOR m_ip IN SELECT ip_address FROM system.services_addr WHERE service_id = m_service.service_id
		AND family(ip_address) = 4
	LOOP
		attribute := 'Framed-IP-Address';
		value := m_ip;
		RETURN NEXT;
	END LOOP;
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
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA network TO network;
