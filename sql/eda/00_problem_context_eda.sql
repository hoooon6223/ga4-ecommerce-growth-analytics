-- Problem context EDA for GA4 ecommerce analysis.
--
-- This query does not create a mart. It summarizes the current core marts using
-- the operational definitions in docs/metric_definitions.md.

WITH
sessions AS (
  SELECT *
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
),
orders AS (
  SELECT *
  FROM `bigquery-457902.ga4_ops_bi.core_f_orders`
),
overall_sessions AS (
  SELECT
    COUNT(*) AS sessions,
    COUNT(DISTINCT anonymous_id) AS users,
    COUNTIF(has_purchase) AS purchase_sessions,
    COUNTIF(ga_session_number = 1) AS new_sessions,
    COUNTIF(ga_session_number > 1) AS returning_sessions,
    SAFE_DIVIDE(COUNTIF(ga_session_number = 1), COUNT(*)) AS new_session_share
  FROM sessions
),
overall_orders AS (
  SELECT
    COUNT(*) AS orders,
    COUNT(DISTINCT anonymous_id) AS buyer_users,
    SUM(purchase_revenue) AS revenue
  FROM orders
),
overall AS (
  SELECT
    s.sessions,
    s.users,
    s.purchase_sessions,
    o.orders,
    ROUND(o.revenue, 2) AS revenue,
    ROUND(SAFE_DIVIDE(s.purchase_sessions, s.sessions), 4) AS session_cvr,
    ROUND(SAFE_DIVIDE(o.revenue, o.orders), 2) AS aov,
    ROUND(SAFE_DIVIDE(o.revenue, s.sessions), 4) AS revenue_per_session,
    s.new_sessions,
    s.returning_sessions,
    ROUND(s.new_session_share, 4) AS new_session_share
  FROM overall_sessions s
  CROSS JOIN overall_orders o
),
overall_user_revenue_decomposition AS (
  SELECT
    s.users AS active_users,
    o.buyer_users,
    o.orders,
    ROUND(o.revenue, 2) AS revenue,
    ROUND(SAFE_DIVIDE(o.buyer_users, s.users), 4) AS buyer_cvr,
    ROUND(SAFE_DIVIDE(o.revenue, o.buyer_users), 2) AS arppu,
    ROUND(SAFE_DIVIDE(o.orders, o.buyer_users), 2) AS orders_per_buyer
  FROM overall_sessions s
  CROSS JOIN overall_orders o
),
monthly_sessions AS (
  SELECT
    DATE_TRUNC(partition_day, MONTH) AS month,
    COUNT(*) AS sessions,
    COUNT(DISTINCT anonymous_id) AS users,
    COUNTIF(has_purchase) AS purchase_sessions,
    COUNTIF(ga_session_number = 1) AS new_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(ga_session_number = 1), COUNT(*)), 4) AS new_session_share
  FROM sessions
  GROUP BY month
),
monthly_orders AS (
  SELECT
    DATE_TRUNC(partition_day, MONTH) AS month,
    COUNT(*) AS orders,
    COUNT(DISTINCT anonymous_id) AS buyer_users,
    SUM(purchase_revenue) AS revenue
  FROM orders
  GROUP BY month
),
monthly AS (
  SELECT
    s.month,
    s.sessions,
    s.users,
    s.purchase_sessions,
    o.orders,
    ROUND(o.revenue, 2) AS revenue,
    ROUND(SAFE_DIVIDE(s.purchase_sessions, s.sessions), 4) AS session_cvr,
    ROUND(SAFE_DIVIDE(o.revenue, o.orders), 2) AS aov,
    ROUND(SAFE_DIVIDE(o.revenue, s.sessions), 4) AS revenue_per_session,
    s.new_sessions,
    s.new_session_share
  FROM monthly_sessions s
  LEFT JOIN monthly_orders o USING (month)
),
monthly_user_revenue_decomposition AS (
  SELECT
    s.month,
    s.users AS active_users,
    COALESCE(o.buyer_users, 0) AS buyer_users,
    COALESCE(o.orders, 0) AS orders,
    ROUND(COALESCE(o.revenue, 0), 2) AS revenue,
    ROUND(SAFE_DIVIDE(o.buyer_users, s.users), 4) AS buyer_cvr,
    ROUND(SAFE_DIVIDE(o.revenue, o.buyer_users), 2) AS arppu,
    ROUND(SAFE_DIVIDE(o.orders, o.buyer_users), 2) AS orders_per_buyer
  FROM monthly_sessions s
  LEFT JOIN monthly_orders o USING (month)
),
new_vs_returning_sessions AS (
  SELECT
    CASE
      WHEN ga_session_number = 1 THEN 'new_session'
      WHEN ga_session_number > 1 THEN 'returning_session'
      ELSE 'unknown'
    END AS session_type,
    COUNT(*) AS sessions,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS session_cvr
  FROM sessions
  GROUP BY session_type
),
new_vs_returning_orders AS (
  SELECT
    CASE
      WHEN s.ga_session_number = 1 THEN 'new_session'
      WHEN s.ga_session_number > 1 THEN 'returning_session'
      ELSE 'unknown'
    END AS session_type,
    COUNT(*) AS orders,
    ROUND(SUM(o.purchase_revenue), 2) AS revenue,
    ROUND(SAFE_DIVIDE(SUM(o.purchase_revenue), COUNT(*)), 2) AS aov
  FROM orders o
  LEFT JOIN sessions s USING (session_id)
  GROUP BY session_type
),
new_vs_returning AS (
  SELECT
    s.session_type,
    s.sessions,
    s.purchase_sessions,
    COALESCE(o.orders, 0) AS orders,
    COALESCE(o.revenue, 0) AS revenue,
    s.session_cvr,
    o.aov,
    ROUND(SAFE_DIVIDE(o.revenue, s.sessions), 4) AS revenue_per_session
  FROM new_vs_returning_sessions s
  LEFT JOIN new_vs_returning_orders o USING (session_type)
),
source_sessions AS (
  SELECT
    COALESCE(traffic_source, 'unknown') AS first_touch_source,
    COALESCE(traffic_medium, 'unknown') AS first_touch_medium,
    COUNT(*) AS sessions,
    ROUND(SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()), 4) AS session_share,
    COUNTIF(ga_session_number = 1) AS new_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(ga_session_number = 1), COUNT(*)), 4) AS new_session_share,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS session_cvr
  FROM sessions
  GROUP BY first_touch_source, first_touch_medium
),
source_orders AS (
  SELECT
    COALESCE(traffic_source, 'unknown') AS first_touch_source,
    COALESCE(traffic_medium, 'unknown') AS first_touch_medium,
    COUNT(*) AS orders,
    ROUND(SUM(purchase_revenue), 2) AS revenue,
    ROUND(SAFE_DIVIDE(SUM(purchase_revenue), COUNT(*)), 2) AS aov
  FROM orders
  GROUP BY first_touch_source, first_touch_medium
),
source_metrics AS (
  SELECT
    s.first_touch_source,
    s.first_touch_medium,
    s.sessions,
    s.session_share,
    s.new_sessions,
    s.new_session_share,
    s.purchase_sessions,
    COALESCE(o.orders, 0) AS orders,
    COALESCE(o.revenue, 0) AS revenue,
    s.session_cvr,
    o.aov,
    ROUND(SAFE_DIVIDE(o.revenue, s.sessions), 4) AS revenue_per_session
  FROM source_sessions s
  LEFT JOIN source_orders o USING (first_touch_source, first_touch_medium)
  WHERE s.sessions >= 1000
),
funnel_reach AS (
  SELECT
    COUNT(*) AS sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(has_view_item), COUNT(*)), 4) AS view_item_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(has_add_to_cart), COUNT(*)), 4) AS add_to_cart_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(has_begin_checkout), COUNT(*)), 4) AS checkout_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS purchase_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS overall_session_cvr
  FROM sessions
),
device_sessions AS (
  SELECT
    COALESCE(device_category, 'unknown') AS device_category,
    COUNT(*) AS sessions,
    ROUND(SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()), 4) AS session_share,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS session_cvr
  FROM sessions
  GROUP BY device_category
),
device_orders AS (
  SELECT
    COALESCE(device_category, 'unknown') AS device_category,
    COUNT(*) AS orders,
    ROUND(SUM(purchase_revenue), 2) AS revenue,
    ROUND(SAFE_DIVIDE(SUM(purchase_revenue), COUNT(*)), 2) AS aov
  FROM orders
  GROUP BY device_category
),
device_metrics AS (
  SELECT
    s.device_category,
    s.sessions,
    s.session_share,
    s.purchase_sessions,
    COALESCE(o.orders, 0) AS orders,
    COALESCE(o.revenue, 0) AS revenue,
    s.session_cvr,
    o.aov,
    ROUND(SAFE_DIVIDE(o.revenue, s.sessions), 4) AS revenue_per_session
  FROM device_sessions s
  LEFT JOIN device_orders o USING (device_category)
)
SELECT
  'overall' AS section,
  TO_JSON_STRING(ARRAY_AGG(overall)) AS result
