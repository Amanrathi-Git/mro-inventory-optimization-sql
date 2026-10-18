-- 02_parts_master.sql
-- Generates 500 synthetic spare parts. Safe to re-run.

DELETE FROM parts_master;

WITH RECURSIVE seq(i) AS (            -- counter: 1, 2, 3 ... 500
    SELECT 1
    UNION ALL
    SELECT i + 1 FROM seq WHERE i < 500
),
draws AS MATERIALIZED (               -- one fixed set of random numbers per part
    -- (RANDOM() & 2147483647) / 2147483648.0 gives a random decimal in [0, 1)
    SELECT i,
        (RANDOM() & 2147483647) / 2147483648.0 AS r1,
        (RANDOM() & 2147483647) / 2147483648.0 AS r2,
        (RANDOM() & 2147483647) / 2147483648.0 AS r3,
        (RANDOM() & 2147483647) / 2147483648.0 AS r4,
        (RANDOM() & 2147483647) / 2147483648.0 AS r5,
        (RANDOM() & 2147483647) / 2147483648.0 AS r6
    FROM seq
)
INSERT INTO parts_master
SELECT
    'MRO-' || printf('%04d', i)                                  AS part_id,
    CASE i % 10
        WHEN 0 THEN 'Bearing'       WHEN 1 THEN 'Hydraulic Seal'
        WHEN 2 THEN 'Filter'        WHEN 3 THEN 'Valve'
        WHEN 4 THEN 'Gasket'        WHEN 5 THEN 'Sensor'
        WHEN 6 THEN 'Relay'         WHEN 7 THEN 'Drive Belt'
        WHEN 8 THEN 'Fastener Kit'  ELSE 'Pump Coupling'
    END || ' Type-' || printf('%03d', i)                         AS part_name,
    -- r1*r2*r3 multiplies three random numbers, so most results are small
    -- and a few are large: a skewed cost curve ($5 to roughly $2,000)
    ROUND(5 + 2000 * r1 * r2 * r3, 2)                            AS unit_cost,
    7 + CAST(r4 * 38 AS INTEGER)                                 AS lead_time_days,   -- 7 to 44 days
    -- lead time std dev = 10% to 30% of the lead time itself
    ROUND((7 + CAST(r4 * 38 AS INTEGER)) * (0.10 + 0.20 * r5), 1) AS lead_time_std_dev,
    ROUND(25 + 75 * r6, 2)                                       AS ordering_cost     -- $25 to $100
FROM draws;