# Supply Chain Performance Analytics

End-to-end analysis of **10,324 real USAID health-commodity shipment lines (2006–2015, $1.63B in value)** to measure supplier performance, delivery delays, fulfillment rates and supply chain costs.

**Tools:** Python (pandas, SciPy, scikit-learn) · SQL (DuckDB) · Tableau Public · Google Colab

👉 **[View the interactive Tableau dashboards](https://public.tableau.com/app/profile/abrar.ahmed.syed4247/viz/SupplyChainShipmentPricingData_17952087968890/ExecutiveOverview)**

![Executive Overview](images/dashboard_executive_overview.png)

---

## Business questions

1. Which suppliers deliver reliably, and which high-spend suppliers are a risk?
2. How late are shipments, and does lateness depend on shipment mode or country?
3. Is fulfillment more reliable from regional warehouses (RDC) or direct from the vendor?
4. Which modes and lanes drive freight cost, and is faster shipping worth the premium?

## Key findings

| # | Finding | Evidence |
|---|---------|----------|
| 1 | **88.5% on-time delivery overall**, but late shipments average **21.4 days late**. | 10,324 lines; 4.1% were 1–7 days late, 5.2% 8–30 days, 2.2% over 30 days |
| 2 | **On-time performance collapsed in 2010–2011** (96.4% in 2009 → 76.5% in 2011, monthly lows near 60%) before recovering to 92.1% in 2012. | Yearly SQL trend + 3-month moving average |
| 3 | **Spend is highly concentrated:** 7 vendors account for 82% of supplier spend; Orgenics alone is 27%. | SQL Pareto with window functions |
| 4 | **Two of the largest suppliers are high-risk.** Aurobindo ($91.4M, 85.9% on-time, 35.6 avg days late) and Cipla ($39.7M, 86.9% on-time, 40.9 avg days late) score in the bottom tier. | Weighted supplier scorecard |
| 5 | **Direct Drop outperforms the warehouse:** 94.7% on time vs 82.8% via RDC (χ² = 356.9, p < 0.001). The gap is concentrated in ARV drugs (95.6% vs 82.3%). | Chi-square test |
| 6 | **Air is ~6× more expensive than Ocean per kg ($10.02 vs $1.68) but late about half as often (9.6% vs 17.5%).** Truck sits in between ($2.50/kg, 16.1% late). Mode significantly affects delay (Kruskal-Wallis H = 640.9, p < 0.001). | SQL + Kruskal-Wallis |
| 7 | **Weight explains much of freight cost (Spearman ρ = 0.74)**, but Air and Air Charter carry a clear premium at the same weight. Nigeria is the most expensive destination (~$14M in Air and Air Charter freight). | Spearman correlation, lane analysis |
| 8 | **Lateness is predictable from order attributes** (logistic regression AUC = 0.74). RDC fulfillment, Ocean mode, HIV test kits (HRDT) and DDP terms raise the risk of a late delivery. | scikit-learn |

## Recommendations

- **Put Aurobindo and Cipla on supplier improvement plans.** Together they represent about $131M in spend with the longest delays among major vendors.
- **Review RDC processes for ARV drugs**, where warehouse fulfillment lags direct drop by 13 points.
- **Use Air selectively** for time-critical orders and shift non-urgent volume to Truck/Ocean, while tightening Ocean schedules.
- **Capture freight cost on every line.** 40% of lines have no separately reported freight cost, which limits cost visibility.

## Dashboards

| Dashboard | What it shows |
|-----------|---------------|
| **Executive Overview** | KPI tiles, on-time trend vs 95% target, delay distribution, late % by country (clickable map) and by mode |
| **Supplier Scorecard** | Supplier score (0–100) by vendor, tier coloring, reliability vs freight-cost bubble chart |
| **Fulfillment & Cost** | On-time % by product group and channel, freight cost per kg vs late % by mode, top 10 freight lanes |

![Supplier Scorecard](images/dashboard_supplier_scorecard.png)
![Fulfillment & Cost](images/dashboard_fulfillment_cost.png)

## Data

- **Source:** USAID Supply Chain Management System (SCMS) Delivery History, published as *Supply Chain Shipment Pricing Data* (originally on data.usaid.gov; mirrored on Kaggle).
- **Scope:** 10,324 shipment lines, 33 fields, 2006–2015, ARV and HIV lab commodities shipped to 40+ countries.
- The raw file is not included in this repo. Download it from Kaggle and place it at `data/raw/scms_delivery_history.csv`.

**Data-quality issues handled**

- Dates stored as text (`2-Jun-06`), plus placeholders such as `Date Not Captured` and `N/A - From RDC`
- Freight and weight fields mixing numbers and text (`Freight Included in Commodity Cost`, `Invoiced Separately`, `See DN-304 (ID#:10589)`); classified into a `freight_status` column (6,198 reported, 2,445 on another line, 1,442 included, 239 invoiced separately)
- Blank shipment modes kept as `Unknown`
- Internal warehouse "vendor" (`SCMS from RDC`) excluded from supplier scoring and analyzed as a fulfillment channel
- File encoding (cp1252)

## Method

```
Raw CSV ──► Python cleaning ──► DuckDB SQL model & KPIs ──► Python statistics ──► Tableau dashboards
           (clean_data.py)      (sql/*.sql)                  (analysis.py)        (Tableau Public)
```

**KPI definitions**

| KPI | Definition |
|-----|------------|
| On-time delivery (OTD) | Share of lines delivered on or before the scheduled date |
| Delay days | Delivered date − scheduled date |
| Lead time | Delivered date − PO sent to vendor (direct-drop orders; median 92 days) |
| Freight % of value | Freight ÷ line value, for lines with a reported freight number |
| Freight per kg | Freight ÷ weight |
| Supplier score | 50% on-time rate + 30% lateness severity + 20% freight cost, as percentile ranks (vendors with 20+ lines) |

**SQL techniques:** CTEs, window functions (`PERCENT_RANK`, running `SUM`, `LAG`, moving averages), filtered aggregates, percentiles, views, star-schema style dimensions.

**Statistics:** Kruskal-Wallis, chi-square, Spearman correlation, logistic regression with AUC.

## Repository structure

```
supply-chain-performance-analytics/
├── README.md
├── clean_data.py                      # Step 3: cleaning + KPI columns
├── run_sql.py                         # helper to run .sql files in DuckDB
├── analysis.py                        # Step 5: statistical tests + charts
├── notebooks/
│   └── Supply_Chain_Project.ipynb     # full Colab workflow
├── sql/
│   ├── 01_model.sql                   # fact table, dimensions, data-quality check
│   ├── 02_kpis.sql                    # headline KPIs, supplier scorecard, Pareto
│   └── 03_delays_fulfillment_costs.sql
└── images/                            # charts and dashboard screenshots
```

## How to run

1. Open `notebooks/Supply_Chain_Project.ipynb` in Google Colab (or any Python 3 environment).
2. `pip install duckdb pandas scipy scikit-learn seaborn`
3. Place the raw CSV in `data/raw/`, then run:

```bash
python clean_data.py
python run_sql.py sql/01_model.sql
python run_sql.py sql/02_kpis.sql
python run_sql.py sql/03_delays_fulfillment_costs.sql
python analysis.py
```

## Limitations

- No ordered-vs-shipped quantities, so "fulfillment rate" is measured as on-time fulfillment rather than unit fill rate.
- About 62% of lines were delivered exactly on the scheduled date, which suggests schedules were sometimes updated at delivery; true lateness may be understated.
- 40% of lines lack a separately reported freight cost.
- Historical public-sector data (2006–2015); patterns may differ from commercial supply chains.

---

**Author:** Abrar Ahmed Syed · [LinkedIn](https://www.linkedin.com/in/abrar313) · [Tableau Public](https://public.tableau.com/app/profile/abrar.ahmed.syed4247)
