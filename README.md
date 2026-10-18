# MRO Spare Parts Inventory Optimization (SQL)

An end-to-end inventory optimization model in pure SQL (SQLite) for 500 **simulated** MRO spare parts with 12 months of consumption each. It covers ABC-XYZ segmentation, safety stock, reorder points and EOQ, and compares the result against a static-buffer baseline.

> **Data note:** all data is synthetic, generated in `sql/02` and `sql/03`. Results show how the method behaves, not real plant performance.

## Pipeline

| File | Purpose |
|---|---|
| `sql/00_check_setup.sql` | Confirms SQLite supports CTEs, window functions and math functions |
| `sql/01_schema.sql` | Creates `parts_master` and `monthly_consumption` |
| `sql/02_parts_master.sql` | Generates 500 parts with skewed unit costs |
| `sql/03_monthly_consumption.sql` | Generates 12 months of steady, variable and lumpy demand |
| `sql/04_abc_xyz.sql` | ABC (80/15/5 by cumulative spend) and XYZ (CV thresholds 0.5 / 1.0) |
| `sql/05_inventory_policy.sql` | Safety stock, reorder point and EOQ |
| `sql/06_cost_comparison.sql` | Baseline vs optimized holding, ordering cost and service level |
| `sql/07_results.sql` | Results report and sensitivity grid |

## How to run

```bash
sqlite3 data/mro.db < sql/04_abc_xyz.sql
sqlite3 data/mro.db < sql/05_inventory_policy.sql
sqlite3 data/mro.db < sql/06_cost_comparison.sql
sqlite3 data/mro.db < sql/07_results.sql
```

`data/mro.db` is included so the numbers below reproduce exactly. Re-running `02` and `03` generates a new random dataset, so results will change.

## Method

- **ABC:** classes by cumulative share of annual spend (A 80%, B 15%, C 5%).
- **XYZ:** coefficient of variation of monthly demand (X ≤ 0.5, Y ≤ 1.0, Z > 1.0). Population standard deviation is computed as `SQRT(AVG(x²) − AVG(x)²)`.
- **Safety stock:** `Z × √(L·σd² + d²·σL²)`, combining demand and lead-time variability.
- **Service targets:** A 99% (Z = 2.33), B 97% (Z = 1.88), C 95% (Z = 1.65).
- **Reorder point:** `d × L + safety stock`.
- **EOQ:** `√(2·D·S / (h·C))` with a 20% annual holding rate.
- **Baseline:** 45-day buffer on every part, ordering two months at a time.

## Results (45-day / 2-month baseline)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Annual holding cost | $1,033,380 | $790,633 | -23.5% |
| Holding + ordering cost | $1,222,915 | $998,129 | -18.4% |
| Blended cycle service level | 96.96% | 98.78% | +1.8 pts |

By class, holding cost fell 28.6% for A and 11.3% for B, and rose 23.1% for C. Cheap, erratic C parts receive more buffer, while expensive A parts were over-buffered.

## Limitations

- Synthetic data; real demand would differ.
- The baseline is an assumption. Across a grid of 30 to 90 buffer days and 1 to 3 order months, the holding saving ranges from -27.6% to +57.5%. The "cheaper and better protected" claim holds at the 45-day / 2-month baseline.
- Safety stock assumes roughly normal demand, which fits lumpy Z items poorly.
- Daily demand variance is scaled from monthly assuming independence.
- Service level is a cycle service level, not a fill rate. Stockout cost is not modeled.

## Validation

MRO-0003 was recomputed independently in Excel and matched the SQL output (safety stock 48, reorder point 89, EOQ 17).