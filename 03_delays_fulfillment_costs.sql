-- Q4 Delay distribution
SELECT delay_bucket, COUNT(*) AS lines,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_lines
FROM shipments GROUP BY delay_bucket ORDER BY MIN(delay_days);

-- Q5 Delays by shipment mode
SELECT shipment_mode, COUNT(*) AS lines,
       ROUND(100 * AVG(is_late), 1) AS late_pct,
       ROUND(AVG(delay_days) FILTER (WHERE is_late = 1), 1) AS avg_days_late,
       QUANTILE_CONT(delay_days, 0.9) AS p90_delay_days
FROM shipments GROUP BY shipment_mode ORDER BY late_pct DESC;

-- Q6 Countries with the worst on-time performance (50+ lines)
SELECT country, COUNT(*) AS lines, ROUND(100 * AVG(is_late), 1) AS late_pct,
       ROUND(AVG(delay_days) FILTER (WHERE is_late = 1), 1) AS avg_days_late
FROM shipments GROUP BY country HAVING COUNT(*) >= 50
ORDER BY late_pct DESC LIMIT 10;

-- Q7 On-time trend by year
WITH y AS (
  SELECT scheduled_year, COUNT(*) AS lines, AVG(is_on_time) AS otd
  FROM shipments GROUP BY scheduled_year
)
SELECT scheduled_year, lines, ROUND(100 * otd, 1) AS otd_pct,
       ROUND(100 * (otd - LAG(otd) OVER (ORDER BY scheduled_year)), 1) AS change_pts
FROM y ORDER BY scheduled_year;

-- Q8 On-time fulfillment by channel
SELECT fulfill_via, COUNT(*) AS lines,
       ROUND(100 * AVG(is_on_time), 1) AS on_time_fulfillment_pct,
       ROUND(AVG(delay_days), 1) AS avg_delay_days,
       MEDIAN(lead_time_days) AS median_order_to_delivery_days
FROM shipments GROUP BY fulfill_via;

-- Q9 Fulfillment by product group and channel
SELECT product_group, fulfill_via, COUNT(*) AS lines,
       ROUND(100 * AVG(is_on_time), 1) AS on_time_fulfillment_pct
FROM shipments GROUP BY product_group, fulfill_via
HAVING COUNT(*) >= 20 ORDER BY product_group, fulfill_via;

-- Q10 Cost vs speed by shipment mode
SELECT shipment_mode, COUNT(*) AS lines,
       ROUND(SUM(freight_usd)) AS total_freight_usd,
       ROUND(MEDIAN(freight_per_kg), 2) AS median_freight_per_kg,
       ROUND(100 * MEDIAN(freight_pct_of_value), 2) AS median_freight_pct,
       ROUND(100 * AVG(is_late), 1) AS late_pct
FROM shipments GROUP BY shipment_mode ORDER BY median_freight_per_kg DESC;

-- Q11 Most expensive lanes (country x mode)
SELECT country, shipment_mode, COUNT(*) AS lines,
       ROUND(SUM(freight_usd)) AS total_freight_usd,
       ROUND(MEDIAN(freight_per_kg), 2) AS median_freight_per_kg
FROM shipments WHERE freight_usd IS NOT NULL
GROUP BY country, shipment_mode HAVING COUNT(*) >= 20
ORDER BY total_freight_usd DESC LIMIT 10;

-- Q12 Landed cost breakdown
SELECT ROUND(SUM(line_item_value) / 1e6, 1) AS goods_musd,
       ROUND(SUM(freight_usd) / 1e6, 1) AS freight_musd,
       ROUND(SUM(insurance_usd) / 1e6, 2) AS insurance_musd,
       ROUND(100.0 * COUNT(*) FILTER (WHERE freight_status <> 'Reported') / COUNT(*), 1)
             AS pct_lines_without_reported_freight
FROM shipments;

-- Export for Tableau
COPY (SELECT * FROM vendor_scorecard) TO 'tableau/vendor_scorecard.csv' (HEADER, DELIMITER ',');
COPY (SELECT * FROM shipments) TO 'tableau/shipments.csv' (HEADER, DELIMITER ',');
