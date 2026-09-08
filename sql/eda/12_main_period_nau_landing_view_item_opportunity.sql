-- Main-period Qualified NAU landing-level View Item opportunity EDA.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
--
-- Population:
--   Qualified NAU user-weeks in the main analysis period.
--   Homepage no-action first sessions are excluded after NAU is selected as
--   the target cohort for deep dive.
--
-- Question:
--   Which landing paths have both meaningful volume and low View Item Reach
--   compared with the home landing benchmark in the same source/medium?
--
-- Interpretation:
--   The benchmark gap is descriptive, not causal. It is used to prioritize
--   landing/page contexts that deserve further inspection or experiment design.

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    COALESCE(traffic_source, '(not set)') AS traffic_source,
    COALESCE(traffic_medium, '(not set)') AS traffic_medium,
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
    MIN(week_start) OVER (PARTITION BY anonymous_id) AS first_active_week
  FROM weekly_active_users
),
nau_user_weeks AS (
  SELECT
    week_start,
    anonymous_id
  FROM user_week_history
  WHERE first_active_week = week_start
    AND week_start BETWEEN DATE '2020-11-23' AND DATE '2020-12-14'
),
nau_first_sessions AS (
  SELECT
    s.*,
    CONCAT(s.traffic_source, ' / ', s.traffic_medium) AS source_medium,
    ROW_NUMBER() OVER (
      PARTITION BY s.week_start, s.anonymous_id
      ORDER BY s.session_start_at, s.session_id
    ) AS session_rank
  FROM session_base s
  INNER JOIN nau_user_weeks u
    ON s.week_start = u.week_start
    AND s.anonymous_id = u.anonymous_id
),
qualified_sessions AS (
  SELECT *
  FROM nau_first_sessions
  WHERE session_rank = 1
    AND NOT (
      landing_path = '/'
      AND page_view_count <= 1
      AND NOT has_view_item
      AND NOT has_select_item
      AND NOT has_add_to_cart
      AND NOT has_begin_checkout
      AND NOT has_purchase
      AND NOT has_search
      AND NOT has_scroll
    )
),
landing_metrics AS (
  SELECT
    source_medium,
    landing_path,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(has_view_item), COUNT(*)), 4) AS view_item_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS first_session_purchase_rate
  FROM qualified_sessions
  GROUP BY
    source_medium,
    landing_path
),
source_home_benchmark AS (
  SELECT
    source_medium,
    view_item_reach_rate AS home_view_item_reach_rate
  FROM landing_metrics
  WHERE landing_path = '/'
),
scored AS (
  SELECT
    m.source_medium,
    m.landing_path,
    m.first_sessions,
    m.view_item_sessions,
    m.purchase_sessions,
    m.view_item_reach_rate,
    m.first_session_purchase_rate,
    b.home_view_item_reach_rate,
    ROUND(b.home_view_item_reach_rate - m.view_item_reach_rate, 4) AS view_item_reach_gap_vs_home,
    ROUND((b.home_view_item_reach_rate - m.view_item_reach_rate) * m.first_sessions, 1) AS expected_view_item_gap_sessions_vs_home
  FROM landing_metrics m
  INNER JOIN source_home_benchmark b
    USING (source_medium)
  WHERE m.landing_path != '/'
    AND m.first_sessions >= 200
)
SELECT *
FROM scored
ORDER BY
  expected_view_item_gap_sessions_vs_home DESC,
  first_sessions DESC;
