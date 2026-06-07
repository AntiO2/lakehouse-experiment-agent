-- ============================================================
-- Validation queries for HyBench on TiDB
-- Replace ${TIDB_DATABASE} before execution or run:
--   mysql --database ${TIDB_DATABASE} < sql/hybench/validate_tidb.sql
-- ============================================================

-- 1. Row count per table
SELECT 'customer' AS tbl, COUNT(*) AS rows FROM customer
UNION ALL SELECT 'company', COUNT(*) FROM company
UNION ALL SELECT 'savingaccount', COUNT(*) FROM savingaccount
UNION ALL SELECT 'checkingaccount', COUNT(*) FROM checkingaccount
UNION ALL SELECT 'transfer', COUNT(*) FROM transfer
UNION ALL SELECT 'checking', COUNT(*) FROM checking
UNION ALL SELECT 'loanapps', COUNT(*) FROM loanapps
UNION ALL SELECT 'loantrans', COUNT(*) FROM loantrans;

-- 2. Distinct primary key count
SELECT 'customer' AS tbl, COUNT(DISTINCT custid) AS distinct_pk FROM customer
UNION ALL SELECT 'company', COUNT(DISTINCT companyid) FROM company
UNION ALL SELECT 'savingaccount', COUNT(DISTINCT accountid) FROM savingaccount
UNION ALL SELECT 'checkingaccount', COUNT(DISTINCT accountid) FROM checkingaccount
UNION ALL SELECT 'transfer', COUNT(DISTINCT id) FROM transfer
UNION ALL SELECT 'checking', COUNT(DISTINCT id) FROM checking
UNION ALL SELECT 'loanapps', COUNT(DISTINCT id) FROM loanapps
UNION ALL SELECT 'loantrans', COUNT(DISTINCT id) FROM loantrans;

-- 3. Freshness check
SELECT tbl, MIN(freshness_ts) AS min_ts, MAX(freshness_ts) AS max_ts FROM (
    SELECT 'customer' AS tbl, freshness_ts FROM customer
    UNION ALL SELECT 'company', freshness_ts FROM company
    UNION ALL SELECT 'savingaccount', freshness_ts FROM savingaccount
    UNION ALL SELECT 'checkingaccount', freshness_ts FROM checkingaccount
    UNION ALL SELECT 'transfer', freshness_ts FROM transfer
    UNION ALL SELECT 'checking', freshness_ts FROM checking
    UNION ALL SELECT 'loanapps', freshness_ts FROM loanapps
    UNION ALL SELECT 'loantrans', freshness_ts FROM loantrans
) t GROUP BY tbl;

