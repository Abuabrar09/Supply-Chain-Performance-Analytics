-- Q1 Headline KPIs
SELECT COUNT(*) AS order_lines,
       ROUND(SUM(line_item_value) / 1e6, 1) AS value_musd,
       ROUND(100 * AVG(is_on_time), 1) AS otd_pct,
       ROUND(AVG(delay_days) FILTER (WHERE is_late = 1), 1) AS avg_days_late_when_late,
       MEDIAN(lead_time_days) AS median_lead_time_days,
       ROUND(100 * SUM(freight_usd) FILTER (WHERE freight_status = 'Reported' AND line_item_value > 0)
             / SUM(line_item_value) FILTER (WHERE freight_status = 'Reported' AND line_item_value > 0), 2)
             AS freight_pct_of_value
FROM shipments;

-- Q2 Supplier scorecard (real vendors with 20+ lines)
CREATE OR REPLACE VIEW vendor_scorecard AS
WITH v AS (
  SELECT vendor,
         COUNT(*) AS order_lines,
         SUM(line_item_value) AS total_value_usd,
         AVG(is_on_time) AS otd_rate,
         COALESCE(AVG(delay_days) FILTER (WHERE is_late = 1), 0) AS avg_days_late,
         MEDIAN(lead_time_days) AS median_lead_time_days,
         SUM(freight_usd) FILTER (WHERE freight_status = 'Reported' AND line_item_value > 0)
           / NULLIF(SUM(line_item_value) FILTER (WHERE freight_status = 'Reported' AND line_item_value > 0), 0)
           AS freight_pct
  FROM shipments
  WHERE NOT is_internal_rdc
  GROUP BY vendor
  HAVING COUNT(*) >= 20
),
scored AS (
  SELECT *,
         PERCENT_RANK() OVER (ORDER BY otd_rate) AS otd_score,
         PERCENT_RANK() OVER (ORDER BY avg_days_late DESC) AS delay_score,
         CASE WHEN freight_pct IS NULL THEN 0.5
              ELSE PERCENT_RANK() OVER (PARTITION BY freight_pct IS NULL ORDER BY freight_pct DESC)
         END AS cost_score
  FROM v
)
SELECT vendor, order_lines, ROUND(total_value_usd) AS total_value_usd,
       ROUND(100 * otd_rate, 1) AS otd_pct,
       ROUND(avg_days_late, 1) AS avg_days_late,
       median_lead_time_days,
       ROUND(100 * freight_pct, 2) AS freight_pct,
       ROUND(100 * (0.5 * otd_score + 0.3 * delay_score + 0.2 * cost_score), 1) AS supplier_score,
       CASE WHEN 0.5 * otd_score + 0.3 * delay_score + 0.2 * cost_score >= 0.67 THEN 'Preferred'
            WHEN 0.5 * otd_score + 0.3 * delay_score + 0.2 * cost_score >= 0.33 THEN 'Acceptable'
            ELSE 'At risk' END AS supplier_tier
FROM scored;

SELECT * FROM vendor_scorecard ORDER BY supplier_score DESC;

-- Q3 Spend concentration (Pareto)
SELECT vendor, ROUND(value_usd) AS value_usd,
       ROUND(100 * SUM(value_usd) OVER (ORDER BY value_usd DESC) / SUM(value_usd) OVER (), 1) AS cumulative_pct
FROM (SELECT vendor, SUM(line_item_value) AS value_usd
      FROM shipments WHERE NOT is_internal_rdc GROUP BY vendor)
ORDER BY value_usd DESC
LIMIT 15;
