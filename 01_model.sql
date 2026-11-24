-- Fact table: one row per shipment line
CREATE OR REPLACE TABLE shipments AS
SELECT * FROM read_csv_auto('data/clean/shipments_clean.csv');

-- Dimensions
CREATE OR REPLACE VIEW dim_vendor AS
SELECT vendor,
       ANY_VALUE(is_internal_rdc) AS is_internal_rdc,
       COUNT(DISTINCT manufacturing_site) AS manufacturing_sites,
       MIN(scheduled_date) AS first_order_date,
       MAX(scheduled_date) AS last_order_date
FROM shipments GROUP BY vendor;

CREATE OR REPLACE VIEW dim_country AS
SELECT country, COUNT(*) AS order_lines, SUM(line_item_value) AS total_value_usd
FROM shipments GROUP BY country;

-- Data quality check
SELECT COUNT(*) AS row_count,
       MIN(scheduled_date) AS first_date,
       MAX(scheduled_date) AS last_date,
       COUNT(*) FILTER (WHERE delivered_date IS NULL) AS missing_delivery,
       COUNT(*) FILTER (WHERE freight_usd IS NULL) AS no_numeric_freight
FROM shipments;
