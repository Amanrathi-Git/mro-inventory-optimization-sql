-- 01_schema.sql
-- Creates the two tables. Safe to re-run: it drops and rebuilds them.

PRAGMA foreign_keys = ON;   -- make SQLite enforce the FK link

DROP TABLE IF EXISTS monthly_consumption;   -- child first
DROP TABLE IF EXISTS parts_master;          -- then parent

CREATE TABLE parts_master (
    part_id            TEXT PRIMARY KEY,   -- e.g. MRO-0001
    part_name          TEXT    NOT NULL,
    unit_cost          REAL    NOT NULL,   -- $ per unit
    lead_time_days     INTEGER NOT NULL,   -- average supplier lead time
    lead_time_std_dev  REAL    NOT NULL,   -- variability of lead time (days)
    ordering_cost      REAL    NOT NULL    -- $ fixed cost per purchase order
);

CREATE TABLE monthly_consumption (
    part_id       TEXT    NOT NULL,
    month_name    TEXT    NOT NULL,        -- 'Jan' ... 'Dec'
    consumed_qty  INTEGER NOT NULL,
    PRIMARY KEY (part_id, month_name),     -- one row per part per month
    FOREIGN KEY (part_id) REFERENCES parts_master (part_id)
);