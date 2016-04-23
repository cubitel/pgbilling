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

CREATE OR REPLACE FUNCTION create_connect_ticket(n_house_id integer, vc_street_guid varchar, vc_house_number varchar, vc_phone varchar) RETURNS integer AS $$
DECLARE
	m_ticket_id integer;
BEGIN
	SELECT ticket_id INTO m_ticket_id FROM system.tickets
		WHERE ticket_type = 1 AND service_type = 1 AND street_guid = vc_street_guid AND house_number = vc_house_number;

	IF FOUND THEN
		RETURN m_ticket_id;
	END IF;

	INSERT INTO system.tickets (ticket_type, service_type, house_id, street_guid, house_number, phone)
		VALUES(1, 1, n_house_id, vc_street_guid, vc_house_number, vc_phone);
	SELECT lastval() INTO m_ticket_id;

	RETURN m_ticket_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT

GRANT USAGE ON SCHEMA site TO site;
GRANT SELECT ON ALL TABLES IN SCHEMA site TO site;
