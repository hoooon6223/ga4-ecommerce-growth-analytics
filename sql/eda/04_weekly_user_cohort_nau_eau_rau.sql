-- Weekly active user cohort EDA.
--
-- Operational definition:
--   WAU = distinct anonymous_id active in a week
--   NAU = observed new active user whose first active week is the current week
--   EAU = existing/retained active user active in both previous week and current week
--   RAU = returned active user with prior activity, inactive in previous week, active again in current week
--
-- Notes:
--   anonymous_id is based on GA4 user_pseudo_id, not a backend customer ID.
--   NAU means observed new within the available data window, not necessarily a true first-time customer.
--   The first observed week is a warm-up week because prior activity is unavailable.

WITH sessions AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    anonymous_id
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
  WHERE anonymous_id IS NOT NULL
  GROUP BY
    week_start,
    anonymous_id
),
user_week_history AS (
  SELECT
    week_start,
    anonymous_id,
    MIN(week_start) OVER (PARTITION BY anonymous_id) AS first_active_week,
    LAG(week_start) OVER (PARTITION BY anonymous_id ORDER BY week_start) AS previous_active_week
  FROM sessions
),
classified_user_weeks AS (
  SELECT
    week_start,
    anonymous_id,
    CASE
      WHEN first_active_week = week_start THEN 'NAU'
      WHEN previous_active_week = DATE_SUB(week_start, INTERVAL 1 WEEK) THEN 'EAU'
      ELSE 'RAU'
    END AS active_user_segment,
    week_start = MIN(week_start) OVER () AS is_first_observed_week
  FROM user_week_history
),
orders AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    anonymous_id,
    order_id,
    purchase_revenue
  FROM `bigquery-457902.ga4_ops_bi.core_f_orders`
  WHERE anonymous_id IS NOT NULL
),
weekly_segment_metrics AS (
  SELECT
    u.week_start,
    DATE_ADD(u.week_start, INTERVAL 6 DAY) AS week_end,
    u.active_user_segment,
    LOGICAL_OR(u.is_first_observed_week) AS is_first_observed_week,
    COUNT(DISTINCT u.anonymous_id) AS active_users,
    COUNT(DISTINCT o.anonymous_id) AS buyer_users,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(COALESCE(o.purchase_revenue, 0)), 2) AS revenue
  FROM classified_user_weeks u
  LEFT JOIN orders o
    ON u.week_start = o.week_start
    AND u.anonymous_id = o.anonymous_id
  GROUP BY
    u.week_start,
    week_end,
    u.active_user_segment
)
SELECT
  week_start,
  week_end,
  active_user_segment,
  is_first_observed_week,
  active_users,
  buyer_users,
  orders,
  revenue,
  ROUND(SAFE_DIVIDE(buyer_users, active_users), 4) AS buyer_cvr,
  ROUND(SAFE_DIVIDE(revenue, buyer_users), 2) AS arppu,
  ROUND(SAFE_DIVIDE(revenue, active_users), 4) AS revenue_per_active_user
FROM weekly_segment_metrics
ORDER BY
  week_start,
  CASE active_user_segment
    WHEN 'NAU' THEN 1
    WHEN 'EAU' THEN 2
    WHEN 'RAU' THEN 3
    ELSE 4
  END;
