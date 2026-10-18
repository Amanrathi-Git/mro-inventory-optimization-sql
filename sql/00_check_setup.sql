-- 00_check_setup.sql
-- Confirms SQLite supports everything this project needs.

.headers on
.mode column

-- 1. SQLite version (need 3.35 or newer)
SELECT sqlite_version() AS sqlite_version;

-- 2. Recursive CTE: we will use this to generate 500 parts
WITH RECURSIVE n(i) AS (
    SELECT 1
    UNION ALL
    SELECT i + 1 FROM n WHERE i < 5
)
SELECT group_concat(i) AS numbers_1_to_5 FROM n;

-- 3. Window function: we will use this for ABC cumulative spend
WITH t(x) AS (VALUES (10), (20), (30))
SELECT x, SUM(x) OVER (ORDER BY x) AS running_total FROM t;

-- 4. Math function: we will use SQRT for EOQ and safety stock
-- Test: demand 1200/yr, ordering cost 50, unit cost 25, holding rate 20%
-- Expected result: about 154.92
SELECT SQRT(2 * 1200 * 50 / (0.20 * 25)) AS eoq_test;

-- 5. Random numbers: we will use these for synthetic consumption data
SELECT ABS(RANDOM() % 100) AS random_0_to_99;