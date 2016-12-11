--
-- BILLING
--

SET SCHEMA 'billing';

-- billing.services

CREATE OR REPLACE VIEW services AS
    SELECT
        services.service_id,
        services.service_type,
        services.service_name,
        accounts.time_created,
        services.service_state,
        services.current_tarif AS tarif,
        tarifs.connect_price,
        tarifs.abon,
        tarifs.tarif_name,
        services.inet_speed,
        addr_houses.street_guid,
        addr_houses.house_number,
        services.flat_number,
        system.services_get_addr(services.house_id, flat_number) AS postaddr,
        services.serial_no,
        array(SELECT contact_value FROM system.user_contacts WHERE user_contacts.user_id = services.user_id) AS contacts,
        user_data.namef,
        user_data.namei,
        user_data.nameo,
        user_data.birthdate,
        user_data.birthplace,
        user_data.doc_type,
        user_data.doc_number,
        user_data.doc_date,
        user_data.doc_auth,
        user_data.doc_auth_code
    FROM system.services
    LEFT JOIN system.accounts ON accounts.account_id = services.account_id
    LEFT JOIN system.tarifs ON tarifs.tarif_id = services.current_tarif
    LEFT JOIN system.addr_houses ON addr_houses.house_id = services.house_id
    LEFT JOIN system.user_data ON user_data.user_id = services.user_id
    WHERE services.current_tarif IS NOT NULL;

COMMENT ON COLUMN services.service_id IS 'Идентификатор услуги';
COMMENT ON COLUMN services.service_type IS 'Тип услуги';
COMMENT ON COLUMN services.service_name IS 'Имя услуги';
COMMENT ON COLUMN services.time_created IS 'Время создания аккаунта';
COMMENT ON COLUMN services.service_state IS 'Состояние услуги';
COMMENT ON COLUMN services.tarif IS 'Идентификатор тарифа';
COMMENT ON COLUMN services.connect_price IS 'Стоимость подключения';
COMMENT ON COLUMN services.abon IS 'Абонентская плата';
COMMENT ON COLUMN services.tarif_name IS 'Название тарифа';
COMMENT ON COLUMN services.inet_speed IS 'Скорость доступа в интернет';
COMMENT ON COLUMN services.street_guid IS 'Идентификатор улицы по ФИАС';
COMMENT ON COLUMN services.house_number IS 'Номер дома';
COMMENT ON COLUMN services.flat_number IS 'Номер квартиры';
COMMENT ON COLUMN services.postaddr IS 'Адрес в текстовом виде';
COMMENT ON COLUMN services.serial_no IS 'Серийный номер ONU';
COMMENT ON COLUMN services.contacts IS 'Контактная информация';
COMMENT ON COLUMN services.namef IS 'Фамилия';
COMMENT ON COLUMN services.namei IS 'Имя';
COMMENT ON COLUMN services.nameo IS 'Отчество';
COMMENT ON COLUMN services.birthdate IS 'Дата рождения';
COMMENT ON COLUMN services.birthplace IS 'Место рождения';
COMMENT ON COLUMN services.doc_type IS 'Тип документа';
COMMENT ON COLUMN services.doc_number IS 'Номер документа';
COMMENT ON COLUMN services.doc_date IS 'Дата документа';
COMMENT ON COLUMN services.doc_auth IS 'Орган, выдавший документ';
COMMENT ON COLUMN services.doc_auth_code IS 'Код органа, выдавшего документ';

-- GRANT to billing

GRANT USAGE ON SCHEMA billing TO billing;
GRANT SELECT ON ALL TABLES IN SCHEMA billing TO billing;
