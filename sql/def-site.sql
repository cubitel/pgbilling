--
-- BILLING
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

-- GRANT

GRANT USAGE ON SCHEMA site TO site;
GRANT SELECT ON ALL TABLES IN SCHEMA site TO site;
