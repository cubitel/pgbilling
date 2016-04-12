--
-- NETWORK
--

SET SCHEMA 'network';

-- GRANT to network

CREATE OR REPLACE FUNCTION rad_check(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_password varchar;
BEGIN
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
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rad_reply(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_service system.services%rowtype;
	m_attr system.radius_attrs%rowtype;
	m_ip inet;
BEGIN
	SELECT * INTO m_service FROM system.services WHERE service_name = vc_username;
	IF NOT FOUND THEN
		RETURN;
	END IF;

	FOR m_attr IN SELECT * FROM system.radius_attrs WHERE service_state = m_service.service_state
	LOOP
		value := m_attr.attr_value;
		SELECT replace(value, '{kbps}', m_service.inet_speed::varchar) INTO value;

		id := m_attr.attr_id;
		username := vc_username;
		attribute := m_attr.attr_name;
		op := ':=';
		RETURN NEXT;
	END LOOP;

	FOR m_ip IN SELECT ip_address FROM system.services_addr WHERE service_id = m_service.service_id
		AND family(ip_address) = 4
	LOOP
		id := 0;
		username := vc_username;
		attribute := 'Framed-IP-Address';
		op := ':=';
		value := m_ip;
		RETURN NEXT;
	END LOOP;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT USAGE ON SCHEMA network TO network;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA network TO network;
