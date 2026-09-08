-- Final analysis SQL 01: revenue decomposition, cohort sizing, and first-session funnel.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
--
-- Purpose:
--   Reproduce the core WHAT/WHO/WHERE results used in
--   docs/analysis_notes/01_revenue_growth_flow.md.
--
-- Output shape:
--   One row per section. Each result column is a JSON array so the script can
--   keep related portfolio outputs in one reproducible query file.

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
  WHERE anonymous_id IS NOT NULL
),
order_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    order_id,
    anonymous_id,
    purchase_revenue
  FROM `bigquery-457902.ga4_ops_bi.core_f_orders`
  WHERE anonymous_id IS NOT NULL
),
weekly_active_users AS (
  SELECT
    week_start,
    anonymous_id
  FROM session_base
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
classified_user_weeks AS (
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
target_user_weeks AS (
  SELECT *
  FROM classified_user_weeks
  WHERE week_start BETWEEN DATE '2020-11-23' AND DATE '2020-12-14'
),
weekly_revenue AS (
  SELECT
    u.week_start,
    DATE_ADD(u.week_start, INTERVAL 6 DAY) AS week_end,
    COUNT(DISTINCT u.anonymous_id) AS wau,
    COUNT(DISTINCT o.anonymous_id) AS weekly_buyer_users,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(COALESCE(o.purchase_revenue, 0)), 2) AS revenue
  FROM target_user_weeks u
  LEFT JOIN order_base o
    ON u.week_start = o.week_start
    AND u.anonymous_id = o.anonymous_id
  GROUP BY
    u.week_start,
    week_end
),
cohort_summary AS (
  SELECT
    u.active_user_segment,
    COUNT(*) AS active_user_weeks,
    COUNT(DISTINCT IF(o.anonymous_id IS NOT NULL, CONCAT(o.anonymous_id, '|', CAST(o.week_start AS STRING)), NULL)) AS buyer_user_weeks,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(COALESCE(o.purchase_revenue, 0)), 2) AS revenue
  FROM target_user_weeks u
  LEFT JOIN order_base o
    ON u.week_start = o.week_start
    AND u.anonymous_id = o.anonymous_id
  GROUP BY
    u.active_user_segment
),
cohort_summary_scored AS (
  SELECT
    active_user_segment,
    active_user_weeks,
    ROUND(SAFE_DIVIDE(active_user_weeks, SUM(active_user_weeks) OVER ()), 4) AS active_user_week_share,
    buyer_user_weeks,
    orders,
    revenue,
    ROUND(SAFE_DIVIDE(buyer_user_weeks, active_user_weeks), 4) AS buyer_cvr,
    ROUND(SAFE_DIVIDE(revenue, buyer_user_weeks), 2) AS arppu
  FROM cohort_summary
),
first_sessions AS (
  SELECT
    s.week_start,
    u.active_user_segment,
    s.anonymous_id,
    s.session_id,
    ROW_NUMBER() OVER (
      PARTITION BY s.week_start, s.anonymous_id
      ORDER BY s.session_start_at, s.session_id
    ) AS session_rank
  FROM session_base s
  INNER JOIN target_user_weeks u
    ON s.week_start = u.week_start
    AND s.anonymous_id = u.anonymous_id
),
target_first_sessions AS (
  SELECT *
  FROM first_sessions
  WHERE session_rank = 1
),
view_steps AS (
  SELECT
    t.week_start,
    t.active_user_segment,
    t.anonymous_id,
    t.session_id,
    MIN(IF(e.event_name = 'view_item', e.event_seq, NULL)) AS view_item_seq
  FROM target_first_sessions t
  LEFT JOIN `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
    ON t.session_id = e.session_id
  GROUP BY
    t.week_start,
    t.active_user_segment,
    t.anonymous_id,
    t.session_id
),
cart_steps AS (
  SELECT
    s.*,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'add_to_cart'
        AND e.event_seq > s.view_item_seq
    ) AS add_to_cart_seq
  FROM view_steps s
),
checkout_steps AS (
  SELECT
    s.*,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'begin_checkout'
        AND e.event_seq > s.add_to_cart_seq
    ) AS begin_checkout_seq
  FROM cart_steps s
),
purchase_steps AS (
  SELECT
    s.*,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'purchase'
        AND e.event_seq > s.begin_checkout_seq
    ) AS purchase_seq
  FROM checkout_steps s
),
first_session_funnel AS (
  SELECT
    active_user_segment,
    COUNT(*) AS first_sessions,
    COUNTIF(view_item_seq IS NOT NULL) AS view_item_sessions,
    COUNTIF(add_to_cart_seq IS NOT NULL) AS add_to_cart_sessions,
    COUNTIF(begin_checkout_seq IS NOT NULL) AS begin_checkout_sessions,
    COUNTIF(purchase_seq IS NOT NULL) AS purchase_sessions
  FROM purchase_steps
  GROUP BY
    active_user_segment
)
SELECT
  'weekly_revenue_decomposition' AS section,
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    week_start,
    week_end,
    revenue AS weekly_revenue,
    wau,
    weekly_buyer_users,
    ROUND(SAFE_DIVIDE(weekly_buyer_users, wau), 4) AS weekly_buyer_cvr,
    ROUND(SAFE_DIVIDE(revenue, weekly_buyer_users), 2) AS arppu
  ) ORDER BY week_start)) AS result
FROM weekly_revenue

UNION ALL

SELECT
  'cohort_summary',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    active_user_segment,
    active_user_weeks,
    active_user_week_share,
    buyer_user_weeks,
    orders,
    revenue,
    buyer_cvr,
    arppu
  ) ORDER BY
    CASE active_user_segment WHEN 'NAU' THEN 1 WHEN 'EAU' THEN 2 WHEN 'RAU' THEN 3 ELSE 4 END
  ))
FROM cohort_summary_scored

UNION ALL

SELECT
  'first_session_sequential_funnel',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    active_user_segment,
    first_sessions,
    view_item_sessions,
    add_to_cart_sessions,
    begin_checkout_sessions,
    purchase_sessions,
    ROUND(SAFE_DIVIDE(view_item_sessions, first_sessions), 4) AS view_item_reach_rate,
    ROUND(SAFE_DIVIDE(add_to_cart_sessions, view_item_sessions), 4) AS view_to_cart_rate,
    ROUND(SAFE_DIVIDE(begin_checkout_sessions, add_to_cart_sessions), 4) AS cart_to_checkout_rate,
    ROUND(SAFE_DIVIDE(purchase_sessions, begin_checkout_sessions), 4) AS checkout_to_purchase_rate,
    ROUND(SAFE_DIVIDE(purchase_sessions, first_sessions), 4) AS funnel_completion_rate
  ) ORDER BY
    CASE active_user_segment WHEN 'NAU' THEN 1 WHEN 'EAU' THEN 2 WHEN 'RAU' THEN 3 ELSE 4 END
  ))
FROM first_session_funnel;
