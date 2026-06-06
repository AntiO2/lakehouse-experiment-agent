-- ============================================================
-- Validation queries for HyBench
-- Run via: Trino --server localhost:8080 --catalog iceberg --schema hybench_sf100
-- ============================================================

-- 1. Row count per table
SELECT 'customer' AS tbl, COUNT(*) AS rows FROM customer
UNION ALL
SELECT 'company', COUNT(*) FROM company
UNION ALL
SELECT 'savingaccount', COUNT(*) FROM savingaccount
UNION ALL
SELECT 'checkingaccount', COUNT(*) FROM checkingaccount
UNION ALL
SELECT 'transfer', COUNT(*) FROM transfer
UNION ALL
SELECT 'checking', COUNT(*) FROM checking
UNION ALL
SELECT 'loanapps', COUNT(*) FROM loanapps
UNION ALL
SELECT 'loantrans', COUNT(*) FROM loantrans;

-- 2. PK uniqueness (sample: customer)
SELECT custid, COUNT(*) AS cnt FROM customer
GROUP BY custid HAVING COUNT(*) > 1 LIMIT 5;

-- 3. Freshness check
SELECT tbl, MIN(freshness_ts) AS min_ts, MAX(freshness_ts) AS max_ts FROM (
    SELECT 'customer' AS tbl, freshness_ts FROM customer
    UNION ALL SELECT 'company', freshness_ts FROM company
) t GROUP BY tbl;
