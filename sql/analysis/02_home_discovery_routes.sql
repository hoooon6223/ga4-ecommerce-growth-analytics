-- Final analysis SQL 02: Home landing discovery route diagnostics.
--
-- Purpose:
--   Reproduce Home Landing baseline, Qualified Home Landing population, search
--   routes, and MECE Home -> View Item route segments used in
--   docs/analysis_notes/02_home_discovery_funnel.md.

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    COALESCE(NULLIF(REGEXP_EXTRACT(landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    landing_page_title,
    page_view_count,
    session_duration_sec,
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
    ROW_NUMBER() OVER (
      PARTITION BY s.week_start, s.anonymous_id
      ORDER BY s.session_start_at, s.session_id
    ) AS session_rank
  FROM session_base s
  INNER JOIN nau_user_weeks u
    ON s.week_start = u.week_start
    AND s.anonymous_id = u.anonymous_id
),
home_first_sessions AS (
  SELECT *
  FROM nau_first_sessions
  WHERE session_rank = 1
    AND (
      landing_path IN ('/', '/store.html')
      OR landing_page_title IN ('Home', 'Google Online Store')
    )
),
event_paths AS (
  SELECT
    session_id,
    event_seq,
    event_name,
    COALESCE(NULLIF(REGEXP_EXTRACT(page_location, r'^https?://[^/]+([^?#]*)'), ''), '/') AS page_path
  FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide`
),
session_steps AS (
  SELECT
    h.*,
    MIN(IF(e.event_name = 'view_item', e.event_seq, NULL)) AS view_item_seq,
    MIN(IF(e.event_name = 'view_search_results', e.event_seq, NULL)) AS search_seq,
    MIN(IF(e.event_name = 'page_view' AND REGEXP_CONTAINS(e.page_path, r'^/Google\+Redesign/'), e.event_seq, NULL)) AS item_list_seq,
    MIN(IF(
      e.event_name = 'page_view'
      AND NOT (e.page_path IN ('/', '/store.html'))
      AND NOT REGEXP_CONTAINS(e.page_path, r'^/Google\+Redesign/'),
      e.event_seq,
      NULL
    )) AS other_page_seq,
    COUNTIF(e.event_name = 'page_view') AS event_page_view_count,
    COUNTIF(e.event_name = 'scroll') AS scroll_events
  FROM home_first_sessions h
  LEFT JOIN event_paths e
    USING (session_id)
  GROUP BY
    h.week_start,
    h.session_id,
    h.anonymous_id,
    h.session_start_at,
    h.landing_path,
    h.landing_page_title,
    h.page_view_count,
    h.session_duration_sec,
    h.has_view_item,
    h.has_select_item,
    h.has_add_to_cart,
    h.has_begin_checkout,
    h.has_purchase,
    h.has_search,
    h.has_scroll,
    h.session_rank
),
classified AS (
  SELECT
    *,
    view_item_seq IS NOT NULL AS reached_view_item,
    item_list_seq IS NOT NULL AS reached_item_list,
    search_seq IS NOT NULL AS used_search,
    other_page_seq IS NOT NULL AS moved_to_other_page,
    (
      view_item_seq IS NULL
      AND item_list_seq IS NULL
      AND search_seq IS NULL
      AND other_page_seq IS NULL
      AND page_view_count <= 1
      AND scroll_events = 0
    ) AS is_home_no_exploration
  FROM session_steps
),
qualified_home AS (
  SELECT *
  FROM classified
  WHERE NOT is_home_no_exploration
),
route_segments AS (
  SELECT
    *,
    CASE
      WHEN item_list_seq IS NOT NULL
        AND search_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND item_list_seq < search_seq
        AND search_seq < view_item_seq
        THEN 'item_list -> search -> view_item'
      WHEN search_seq IS NOT NULL
        AND item_list_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND search_seq < item_list_seq
        AND item_list_seq < view_item_seq
        THEN 'search -> item_list -> view_item'
      WHEN item_list_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND item_list_seq < view_item_seq
        THEN 'item_list only -> view_item'
      WHEN search_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND search_seq < view_item_seq
        THEN 'search only -> view_item'
      WHEN view_item_seq IS NOT NULL
        AND (item_list_seq IS NULL OR item_list_seq > view_item_seq)
        AND (search_seq IS NULL OR search_seq > view_item_seq)
        AND (other_page_seq IS NULL OR other_page_seq > view_item_seq)
        THEN 'direct/unknown -> view_item'
      WHEN other_page_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND other_page_seq < view_item_seq
        THEN 'other page -> view_item'
      WHEN item_list_seq IS NOT NULL
        AND search_seq IS NOT NULL
        AND view_item_seq IS NULL
        THEN 'item_list + search -> no view_item'
      WHEN item_list_seq IS NOT NULL
        AND view_item_seq IS NULL
        THEN 'item_list only -> no view_item'
      WHEN search_seq IS NOT NULL
        AND view_item_seq IS NULL
        THEN 'search only -> no view_item'
      ELSE 'home/other exploration -> no view_item'
    END AS route_segment
  FROM qualified_home
),
search_routes AS (
  SELECT
    CASE
      WHEN item_list_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND item_list_seq < search_seq
        AND search_seq < view_item_seq
        THEN 'item_list -> search -> view_item'
      WHEN search_seq IS NOT NULL
        AND item_list_seq IS NOT NULL
        AND view_item_seq IS NOT NULL
        AND search_seq < item_list_seq
        AND item_list_seq < view_item_seq
        THEN 'search -> item_list -> view_item'
      WHEN view_item_seq IS NOT NULL
        AND (item_list_seq IS NULL OR item_list_seq > view_item_seq)
        THEN 'search -> view_item, no item_list before view'
      ELSE 'search -> no view_item'
    END AS search_route,
    COUNT(*) AS sessions
  FROM classified
  WHERE search_seq IS NOT NULL
  GROUP BY
    search_route
),
home_exploration_no_view AS (
  SELECT
    *,
    CASE
      WHEN moved_to_other_page THEN 'moved_to_other_non_item_page'
      WHEN event_page_view_count > 1 THEN 'home_reloaded_or_store_home_only'
      WHEN scroll_events > 0 THEN 'scroll_only_on_home'
      ELSE 'other_event_pattern'
    END AS detail_bucket
  FROM route_segments
  WHERE route_segment = 'home/other exploration -> no view_item'
),
home_landing_baseline AS (
  SELECT
    COUNT(*) AS home_landing_total,
    COUNTIF(reached_item_list) AS reached_item_list,
    COUNTIF(used_search) AS used_search,
    COUNTIF(reached_view_item) AS reached_view_item,
    COUNTIF(has_add_to_cart) AS reached_cart_after_view_item
  FROM classified
),
qualified_home_population AS (
  SELECT
    COUNT(*) AS home_landing_total,
    COUNTIF(is_home_no_exploration) AS home_no_exploration_sessions,
    COUNTIF(NOT is_home_no_exploration) AS qualified_home_landing_sessions
  FROM classified
),
search_routes_scored AS (
  SELECT
    search_route,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share_of_search_sessions
  FROM search_routes
),
route_segment_metrics AS (
  SELECT
    route_segment,
    COUNT(*) AS sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM route_segments
  GROUP BY
    route_segment
),
route_segment_scored AS (
  SELECT
    route_segment,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share_of_qualified_home,
    purchase_sessions,
    ROUND(SAFE_DIVIDE(purchase_sessions, sessions), 4) AS purchase_rate
  FROM route_segment_metrics
),
home_exploration_detail_metrics AS (
  SELECT
    detail_bucket,
    COUNT(*) AS sessions
  FROM home_exploration_no_view
  GROUP BY
    detail_bucket
),
home_exploration_detail_scored AS (
  SELECT
    detail_bucket,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share
  FROM home_exploration_detail_metrics
)
SELECT
  'home_landing_baseline' AS section,
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    home_landing_total,
    reached_item_list,
    used_search,
    reached_view_item,
    reached_cart_after_view_item
  ))) AS result
FROM home_landing_baseline

UNION ALL

SELECT
  'qualified_home_population',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    home_landing_total,
    home_no_exploration_sessions,
    qualified_home_landing_sessions
  )))
FROM qualified_home_population

UNION ALL

SELECT
  'search_routes',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    search_route,
    sessions,
    share_of_search_sessions
  ) ORDER BY sessions DESC))
FROM search_routes_scored

UNION ALL

SELECT
  'home_to_view_item_route_segments',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    route_segment,
    sessions,
    share_of_qualified_home,
    purchase_sessions,
    purchase_rate
  ) ORDER BY sessions DESC))
FROM route_segment_scored

UNION ALL

SELECT
  'home_exploration_no_view_detail',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    detail_bucket,
    sessions,
    share
  ) ORDER BY sessions DESC))
FROM home_exploration_detail_scored;
