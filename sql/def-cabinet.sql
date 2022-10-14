--
-- CABINET
--

SET SCHEMA 'cabinet';

-- Functions

CREATE OR REPLACE FUNCTION login(vc_login varchar, vc_pass varchar) RETURNS integer AS $$
DECLARE
    m_user_id integer;
    m_operator_id integer;
    m_logins text[];
BEGIN
	SELECT regexp_matches(vc_login, '^([a-zA-Z0-9]+)(/(.*))?$') INTO m_logins;
	IF m_logins[3] IS NULL THEN
		-- User authentication
	    SELECT users.user_id INTO m_user_id FROM system.users
	    	LEFT JOIN system.accounts ON accounts.user_id = users.user_id
	    	WHERE (login = lower(m_logins[1]) OR account_number = m_logins[1]) AND pass = vc_pass
	    	LIMIT 1;
	    IF NOT FOUND THEN
	        RETURN 0;
	    END IF;
	ELSE
		-- Operator authentication
	    SELECT operator_id INTO m_operator_id FROM system.operators WHERE login = m_logins[1] AND pass = md5(vc_pass);
	    IF NOT FOUND THEN
	        RETURN 0;
	    END IF;
	    SELECT users.user_id INTO m_user_id FROM system.users
	    	LEFT JOIN system.accounts ON accounts.user_id = users.user_id
	    	WHERE (login = lower(m_logins[3]) OR account_number = m_logins[3])
	    	LIMIT 1;
	    IF NOT FOUND THEN
	        RETURN 0;
	    END IF;
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

    CREATE TEMPORARY VIEW tarifs AS
        SELECT * FROM system.tarifs
        WHERE active = 1;

    GRANT SELECT ON tarifs TO cabinet;

    CREATE TEMPORARY VIEW services AS
        SELECT
            service_id,
            user_id,
            account_id,
            services.service_type,
            service_type_name,
            service_name,
            services.service_state,
            service_state_name,
            current_tarif,
            next_tarif,
            t1.tarif_name AS current_tarif_name,
            t2.tarif_name AS next_tarif_name,
            t1.abon AS current_tarif_abon,
            services.inet_speed,
            mac_address,
            array(SELECT ip_address FROM system.services_addr WHERE services_addr.service_id = services.service_id) AS ip_list,
            services_get_addr(house_id, flat_number) AS postaddr,
            serial_no,
            (SELECT json_agg(service_invoices.*) FROM system.service_invoices WHERE service_invoices.service_id = services.service_id) AS invoices
        FROM system.services
        LEFT JOIN system.service_types ON service_types.service_type = services.service_type
        LEFT JOIN system.service_state_names ON service_state_names.service_state = services.service_state
        LEFT JOIN system.tarifs AS t1 ON t1.tarif_id = services.current_tarif
        LEFT JOIN system.tarifs AS t2 ON t2.tarif_id = services.next_tarif
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON services TO cabinet;

	CREATE TEMPORARY VIEW services_tarifs AS
		SELECT
			service_id,
			system.services_get_tarifs(service_id, current_tarif) AS options
		FROM system.services
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON services_tarifs TO cabinet;

    CREATE TEMPORARY VIEW user_contacts AS
        SELECT * FROM system.user_contacts
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON user_contacts TO cabinet;

    CREATE TEMPORARY VIEW user_info AS
        SELECT login, user_name FROM system.users
        WHERE user_id IN (SELECT user_id FROM sessions);

    GRANT SELECT ON user_info TO cabinet;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION user_change_password(vc_pass varchar) RETURNS integer AS $$
DECLARE
    m_user_id integer;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

	UPDATE system.users SET pass = vc_pass WHERE user_id = m_user_id;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION user_change_login(vc_login varchar) RETURNS integer AS $$
DECLARE
    m_user_id integer;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

	IF vc_login SIMILAR TO '[0-9]+' THEN
		RAISE EXCEPTION 'Логин не может состоять только из цифр';
	END IF;
	IF vc_login NOT SIMILAR TO '[a-zA-Z0-9]+' THEN
		RAISE EXCEPTION 'В логине содержатся недопустимые символы';
	END IF;

	UPDATE system.users SET login = lower(vc_login) WHERE user_id = m_user_id;

    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION account_promise_payment(n_account_id integer) RETURNS integer AS $$
DECLARE
	m_account system.accounts%rowtype;
	m_service_id integer;
