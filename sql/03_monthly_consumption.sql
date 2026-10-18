-- 03_monthly_consumption.sql
-- Generates 12 months of consumption for each of the 500 parts (6,000 rows).
-- Safe to re-run: it clears the table first.

DELETE FROM monthly_consumption;

WITH profile AS MATERIALIZED (            -- one fixed "personality" per part
    SELECT part_id,
           (RANDOM() & 2147483647) / 2147483648.0 AS pat,   -- picks X / Y / Z
           (RANDOM() & 2147483647) / 2147483648.0 AS b      -- picks base demand
    FROM parts_master
),
months(month_name) AS (
    VALUES ('Jan'),('Feb'),('Mar'),('Apr'),('May'),('Jun'),
           ('Jul'),('Aug'),('Sep'),('Oct'),('Nov'),('Dec')
),
draws AS MATERIALIZED (                   -- one random draw per part per month
    SELECT p.part_id,
           m.month_name,
           p.pat,
           3 + 40.0 * p.b * p.b AS base,  -- base monthly demand: about 3 to 43, skewed low
           (RANDOM() & 2147483647) / 2147483648.0 AS r
    FROM profile p
    CROSS JOIN months m                   -- every part paired with every month
)
INSERT INTO monthly_consumption (part_id, month_name, consumed_qty)
SELECT part_id,
       month_name,
       CAST(ROUND(
           CASE
               WHEN pat < 0.50 THEN base * (0.5 + r)   -- X: steady (50% to 150% of base)
               WHEN pat < 0.80 THEN base * 2 * r       -- Y: moderate (0% to 200% of base)
               WHEN r < 0.25   THEN base * 4           -- Z: occasional spike
               ELSE base * 0.1                         -- Z: otherwise near zero
           END
       ) AS INTEGER)
FROM draws;