-- Main-period weekly revenue decomposition EDA.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
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
classified_active_users AS (
  SELECT
    week_start,
    anonymous_id,
    CASE
      WHEN first_active_week = week_start THEN 'NAU'
      WHEN previous_active_week = DATE_SUB(week_start, INTERVAL 1 WEEK) THEN 'EAU'
      ELSE 'RAU'
    END AS active_user_segment
  FROM user_week_history
),
main_period_active_users AS (
  SELECT *
  FROM classified_active_users
  WHERE week_start BETWEEN DATE '2020-11-23' AND DATE '2020-12-14'
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
    COUNT(DISTINCT u.anonymous_id) AS wau,
    COUNT(DISTINCT o.anonymous_id) AS buyer_users,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(COALESCE(o.purchase_revenue, 0)), 2) AS weekly_revenue
  FROM main_period_active_users u
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
