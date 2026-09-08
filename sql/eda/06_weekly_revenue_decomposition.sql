-- Weekly revenue decomposition EDA.
--
-- Business goal:
--   Weekly Revenue Growth
--
-- KPI decomposition:
--   Weekly Revenue = WAU x Weekly Buyer CVR x ARPPU
--
-- Operational definitions:
--   WAU = distinct anonymous_id with at least one session in the week
--   Weekly Buyer Users = distinct anonymous_id with at least one purchase in the week
--   Weekly Buyer CVR = Weekly Buyer Users / WAU
--   ARPPU = Weekly Revenue / Weekly Buyer Users
--
-- Segment definitions:
--   NAU = observed new active user whose first active week is the current week
--   EAU = existing/retained active user active in both previous week and current week
--   RAU = returned active user with prior activity, inactive in previous week, active again in current week
--
-- Notes:
--   anonymous_id is based on GA4 user_pseudo_id, not a backend customer ID.
--   The first 4 observed weeks are marked as warm-up for lifecycle segment interpretation.

WITH weekly_active_users AS (
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
  FROM weekly_active_users
),
observed_weeks AS (
  SELECT
    week_start,
    DENSE_RANK() OVER (ORDER BY week_start) AS observed_week_number
  FROM (
    SELECT DISTINCT week_start
    FROM weekly_active_users
  )
),
classified_active_users AS (
  SELECT
    h.week_start,
    h.anonymous_id,
    CASE
      WHEN h.first_active_week = h.week_start THEN 'NAU'
      WHEN h.previous_active_week = DATE_SUB(h.week_start, INTERVAL 1 WEEK) THEN 'EAU'
      ELSE 'RAU'
    END AS active_user_segment,
    w.observed_week_number <= 4 AS is_warmup_week
  FROM user_week_history h
  INNER JOIN observed_weeks w
    USING (week_start)
),
weekly_orders AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    anonymous_id,
    order_id,
    purchase_revenue
  FROM `bigquery-457902.ga4_ops_bi.core_f_orders`
  WHERE anonymous_id IS NOT NULL
),
segment_weekly AS (
  SELECT
    u.week_start,
    DATE_ADD(u.week_start, INTERVAL 6 DAY) AS week_end,
    u.active_user_segment,
    LOGICAL_OR(u.is_warmup_week) AS is_warmup_week,
    COUNT(DISTINCT u.anonymous_id) AS wau,
    COUNT(DISTINCT o.anonymous_id) AS buyer_users,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(COALESCE(o.purchase_revenue, 0)), 2) AS weekly_revenue
  FROM classified_active_users u
  LEFT JOIN weekly_orders o
    ON u.week_start = o.week_start
    AND u.anonymous_id = o.anonymous_id
  GROUP BY
    u.week_start,
    week_end,
    u.active_user_segment
),
overall_weekly AS (
  SELECT
    week_start,
    week_end,
    'ALL' AS active_user_segment,
    LOGICAL_OR(is_warmup_week) AS is_warmup_week,
    SUM(wau) AS wau,
    SUM(buyer_users) AS buyer_users,
    SUM(orders) AS orders,
    ROUND(SUM(weekly_revenue), 2) AS weekly_revenue
  FROM segment_weekly
  GROUP BY
    week_start,
    week_end
),
combined AS (
  SELECT * FROM overall_weekly
  UNION ALL
  SELECT * FROM segment_weekly
)
SELECT
  week_start,
  week_end,
  active_user_segment,
  is_warmup_week,
  wau,
  buyer_users,
  orders,
  weekly_revenue,
  ROUND(SAFE_DIVIDE(buyer_users, wau), 4) AS weekly_buyer_cvr,
  ROUND(SAFE_DIVIDE(weekly_revenue, buyer_users), 2) AS arppu,
  ROUND(SAFE_DIVIDE(weekly_revenue, wau), 4) AS arpu,
  ROUND(SAFE_DIVIDE(orders, buyer_users), 2) AS orders_per_buyer
FROM combined
ORDER BY
  week_start,
  CASE active_user_segment
    WHEN 'ALL' THEN 0
    WHEN 'NAU' THEN 1
    WHEN 'EAU' THEN 2
    WHEN 'RAU' THEN 3
    ELSE 4
  END;
