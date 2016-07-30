--
-- SITE
--

SET SCHEMA 'site';

-- site.addr_fias

CREATE OR REPLACE VIEW addr_fias AS
    SELECT * FROM system.addr_fias;

-- site.addr_fias_houses

CREATE OR REPLACE VIEW addr_fias_houses AS
    SELECT * FROM system.addr_fias_houses;

-- site.addr_houses

CREATE OR REPLACE VIEW addr_houses AS
    SELECT * FROM system.addr_houses;

-- Functions

CREATE OR REPLACE FUNCTION create_connect_ticket(n_house_id integer, vc_location varchar,
	vc_street_guid varchar, vc_house_number varchar, vc_phone varchar) RETURNS integer AS $$
DECLARE
	m_ticket_id integer;
	m_location varchar;
BEGIN
	SELECT ticket_id INTO m_ticket_id FROM system.tickets
		WHERE ticket_type = 1 AND service_type = 1 AND street_guid = vc_street_guid AND house_number = vc_house_number;

	IF FOUND THEN
		RETURN m_ticket_id;
	END IF;
	
	INSERT INTO system.tickets (ticket_type, service_type, house_id, street_guid, house_number, phone)
		VALUES(1, 1, n_house_id, vc_street_guid, vc_house_number, vc_phone);
	SELECT lastval() INTO m_ticket_id;

	IF vc_location IS NOT NULL THEN
		m_location = 'SRID=4326;POINT(' || vc_location || ')';
		UPDATE system.tickets SET location = m_location::geometry WHERE ticket_id = m_ticket_id;
	END IF;


	RETURN m_ticket_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reg_get_info(in_ip_address inet) RETURNS TABLE(name varchar, value varchar) AS $$
DECLARE
	m_service_id integer;
	m_service system.services%rowtype;
	m_port system.device_ports%rowtype;
	m_device system.devices%rowtype;
BEGIN
	SELECT service_id INTO m_service_id FROM system.services_addr WHERE ip_address = in_ip_address;
	IF NOT FOUND THEN
		RETURN;
	END IF;
	
	SELECT * INTO m_service FROM system.services WHERE service_id = m_service_id;
	IF m_service.service_state != 3 THEN
		RETURN;
	END IF;
	
	SELECT * INTO m_port FROM system.device_ports WHERE port_id = m_service.port_id;
	SELECT * INTO m_device FROM system.devices WHERE device_id = m_port.device_id;
	
	name := 'service_id';
	value := m_service_id::varchar;
	RETURN NEXT;
	name := 'device';
	value := m_device.device_ip::varchar;
	RETURN NEXT;
	name := 'port';
	value := m_port.port_name;
	RETURN NEXT;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT

GRANT USAGE ON SCHEMA site TO site;
GRANT SELECT ON ALL TABLES IN SCHEMA site TO site;