FROM overall
UNION ALL
SELECT
  'overall_user_revenue_decomposition' AS section,
  TO_JSON_STRING(ARRAY_AGG(overall_user_revenue_decomposition)) AS result
FROM overall_user_revenue_decomposition
UNION ALL
SELECT
  'monthly' AS section,
  TO_JSON_STRING(ARRAY_AGG(monthly ORDER BY month)) AS result
FROM monthly
UNION ALL
SELECT
  'monthly_user_revenue_decomposition' AS section,
  TO_JSON_STRING(ARRAY_AGG(monthly_user_revenue_decomposition ORDER BY month)) AS result
FROM monthly_user_revenue_decomposition
UNION ALL
SELECT
  'new_vs_returning' AS section,
  TO_JSON_STRING(ARRAY_AGG(new_vs_returning ORDER BY session_type)) AS result
FROM new_vs_returning
UNION ALL
SELECT
  'first_touch_source_medium_top' AS section,
  TO_JSON_STRING(ARRAY_AGG(source_metrics ORDER BY sessions DESC LIMIT 15)) AS result
FROM source_metrics
UNION ALL
SELECT
  'funnel_reach' AS section,
  TO_JSON_STRING(ARRAY_AGG(funnel_reach)) AS result
FROM funnel_reach
UNION ALL
SELECT
  'device_metrics' AS section,
  TO_JSON_STRING(ARRAY_AGG(device_metrics ORDER BY sessions DESC)) AS result
FROM device_metrics;
