-- 06_cost_comparison.sql
-- Compares a traditional static-buffer policy with the optimized policy.
-- Safe to re-run.

-- Baseline assumptions. Choose them for a reason, never to hit a target number.
DROP TABLE IF EXISTS baseline_params;
CREATE TABLE baseline_params (buffer_days REAL, order_months REAL);
INSERT INTO baseline_params VALUES (45, 2);   -- 45-day buffer, order 2 months at a time

DROP TABLE IF EXISTS policy_comparison;
CREATE TABLE policy_comparison AS
WITH base AS (                          -- Step 1: inputs plus both policies' stock levels
    SELECT i.part_id, i.abc_class, i.xyz_class,
           i.unit_cost, i.ordering_cost, i.annual_qty, i.annual_spend,
           i.service_level AS target_service,
           i.lead_time_days AS L, i.lead_time_std_dev AS sL,
           i.safety_stock AS ss_opt, i.eoq AS q_opt,           -- optimized policy
           m.holding_rate,
           c.annual_qty / 365.0                 AS d,          -- avg daily demand
           c.std_monthly / SQRT(365.0 / 12)     AS sd,         -- daily std dev
           b.buffer_days  * c.annual_qty / 365.0 AS ss_base,   -- baseline: N days of demand
           b.order_months * c.annual_qty / 12.0  AS q_base     -- baseline: M months per order
    FROM inventory_policy i
    JOIN part_classification c ON c.part_id = i.part_id
    CROSS JOIN model_params m
    CROSS JOIN baseline_params b
),
sig AS (                                -- Step 2: std dev of demand during lead time
    SELECT *, SQRT(L * sd * sd + d * d * sL * sL) AS sigma_lt FROM base
),
zs AS (                                 -- Step 3: how many std devs each buffer covers
    SELECT *,
           CASE WHEN sigma_lt > 0 THEN ss_base / sigma_lt END AS z_base,
           CASE WHEN sigma_lt > 0 THEN ss_opt  / sigma_lt END AS z_opt
    FROM sig
),
cdf AS (                                -- Step 4: helper term for the normal CDF approximation
    SELECT *,
           1.0 / (1 + 0.2316419 * z_base) AS t_b,
           1.0 / (1 + 0.2316419 * z_opt)  AS t_o
    FROM zs
)
SELECT part_id, abc_class, xyz_class, annual_qty, annual_spend,
       unit_cost, ordering_cost, holding_rate, target_service,
       ss_base, q_base, ss_opt, q_opt,
       -- annual holding cost = rate * unit cost * (Q/2 + safety stock)
       holding_rate * unit_cost * (q_base / 2 + ss_base) AS hold_base,
       holding_rate * unit_cost * (q_opt  / 2 + ss_opt)  AS hold_opt,
       -- annual ordering cost = cost per order * number of orders
       CASE WHEN q_base > 0 THEN ordering_cost * annual_qty / q_base ELSE 0 END AS order_base,
       CASE WHEN q_opt  > 0 THEN ordering_cost * annual_qty / q_opt  ELSE 0 END AS order_opt,
       -- cycle service level = normal CDF of Z (Abramowitz-Stegun approximation)
       CASE WHEN z_base IS NULL THEN 1.0 ELSE
            1 - EXP(-z_base * z_base / 2) / 2.5066282746310002 * t_b *
                (0.319381530 + t_b * (-0.356563782 + t_b * (1.781477937
                 + t_b * (-1.821255978 + t_b * 1.330274429)))) END AS csl_base,
       CASE WHEN z_opt IS NULL THEN 1.0 ELSE
            1 - EXP(-z_opt * z_opt / 2) / 2.5066282746310002 * t_o *
                (0.319381530 + t_o * (-0.356563782 + t_o * (1.781477937
                 + t_o * (-1.821255978 + t_o * 1.330274429)))) END AS csl_opt
FROM cdf;