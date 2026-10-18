-- 05_inventory_policy.sql
-- Calculates safety stock, reorder point and EOQ for every part.
-- Safe to re-run: it rebuilds its tables each time.

-- Model assumptions live in one place so they are easy to change
DROP TABLE IF EXISTS model_params;
CREATE TABLE model_params (holding_rate REAL);
INSERT INTO model_params VALUES (0.20);          -- 20% annual holding cost

-- Z-score lookup (SQLite has no NORM.S.INV, so we store the three values we need)
DROP TABLE IF EXISTS service_levels;
CREATE TABLE service_levels (
    abc_class     TEXT PRIMARY KEY,
    service_level REAL,
    z_score       REAL
);
INSERT INTO service_levels VALUES
    ('A', 0.99, 2.33),
    ('B', 0.97, 1.88),    -- 1.88 is the correct Z for 97% (1.96 would be 97.5%)
    ('C', 0.95, 1.65);

DROP TABLE IF EXISTS inventory_policy;
CREATE TABLE inventory_policy AS
WITH base AS (                       -- Step 1: gather every input in one row per part
    SELECT c.part_id, c.abc_class, c.xyz_class, c.unit_cost,
           c.annual_qty, c.annual_spend,
           p.lead_time_days, p.lead_time_std_dev, p.ordering_cost,
           s.service_level, s.z_score,
           m.holding_rate,
           c.annual_qty / 365.0                AS daily_demand,   -- average units per day
           -- monthly std dev scaled down to daily (assumes days are independent)
           c.std_monthly / SQRT(365.0 / 12)    AS daily_std
    FROM part_classification c
    JOIN parts_master   p ON p.part_id   = c.part_id
    JOIN service_levels s ON s.abc_class = c.abc_class
    CROSS JOIN model_params m
),
calc AS (                            -- Step 2: safety stock before rounding
    SELECT *,
           z_score * SQRT( lead_time_days * daily_std * daily_std
                         + daily_demand * daily_demand
                           * lead_time_std_dev * lead_time_std_dev ) AS ss_raw
    FROM base
)
SELECT part_id, abc_class, xyz_class, unit_cost, annual_qty, annual_spend,
       lead_time_days, lead_time_std_dev, ordering_cost, service_level, z_score,
       ROUND(daily_demand, 3)                              AS daily_demand,
       ROUND(daily_std, 3)                                 AS daily_std,
       CEIL(ss_raw)                                        AS safety_stock,   -- round UP: never under-protect
       CEIL(daily_demand * lead_time_days + ss_raw)        AS rop,
       CEIL(SQRT(2 * annual_qty * ordering_cost
                 / (holding_rate * unit_cost)))            AS eoq
FROM calc;