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
	vc_street_guid varchar, vc_house_number varchar, vc_phone varchar, n_flat_number integer) RETURNS integer AS $$
DECLARE
	m_ticket_id integer;
	m_location varchar;
BEGIN
	SELECT ticket_id INTO m_ticket_id FROM system.tickets
		WHERE ticket_type = 1 AND service_type = 1 AND time_completed IS NULL
		AND street_guid = vc_street_guid AND house_number = vc_house_number AND flat_number IS NOT DISTINCT FROM n_flat_number;

	IF FOUND THEN
		RETURN m_ticket_id;
	END IF;
	
	INSERT INTO system.tickets (ticket_type, service_type, house_id, street_guid, house_number, flat_number, phone)
		VALUES(1, 1, n_house_id, vc_street_guid, vc_house_number, n_flat_number, vc_phone);
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
	IF m_service.current_tarif IS NULL AND m_service.user_id != 1 THEN
		-- A TEST SUBSCRIBER
		name := 'service_id';
		value := m_service_id::varchar;
		RETURN NEXT;
		name := 'test';
		value := '1';
		RETURN NEXT;
	END IF;
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

CREATE OR REPLACE FUNCTION reg_set_serial(n_service_id integer, vc_serial_no varchar, n_user_port integer) RETURNS integer AS $$
BEGIN
	UPDATE system.services SET serial_no = vc_serial_no, user_port = n_user_port WHERE service_id = n_service_id AND service_state = 3;
	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reg_register_service(in_ip_address inet, n_ticket_id integer, n_tarif_id integer,
	vc_namef varchar, vc_namei varchar, vc_nameo varchar, d_birthdate date)
RETURNS TABLE(name varchar, value varchar) AS $$
DECLARE
	m_service_id integer;
	m_service system.services%rowtype;
	m_ticket system.tickets%rowtype;
	m_tarif system.tarifs%rowtype;
	m_house_id integer;
	m_user_id integer;
	m_account_id integer;
	m_account_number varchar;
	m_fio varchar;
	m_password varchar;
BEGIN
	SELECT service_id INTO m_service_id FROM system.services_addr WHERE ip_address = in_ip_address;
	IF NOT FOUND THEN
		RETURN;
	END IF;
	
	SELECT * INTO m_service FROM system.services WHERE service_id = m_service_id;
	IF m_service.service_state != 3 THEN
		RAISE 'Сервис не находится в состоянии "Новый"';
		RETURN;
	END IF;
	
	SELECT * INTO m_ticket FROM system.tickets WHERE ticket_id = n_ticket_id AND ticket_type = 1 AND time_completed IS NULL;
	IF NOT FOUND THEN
		RAISE 'Заявка % не найдена или закрыта', n_ticket_id;
		RETURN;
	END IF;
	
	SELECT * INTO m_tarif FROM system.tarifs WHERE tarif_id = n_tarif_id;
	IF NOT FOUND THEN
		RAISE 'Тариф % не найден', n_tarif_id;
		RETURN;
	END IF;
	
	SELECT house_id INTO m_house_id FROM system.addr_houses WHERE street_guid = m_ticket.street_guid AND house_number = m_ticket.house_number;
	IF NOT FOUND THEN
		INSERT INTO system.addr_houses (street_guid, house_number) VALUES(m_ticket.street_guid, m_ticket.house_number);
		SELECT lastval() INTO m_house_id;
	END IF;

	SELECT system.account_get_next() INTO m_account_number;

	m_fio := vc_namei || ' ' || vc_namef;
	SELECT system.generate_password() INTO m_password;
	INSERT INTO system.users (user_name, login_type, login, pass) VALUES(m_fio, 1, m_account_number, m_password);
	SELECT lastval() INTO m_user_id;
	
	INSERT INTO system.user_data (user_id, namef, namei, nameo, birthdate) VALUES(m_user_id, vc_namef, vc_namei, vc_nameo, d_birthdate);

	INSERT INTO system.user_contacts (user_id, contact_type, contact_value) VALUES(m_user_id, 1, m_ticket.phone);

	INSERT INTO system.accounts (user_id, account_number, balance, time_created, promised_end_date) VALUES(m_user_id, m_account_number, 0, now(), now() + interval '3 days');
	SELECT lastval() INTO m_account_id;

	UPDATE system.services SET user_id = m_user_id, account_id = m_account_id, service_name = m_account_number || '-1',
		house_id = m_house_id, flat_number = m_ticket.flat_number,
		service_state = 1, inet_speed = m_tarif.inet_speed, current_tarif = n_tarif_id
		WHERE service_id = m_service_id;
	
	INSERT INTO system.account_logs (user_id, account_id, oper_time, amount, descr)
		VALUES(m_user_id, m_account_id, now(), 0 - m_tarif.connect_price, 'Плата за подключение');
	
	PERFORM services_update_invoice(m_service_id);
	
	UPDATE system.tickets SET ticket_status = 4, time_completed = now() where ticket_id = m_ticket.ticket_id;
	
	IF m_service.serial_no IS NOT NULL THEN
		DELETE FROM system.user_devices WHERE serial_no = m_service.serial_no;
	END IF;
	
	PERFORM pg_notify('services_new', m_service_id::text);
	PERFORM pg_notify('sms', '7' || m_ticket.phone || ',Пароль в ЛК: ' || m_password);
	
	name := 'service_id';
	value := m_service_id::varchar;
	RETURN NEXT;
	name := 'account_number';
	value := m_account_number;
	RETURN NEXT;
	name := 'password';
	value := m_password;
	RETURN NEXT;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION reg_register_test_service(in_ip_address inet, n_tarif_id integer)
