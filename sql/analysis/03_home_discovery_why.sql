-- Final analysis SQL 03: WHY diagnostics for the Home discovery bottleneck.
--
-- Purpose:
--   Reproduce the competing WHY checks used in
--   docs/analysis_notes/03_home_discovery_why_hypothesis.md.

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    COALESCE(traffic_source, '(not set)') AS traffic_source,
    COALESCE(traffic_medium, '(not set)') AS traffic_medium,
    COALESCE(device_category, '(not set)') AS device_category,
    COALESCE(NULLIF(REGEXP_EXTRACT(landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    landing_page_title,
    page_view_count,
    session_duration_sec,
    max_percent_scrolled,
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
event_rollup AS (
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
    COUNTIF(e.event_name = 'scroll') AS scroll_events,
    COUNTIF(e.event_name = 'user_engagement') AS user_engagement_events,
    COUNTIF(e.event_name = 'view_promotion') AS view_promotion_events,
    COUNTIF(e.event_name = 'select_promotion') AS select_promotion_events
  FROM home_first_sessions h
  LEFT JOIN event_paths e
    USING (session_id)
  GROUP BY
    h.week_start,
    h.session_id,
    h.anonymous_id,
    h.session_start_at,
    h.traffic_source,
    h.traffic_medium,
    h.device_category,
    h.landing_path,
    h.landing_page_title,
    h.page_view_count,
    h.session_duration_sec,
    h.max_percent_scrolled,
    h.has_view_item,
    h.has_select_item,
    h.has_add_to_cart,
    h.has_begin_checkout,
    h.has_purchase,
    h.has_search,
    h.has_scroll,
    h.source_medium,
    h.session_rank
),
classified AS (
  SELECT
    *,
    view_item_seq IS NOT NULL AS reached_view_item,
    item_list_seq IS NOT NULL AS reached_item_list,
    search_seq IS NOT NULL AS used_search,
    other_page_seq IS NOT NULL AS moved_to_other_page,
    view_promotion_events > 0 AS has_view_promotion,
    select_promotion_events > 0 AS has_select_promotion,
    (
      view_item_seq IS NULL
      AND item_list_seq IS NULL
      AND search_seq IS NULL
      AND other_page_seq IS NULL
      AND page_view_count <= 1
      AND scroll_events = 0
    ) AS is_home_no_exploration
  FROM event_rollup
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
      WHEN item_list_seq IS NOT NULL AND view_item_seq IS NOT NULL AND item_list_seq < view_item_seq
        THEN 'item_list_before_view_item'
      WHEN view_item_seq IS NOT NULL
        THEN 'view_item_without_prior_item_list'
      WHEN item_list_seq IS NOT NULL
        THEN 'item_list_no_view_item'
      ELSE 'home_or_other_exploration_no_view_item'
    END AS route_group
  FROM qualified_home
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
  WHERE route_group = 'home_or_other_exploration_no_view_item'
),
first_other_page AS (
  SELECT
    h.session_id,
    ARRAY_AGG(e.page_path IGNORE NULLS ORDER BY e.event_seq LIMIT 1)[SAFE_OFFSET(0)] AS first_other_page_path
  FROM home_exploration_no_view h
  LEFT JOIN event_paths e
    ON h.session_id = e.session_id
    AND e.event_name = 'page_view'
    AND NOT (e.page_path IN ('/', '/store.html'))
    AND NOT REGEXP_CONTAINS(e.page_path, r'^/Google\+Redesign/')
  GROUP BY
    h.session_id
),
event_sequence AS (
  SELECT
    h.session_id,
    STRING_AGG(
      CASE
        WHEN e.event_name = 'page_view' AND e.page_path IN ('/', '/store.html') THEN 'home_pageview'
        WHEN e.event_name = 'page_view' THEN 'other_pageview'
        WHEN e.event_name IN ('scroll', 'user_engagement', 'view_promotion', 'select_promotion') THEN e.event_name
        ELSE 'other_event'
      END,
      ' -> '
      ORDER BY e.event_seq
      LIMIT 6
    ) AS first_event_pattern
  FROM home_exploration_no_view h
  INNER JOIN event_paths e
    ON h.session_id = e.session_id
  GROUP BY
    h.session_id
),
promotion_behavior AS (
  SELECT
    *,
    CASE
      WHEN has_select_promotion THEN 'promotion selected'
      WHEN has_view_promotion THEN 'promotion view, no select'
      ELSE 'no promotion view'
    END AS promotion_behavior_group
  FROM classified
),
source_device_check AS (
  SELECT
    'device_category' AS segment_type,
    device_category AS segment_value,
    COUNT(*) AS sessions,
    APPROX_QUANTILES(session_duration_sec, 100)[OFFSET(50)] AS p50_sec,
    ROUND(AVG(page_view_count), 2) AS avg_page_views,
    APPROX_QUANTILES(max_percent_scrolled, 100)[OFFSET(50)] AS p50_scroll
  FROM home_exploration_no_view
  GROUP BY
    segment_value

  UNION ALL

  SELECT
    'source_medium',
    source_medium,
    COUNT(*),
    APPROX_QUANTILES(session_duration_sec, 100)[OFFSET(50)],
    ROUND(AVG(page_view_count), 2),
    APPROX_QUANTILES(max_percent_scrolled, 100)[OFFSET(50)]
  FROM home_exploration_no_view
  WHERE source_medium IN ('google / organic', 'direct / none')
  GROUP BY
    source_medium
),
home_exploration_detail_metrics AS (
  SELECT
    detail_bucket,
    COUNT(*) AS sessions,
    APPROX_QUANTILES(session_duration_sec, 100)[OFFSET(50)] AS p50_sec,
    ROUND(AVG(page_view_count), 2) AS avg_page_views,
    APPROX_QUANTILES(max_percent_scrolled, 100)[OFFSET(50)] AS p50_scroll
  FROM home_exploration_no_view
  GROUP BY
    detail_bucket
),
home_exploration_detail_scored AS (
  SELECT
    detail_bucket,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share,
    p50_sec,
    avg_page_views,
    p50_scroll
  FROM home_exploration_detail_metrics
),
first_other_page_metrics AS (
  SELECT
    first_other_page_path,
    COUNT(*) AS sessions
  FROM first_other_page
  WHERE first_other_page_path IS NOT NULL
  GROUP BY
    first_other_page_path
),
first_other_page_scored AS (
  SELECT
    first_other_page_path,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share
  FROM first_other_page_metrics
),
event_count_metrics AS (
  SELECT 'page_view' AS event_name, COUNTIF(event_page_view_count > 0) AS sessions FROM home_exploration_no_view
  UNION ALL
  SELECT 'scroll', COUNTIF(scroll_events > 0) FROM home_exploration_no_view
  UNION ALL
  SELECT 'user_engagement', COUNTIF(user_engagement_events > 0) FROM home_exploration_no_view
  UNION ALL
  SELECT 'view_promotion', COUNTIF(view_promotion_events > 0) FROM home_exploration_no_view
  UNION ALL
  SELECT 'select_promotion', COUNTIF(select_promotion_events > 0) FROM home_exploration_no_view
),
event_count_scored AS (
  SELECT
    event_name,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, (SELECT COUNT(*) FROM home_exploration_no_view)), 4) AS session_share
  FROM event_count_metrics
),
event_pattern_metrics AS (
  SELECT
    first_event_pattern,
    COUNT(*) AS sessions
  FROM event_sequence
  GROUP BY
    first_event_pattern
),
event_pattern_scored AS (
  SELECT
    first_event_pattern,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share
  FROM event_pattern_metrics
),
promotion_behavior_metrics AS (
  SELECT
    promotion_behavior_group,
    COUNT(*) AS sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_item_list), COUNT(*)), 4) AS item_list_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_view_item), COUNT(*)), 4) AS view_item_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(has_purchase), COUNT(*)), 4) AS purchase_rate
  FROM promotion_behavior
  GROUP BY
    promotion_behavior_group
),
promotion_behavior_scored AS (
  SELECT
    promotion_behavior_group,
    sessions,
    ROUND(SAFE_DIVIDE(sessions, SUM(sessions) OVER ()), 4) AS share_of_home_landing,
    item_list_rate,
    view_item_rate,
    purchase_rate
  FROM promotion_behavior_metrics
)
SELECT
  'source_device_check' AS section,
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    segment_type,
    segment_value,
    sessions,
    p50_sec,
    avg_page_views,
    p50_scroll
  ) ORDER BY segment_type, sessions DESC)) AS result
FROM source_device_check

UNION ALL

SELECT
  'home_exploration_no_view_detail',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    detail_bucket,
    sessions,
    share,
    p50_sec,
    avg_page_views,
    p50_scroll
  ) ORDER BY sessions DESC))
FROM home_exploration_detail_scored

UNION ALL

SELECT
  'first_other_page',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    first_other_page_path,
    sessions,
    share
  ) ORDER BY sessions DESC))
FROM first_other_page_scored

UNION ALL

SELECT
  'event_counts_in_home_exploration_no_view',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    event_name,
    sessions,
    session_share
  ) ORDER BY sessions DESC))
FROM event_count_scored

UNION ALL

SELECT
  'first_event_patterns',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    first_event_pattern,
    sessions,
    share
  ) ORDER BY sessions DESC LIMIT 10))
FROM event_pattern_scored

UNION ALL

SELECT
  'promotion_behavior_outcomes',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    promotion_behavior_group,
    sessions,
    share_of_home_landing,
    item_list_rate,
    view_item_rate,
    purchase_rate
  ) ORDER BY sessions DESC))
FROM promotion_behavior_scored;
