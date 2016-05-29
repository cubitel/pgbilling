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

	UPDATE system.accounts SET balance = balance + n_amount WHERE account_id = m_account_id;

    INSERT INTO system.payments
        (user_id, account_id, oper_time, amount, agent_id, agent_ref, descr)
        VALUES(m_user_id, m_account_id, NOW(), n_amount, n_agent_id, vc_agent_ref, vc_descr);

    RETURN lastval();
END
$$ LANGUAGE plpgsql SECURITY DEFINER;


GRANT USAGE ON SCHEMA payments TO payments;