BEGIN
	SELECT * INTO m_account FROM system.accounts
		WHERE user_id IN (SELECT user_id FROM sessions)
		AND account_id = n_account_id;
	IF NOT FOUND THEN
		RETURN 0;
	END IF;

	IF m_account.promised_end_date > (now() + interval '8 hour') THEN
		RAISE EXCEPTION 'Предыдущий обещанный платёж еще действует более 8 часов';
	END IF;

	IF m_account.promised_count > 7 THEN
		RAISE EXCEPTION 'Превышено максимальное количество неоплаченных обещанных платежей.';
	END IF;

	UPDATE system.accounts SET promised_end_date = now() + interval '1 day', promised_count = promised_count + 1
		WHERE account_id = n_account_id;

	FOR m_service_id IN SELECT service_id FROM system.services WHERE account_id = n_account_id AND current_tarif IS NOT NULL
	LOOP
		PERFORM system.services_update_invoice(m_service_id);
	END LOOP;

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION service_change_tarif(params jsonb) RETURNS integer AS $$
DECLARE
	m_user_id integer;
	m_group_id integer;
	m_tarif_id integer;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вход не выполнен';
    END IF;

	SELECT group_id INTO m_group_id
		FROM system.services
		LEFT JOIN system.tarifs ON tarifs.tarif_id = services.current_tarif
		WHERE user_id = m_user_id AND service_id = (params->>'service_id')::int AND group_id != 0;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Доступ запрещен';
    END IF;

	SELECT tarif_id INTO m_tarif_id FROM system.tarifs
		WHERE tarif_id = (params->>'tarif_id')::int AND active = 1 AND group_id = m_group_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Указанный тариф недопустим';
    END IF;

	UPDATE system.services SET next_tarif = m_tarif_id WHERE service_id = (params->>'service_id')::int;
	PERFORM system.services_update_invoice((params->>'service_id')::int);

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION service_add_option(params jsonb) RETURNS integer AS $$
DECLARE
	m_user_id integer;
	m_service system.services%rowtype;
	m_option system.tarif_options%rowtype;
	m_invoice_id integer;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вход не выполнен';
    END IF;

	SELECT * INTO m_service FROM system.services
		WHERE service_id = (params->>'service_id')::int AND user_id = m_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Доступ запрещен';
    END IF;

	SELECT * INTO m_option FROM system.tarif_options
		WHERE option_id = (params->>'option_id')::int AND m_service.current_tarif = ANY(allowed_tarifs) AND user_controlled = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Указанная тарифная опция недопустима';
    END IF;

	SELECT invoice_id INTO m_invoice_id FROM system.service_invoices
		WHERE service_id = m_service.service_id AND option_id = m_option.option_id;
	IF FOUND THEN
        RAISE EXCEPTION 'Указанная тарифная опция уже подключена';
	END IF;

	INSERT INTO system.service_invoices (service_id, option_id) VALUES(m_service.service_id, m_option.option_id);

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION service_delete_option(params jsonb) RETURNS integer AS $$
DECLARE
	m_user_id integer;
	m_service system.services%rowtype;
	m_option system.tarif_options%rowtype;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вход не выполнен';
    END IF;

	SELECT * INTO m_service FROM system.services
		WHERE service_id = (params->>'service_id')::int AND user_id = m_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Доступ запрещен';
    END IF;

	SELECT * INTO m_option FROM system.tarif_options
		WHERE option_id = (params->>'option_id')::int AND user_controlled = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Удаление указанной тарифной опции пользователем невозможно.';
    END IF;

	DELETE FROM system.service_invoices WHERE service_id = m_service.service_id AND option_id = m_option.option_id;

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION create_smotreshka(params jsonb) RETURNS integer AS $$
DECLARE
	m_user_id integer;
	m_service_name text;
	m_tarif_id integer;
	m_account_id integer;
	m_service_id integer;
	m_notify record;
BEGIN
	SELECT user_id INTO m_user_id FROM sessions;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Вход не выполнен';
    END IF;

	m_service_name = lower(params->>'service_name');
	IF m_service_name NOT SIMILAR TO '[a-z0-9._]+@[a-z0-9.-]+.[a-z]+' THEN
		RAISE EXCEPTION 'Неверный e-mail адрес';
	END IF;

	SELECT tarif_id INTO m_tarif_id FROM system.tarifs
		WHERE tarif_id = (params->>'tarif_id')::int AND active = 1 AND service_type = 2;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Указанный тариф не найден или недопустим';
	END IF;

	SELECT account_id INTO m_account_id FROM system.accounts
		WHERE account_id = (params->>'account_id')::int AND user_id = m_user_id;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'Доступ запрещен';
	END IF;

	SELECT service_id INTO m_service_id FROM system.services WHERE service_name = m_service_name AND service_type = 2;
	IF FOUND THEN
		RAISE EXCEPTION 'Сервис с таким e-mail уже существует';
	END IF;

	SELECT service_id INTO m_service_id FROM system.services WHERE account_id = m_account_id AND service_type = 2;
	IF FOUND THEN
		RAISE EXCEPTION 'Возможно подключение только одного аккаунта';
	END IF;

	INSERT INTO system.services
		(service_type, user_id, account_id, service_name, service_pass, current_tarif, service_state)
		VALUES(2, m_user_id, m_account_id, m_service_name, system.generate_password(), m_tarif_id, 2);
	m_service_id = lastval();

	PERFORM system.services_update_invoice(m_service_id);

	-- Send invoice change notification
	SELECT service_id, service_type INTO m_notify FROM system.services WHERE service_id = m_service_id;
	PERFORM pg_notify('service_invoices_change', row_to_json(m_notify)::text);

	RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT TO cabinet

GRANT USAGE ON SCHEMA cabinet TO cabinet;
GRANT SELECT ON ALL TABLES IN SCHEMA cabinet TO cabinet;
