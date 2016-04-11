BEGIN TRANSACTION;

DO $$
DECLARE
    user_id integer;
    account_id integer;
    service_id integer;
BEGIN
    INSERT INTO users (user_name, login_type, login, pass) VALUES('Иванов С. С.', 1, 'siva', '123');
    SELECT lastval() INTO user_id;

    INSERT INTO accounts (user_id, account_number, balance) VALUES(user_id, '1001', 10);
    SELECT lastval() INTO account_id;

    INSERT INTO services (user_id, account_id, service_type, service_name, service_pass, inet_speed) VALUES(user_id, account_id, 1, 'TEST-01', '123', 10000);
    SELECT lastval() INTO service_id;

    INSERT INTO services_addr (service_id, ip_address) VALUES(service_id, '1.2.3.4');
    INSERT INTO services_addr (service_id, ip_address) VALUES(service_id, '2a00:d48::/32');

    INSERT INTO services (user_id, account_id, service_type, service_name, service_state) VALUES(user_id, account_id, 1, 'TEST-02', 2);

    INSERT INTO radius_attrs (service_state, attr_name, attr_value) VALUES(1, 'Dynamic-Qos-Param', 'police-circuit-rate rate-absolute {kbps}');
    INSERT INTO radius_attrs (service_state, attr_name, attr_value) VALUES(1, 'Dynamic-Qos-Param', 'meter-circuit-rate rate-absolute {kbps}');
END;
$$;

SELECT * FROM billing.services;

COMMIT;
