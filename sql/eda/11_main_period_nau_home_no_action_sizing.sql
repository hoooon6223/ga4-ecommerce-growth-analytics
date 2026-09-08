-- Main-period NAU homepage no-action sizing.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
--
-- Purpose:
--   Quantify how many NAU first sessions are excluded from Qualified NAU
--   funnel/context deep dives after defining homepage no-action sessions.
--
-- Homepage No-action First Session:
--   NAU user-week first session
--   AND landing_path = '/'
--   AND page_view_count <= 1
--   AND no view_item/select_item/add_to_cart/begin_checkout/purchase/search/scroll

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    COALESCE(NULLIF(REGEXP_EXTRACT(landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    page_view_count,
    has_view_item,
    has_select_item,
    has_add_to_cart,
    has_begin_checkout,
    has_purchase,
    has_search,
    has_scroll
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
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
target_user_weeks AS (
  SELECT *
  FROM classified_active_users
  WHERE week_start BETWEEN DATE '2020-11-23' AND DATE '2020-12-14'
    AND active_user_segment = 'NAU'
),
segment_first_sessions AS (
  SELECT
    s.*,
    u.active_user_segment,
    ROW_NUMBER() OVER (
      PARTITION BY s.week_start, s.anonymous_id
      ORDER BY s.session_start_at, s.session_id
    ) AS session_rank
  FROM session_base s
  INNER JOIN target_user_weeks u
    ON s.week_start = u.week_start
    AND s.anonymous_id = u.anonymous_id
),
target_sessions AS (
  SELECT
    *,
    landing_path = '/'
      AND page_view_count <= 1
      AND NOT has_view_item
      AND NOT has_select_item
      AND NOT has_add_to_cart
      AND NOT has_begin_checkout
      AND NOT has_purchase
      AND NOT has_search
      AND NOT has_scroll AS is_home_no_action
  FROM segment_first_sessions
  WHERE session_rank = 1
),
weekly AS (
  SELECT
    'weekly' AS aggregation_level,
    week_start,
    DATE_ADD(week_start, INTERVAL 6 DAY) AS week_end,
    COUNT(*) AS nau_first_sessions,
    COUNTIF(is_home_no_action) AS home_no_action_sessions,
    COUNTIF(NOT is_home_no_action) AS qualified_nau_first_sessions
  FROM target_sessions
  GROUP BY
    week_start,
    week_end
),
main_period_total AS (
  SELECT
    'main_period_total' AS aggregation_level,
    CAST(NULL AS DATE) AS week_start,
    CAST(NULL AS DATE) AS week_end,
    COUNT(*) AS nau_first_sessions,
    COUNTIF(is_home_no_action) AS home_no_action_sessions,
    COUNTIF(NOT is_home_no_action) AS qualified_nau_first_sessions
  FROM target_sessions
),
combined AS (
  SELECT * FROM main_period_total
  UNION ALL
  SELECT * FROM weekly
)
SELECT
  aggregation_level,
  week_start,
  week_end,
  nau_first_sessions,
  home_no_action_sessions,
  qualified_nau_first_sessions,
  ROUND(SAFE_DIVIDE(home_no_action_sessions, nau_first_sessions), 4) AS home_no_action_share
FROM combined
ORDER BY
  CASE aggregation_level
    WHEN 'main_period_total' THEN 0
    ELSE 1
  END,
  week_start;
