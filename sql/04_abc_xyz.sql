-- 04_abc_xyz.sql
-- Builds part_classification: annual demand, spend, CV, ABC class, XYZ class.
-- Safe to re-run: it rebuilds the table each time.

DROP TABLE IF EXISTS part_classification;

CREATE TABLE part_classification AS
WITH demand AS (                      -- Step 1: summarise 12 months per part
    SELECT p.part_id,
           p.unit_cost,
           SUM(c.consumed_qty)                      AS annual_qty,
           AVG(c.consumed_qty * 1.0)                AS mean_monthly,   -- * 1.0 forces decimal maths
           AVG(c.consumed_qty * c.consumed_qty * 1.0) AS mean_sq       -- average of squares
    FROM parts_master p
    JOIN monthly_consumption c USING (part_id)
    GROUP BY p.part_id, p.unit_cost
),
stats AS (                            -- Step 2: spend and standard deviation
    SELECT part_id, unit_cost, annual_qty, mean_monthly,
           annual_qty * unit_cost AS annual_spend,
           -- variance = AVG(x^2) - AVG(x)^2 ; MAX(...,0) guards against tiny negative rounding errors
           SQRT(MAX(mean_sq - mean_monthly * mean_monthly, 0)) AS std_monthly
    FROM demand
),
ranked AS (                           -- Step 3: share of spend, running total, CV
    SELECT *,
           std_monthly / NULLIF(mean_monthly, 0) AS cv,   -- NULL when mean is 0
           annual_spend * 1.0 / SUM(annual_spend) OVER () AS spend_pct,
           SUM(annual_spend) OVER (
               ORDER BY annual_spend DESC, part_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) * 1.0 / SUM(annual_spend) OVER () AS cum_pct
    FROM stats
)
SELECT part_id,
       unit_cost,
       annual_qty,
       annual_spend,
       mean_monthly,
       std_monthly,
       cv,
       ROUND(cum_pct * 100, 2) AS cum_spend_pct,
       -- cum_pct - spend_pct = running total BEFORE this part, so the part
       -- that crosses 80% is still included in A
       CASE WHEN cum_pct - spend_pct < 0.80 THEN 'A'
            WHEN cum_pct - spend_pct < 0.95 THEN 'B'
            ELSE 'C' END AS abc_class,
       CASE WHEN cv IS NULL THEN 'Z'      -- no demand at all
            WHEN cv <= 0.50 THEN 'X'
            WHEN cv <= 1.00 THEN 'Y'
            ELSE 'Z' END AS xyz_class
FROM ranked;