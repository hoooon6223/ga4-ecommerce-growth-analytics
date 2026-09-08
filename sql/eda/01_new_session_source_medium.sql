-- New session acquisition EDA.
--
-- Operational definition:
--   New Session = ga_session_number = 1
--   First-touch Source/Medium = traffic_source, traffic_medium
--
-- This query checks which first-touch source/medium combinations bring many
-- new sessions and how those sessions convert.

WITH
new_sessions AS (
  SELECT *
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
  WHERE ga_session_number = 1
),
new_session_metrics AS (
  SELECT
    COALESCE(traffic_source, 'unknown') AS first_touch_source,
    COALESCE(traffic_medium, 'unknown') AS first_touch_medium,
    COUNT(*) AS new_sessions,
    ROUND(SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()), 4) AS new_session_share,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS session_cvr
  FROM new_sessions
  GROUP BY
    first_touch_source,
    first_touch_medium
),
new_order_metrics AS (
  SELECT
    COALESCE(s.traffic_source, 'unknown') AS first_touch_source,
    COALESCE(s.traffic_medium, 'unknown') AS first_touch_medium,
    COUNT(*) AS orders,
    ROUND(SUM(o.purchase_revenue), 2) AS revenue,
    ROUND(SAFE_DIVIDE(SUM(o.purchase_revenue), COUNT(*)), 2) AS aov
  FROM `bigquery-457902.ga4_ops_bi.core_f_orders` o
  INNER JOIN new_sessions s
    USING (session_id)
  GROUP BY
    first_touch_source,
    first_touch_medium
)
SELECT
  s.first_touch_source,
  s.first_touch_medium,
  s.new_sessions,
  s.new_session_share,
  s.purchase_sessions,
  COALESCE(o.orders, 0) AS orders,
  COALESCE(o.revenue, 0) AS revenue,
  s.session_cvr,
  o.aov,
  ROUND(SAFE_DIVIDE(o.revenue, s.new_sessions), 4) AS revenue_per_session
FROM new_session_metrics s
LEFT JOIN new_order_metrics o
  USING (first_touch_source, first_touch_medium)
WHERE s.new_sessions >= 1000
ORDER BY
  s.new_sessions DESC;