RETURNS TABLE(name varchar, value varchar) AS $$
DECLARE
	m_service_id integer;
	m_service system.services%rowtype;
	m_tarif system.tarifs%rowtype;
	m_account_number varchar;
	m_password varchar;
BEGIN
	SELECT service_id INTO m_service_id FROM system.services_addr WHERE ip_address = in_ip_address;
	IF NOT FOUND THEN
		RETURN;
	END IF;
	
	SELECT * INTO m_service FROM system.services WHERE service_id = m_service_id;
	IF m_service.current_tarif IS NOT NULL THEN
		RAISE 'Сервис уже активирован';
		RETURN;
	END IF;

	SELECT * INTO m_tarif FROM system.tarifs WHERE tarif_id = n_tarif_id;
	IF NOT FOUND THEN
		RAISE 'Тариф % не найден', n_tarif_id;
		RETURN;
	END IF;
	
	SELECT system.account_get_next() INTO m_account_number;
	SELECT system.generate_password() INTO m_password;
	
	UPDATE system.accounts SET account_number = m_account_number, time_created = now(), promised_end_date = now() + interval '3 days'
		WHERE account_id = m_service.account_id;
	
	UPDATE system.users SET login = m_account_number, pass = m_password WHERE user_id = m_service.user_id;
	
	UPDATE system.services SET service_name = m_account_number || '-1',
		service_state = 1, inet_speed = m_tarif.inet_speed, current_tarif = n_tarif_id
		WHERE service_id = m_service_id;
	
	INSERT INTO system.account_logs (user_id, account_id, oper_time, amount, descr)
		VALUES(m_service.user_id, m_service.account_id, now(), -7000, 'Плата за подключение');
	
	PERFORM services_update_invoice(m_service_id);
	
	name := 'service_id';
	value := m_service_id::varchar;
	RETURN NEXT;
	name := 'account_number';
	value := m_account_number;
	RETURN NEXT;
	name := 'password';
	value := m_password;
	RETURN NEXT;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT

GRANT USAGE ON SCHEMA site TO site;
GRANT SELECT ON ALL TABLES IN SCHEMA site TO site;
