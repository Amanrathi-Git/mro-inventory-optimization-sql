-- 07_results.sql
-- Read-only report. Run it any time.
.headers on
.mode column

.print '--- 1. Annual cost: baseline vs optimized ($) ---'
SELECT ROUND(SUM(hold_base))                         AS holding_baseline,
       ROUND(SUM(hold_opt))                          AS holding_optimized,
       ROUND(100.0 * (SUM(hold_base) - SUM(hold_opt)) / SUM(hold_base), 1) AS holding_saving_pct,
       ROUND(SUM(hold_base + order_base))            AS total_baseline,
       ROUND(SUM(hold_opt + order_opt))              AS total_optimized,
       ROUND(100.0 * (SUM(hold_base + order_base) - SUM(hold_opt + order_opt))
             / SUM(hold_base + order_base), 1)       AS total_saving_pct
FROM policy_comparison;

.print ''
.print '--- 2a. Blended cycle service level (weighted by annual spend) ---'
SELECT ROUND(100.0 * SUM(annual_spend * target_service) / SUM(annual_spend), 2) AS target_blended_pct,
       ROUND(100.0 * SUM(annual_spend * csl_opt)  / SUM(annual_spend), 2)       AS optimized_achieved_pct,
       ROUND(100.0 * SUM(annual_spend * csl_base) / SUM(annual_spend), 2)       AS baseline_achieved_pct
FROM policy_comparison;

.print ''
.print '--- 2b. Service level by ABC class (simple average of parts) ---'
SELECT abc_class,
       ROUND(100 * AVG(target_service), 1) AS target_pct,
       ROUND(100 * AVG(csl_opt), 1)        AS optimized_pct,
       ROUND(100 * AVG(csl_base), 1)       AS baseline_pct
FROM policy_comparison GROUP BY abc_class ORDER BY abc_class;

.print ''
.print '--- 3. Holding cost by ABC class ($) ---'
SELECT abc_class,
       ROUND(SUM(hold_base)) AS holding_baseline,
       ROUND(SUM(hold_opt))  AS holding_optimized,
       ROUND(100.0 * (SUM(hold_base) - SUM(hold_opt)) / SUM(hold_base), 1) AS saving_pct
FROM policy_comparison GROUP BY abc_class ORDER BY abc_class;

.print ''
.print '--- 4. Sensitivity: saving under different baseline assumptions ---'
WITH nb(buffer_days)  AS (VALUES (30), (45), (60), (90)),
     om(order_months) AS (VALUES (1), (2), (3)),
     g AS (
        SELECT nb.buffer_days, om.order_months, p.hold_opt, p.order_opt,
               p.holding_rate * p.unit_cost *
                 (om.order_months * p.annual_qty / 24.0 + nb.buffer_days * p.annual_qty / 365.0) AS hb,
               CASE WHEN p.annual_qty > 0 THEN p.ordering_cost * 12.0 / om.order_months ELSE 0 END AS ob
        FROM nb CROSS JOIN om CROSS JOIN policy_comparison p
     )
SELECT buffer_days, order_months,
       ROUND(100.0 * (SUM(hb) - SUM(hold_opt)) / SUM(hb), 1)                       AS holding_saving_pct,
       ROUND(100.0 * (SUM(hb + ob) - SUM(hold_opt + order_opt)) / SUM(hb + ob), 1) AS total_saving_pct
FROM g GROUP BY buffer_days, order_months ORDER BY buffer_days, order_months;