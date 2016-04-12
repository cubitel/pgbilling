BEGIN TRANSACTION;

\i def-system.sql
\i def-billing.sql
\i def-cabinet.sql
\i def-network.sql
\i def-payments.sql

COMMIT;
