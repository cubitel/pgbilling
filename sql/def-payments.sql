--
-- payments
--

SET SCHEMA 'payments';

CREATE OR REPLACE FUNCTION payment_check(n_agent_id integer, vc_account_number varchar) RETURNS integer AS $$
DECLARE
    m_account_id integer;
BEGIN
    SELECT account_id INTO m_account_id FROM system.accounts WHERE account_number = vc_account_number;
    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    RETURN m_account_id;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION payment_pay(n_agent_id integer, vc_account_number varchar, n_amount numeric,
    vc_agent_ref varchar, vc_descr varchar) RETURNS integer AS $$
DECLARE
    m_account_id integer;
    m_user_id integer;
    m_payment_id integer;
    m_service_id integer;
BEGIN
    SELECT payments.payment_check(n_agent_id, vc_account_number) INTO m_account_id;
    IF m_account_id = 0 THEN
        RETURN 0;
    END IF;

    SELECT payment_id INTO m_payment_id FROM system.payments
        WHERE account_id = m_account_id AND agent_id = n_agent_id AND agent_ref = vc_agent_ref;
    IF FOUND THEN
        RETURN m_payment_id;
    END IF;

    SELECT user_id INTO m_user_id FROM system.accounts WHERE account_id = m_account_id;

	INSERT INTO system.account_logs
		(user_id, account_id, oper_time, amount, descr)
		VALUES(m_user_id, m_account_id, NOW(), n_amount, vc_descr);

	FOR m_service_id IN SELECT service_id FROM system.services WHERE account_id = m_account_id AND current_tarif IS NOT NULL
	LOOP
		PERFORM system.services_update_invoice(m_service_id);
	END LOOP;

    INSERT INTO system.payments
        (user_id, account_id, oper_time, amount, agent_id, agent_ref, descr)
        VALUES(m_user_id, m_account_id, NOW(), n_amount, n_agent_id, vc_agent_ref, vc_descr);

    RETURN lastval();
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION payment_set_check_data(n_payment_id integer, vc_check_data text) RETURNS integer AS $$
BEGIN
	UPDATE system.payments SET check_data = vc_check_data WHERE payment_id = n_payment_id;
    RETURN 1;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;



CREATE OR REPLACE FUNCTION payment_summary(n_date_from date, n_date_to date)
	RETURNS TABLE(day date, agent_id int, sum numeric) AS $$
DECLARE
	m_row record;
BEGIN
	FOR m_row IN SELECT oper_time::date, payments.agent_id, SUM(amount) AS sum
		FROM system.payments
		WHERE oper_time::date BETWEEN n_date_from AND n_date_to
		GROUP BY oper_time::date, payments.agent_id
		ORDER BY oper_time::date
	LOOP
		day = m_row.oper_time;
		agent_id = m_row.agent_id;
		sum = m_row.sum;
		RETURN NEXT;
	END LOOP;

	RETURN;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT USAGE ON SCHEMA payments TO payments;
