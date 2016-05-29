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

    CREATE TEMPORARY VIEW services AS
        SELECT services.*,
            array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list,
            services_get_addr(house_id, flat_number) AS postaddr
        FROM system.services
        LEFT JOIN system.service_state_names ON service_state_names.service_state = services.service_state
        LEFT JOIN system.tarifs AS t1 ON t1.tarif_id = services.current_tarif
        LEFT JOIN system.tarifs AS t2 ON t2.tarif_id = services.next_tarif;

    GRANT SELECT ON services TO admin;

	CREATE TEMPORARY VIEW tickets AS
		SELECT tickets.*,
			ticket_type_name,
			ticket_status_name,
			addr_fias.off_name AS street_name
		FROM system.tickets
		LEFT JOIN system.ticket_types ON ticket_types.ticket_type = tickets.ticket_type
		LEFT JOIN system.ticket_statuses ON ticket_statuses.ticket_status = tickets.ticket_status
		LEFT JOIN system.addr_fias ON addr_fias.guid = tickets.street_guid
		WHERE time_completed IS NULL;

	GRANT SELECT ON tickets TO admin;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT TO cabinet

GRANT USAGE ON SCHEMA admin TO admin;
GRANT SELECT ON ALL TABLES IN SCHEMA admin TO admin;
