-- Main-period Qualified NAU first-session front-funnel context EDA.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
--
-- Focus:
--   NAU first-session View Item Reach
--   Homepage no-action first sessions are excluded because this analysis focuses
--   on users with at least minimal exploration intent.
--
-- Question:
--   In which traffic/device/landing/behavior contexts does Qualified NAU
--   first-session View Item Reach look lower or higher?

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    traffic_source,
    traffic_medium,
    device_category,
    landing_page,
    landing_page_title,
    page_view_count,
    session_duration_sec
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
    s.week_start,
    s.anonymous_id,
    s.session_id,
    s.session_start_at,
    COALESCE(s.traffic_source, '(not set)') AS traffic_source,
    COALESCE(s.traffic_medium, '(not set)') AS traffic_medium,
    COALESCE(s.device_category, '(not set)') AS device_category,
    COALESCE(NULLIF(REGEXP_EXTRACT(s.landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    s.landing_page_title,
    s.page_view_count,
    s.session_duration_sec,
    ROW_NUMBER() OVER (
      PARTITION BY s.week_start, s.anonymous_id
      ORDER BY s.session_start_at, s.session_id
    ) AS session_rank
  FROM session_base s
  INNER JOIN nau_user_weeks u
    ON s.week_start = u.week_start
    AND s.anonymous_id = u.anonymous_id
),
target_sessions AS (
  SELECT *
  FROM nau_first_sessions
  WHERE session_rank = 1
),
session_flags AS (
  SELECT
    t.week_start,
    t.anonymous_id,
    t.session_id,
    t.traffic_source,
    t.traffic_medium,
    CONCAT(t.traffic_source, ' / ', t.traffic_medium) AS source_medium,
    t.device_category,
    t.landing_path,
    t.page_view_count,
    t.session_duration_sec,
    CASE
      WHEN t.landing_path = '/' THEN 'home'
      WHEN REGEXP_CONTAINS(t.landing_path, r'(?i)/store|/shop|/collection|/category') THEN 'category_or_collection'
      WHEN REGEXP_CONTAINS(t.landing_path, r'(?i)/product|/item') THEN 'product_detail'
      WHEN t.landing_path IS NULL THEN 'unknown'
      ELSE 'other'
    END AS landing_page_group,
    COUNTIF(e.event_name = 'view_item') > 0 AS has_view_item,
    COUNTIF(e.event_name = 'select_item') > 0 AS has_select_item,
    COUNTIF(e.event_name = 'add_to_cart') > 0 AS has_add_to_cart,
    COUNTIF(e.event_name = 'begin_checkout') > 0 AS has_begin_checkout,
    COUNTIF(e.event_name = 'purchase') > 0 AS has_purchase,
    COUNTIF(e.event_name = 'view_search_results') > 0 AS has_search,
    COUNTIF(e.event_name = 'scroll') > 0 AS has_scroll,
    COUNTIF(e.event_name = 'click') > 0 AS has_click
  FROM target_sessions t
  LEFT JOIN `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
    USING (session_id)
  GROUP BY
    t.week_start,
    t.anonymous_id,
    t.session_id,
    t.traffic_source,
    t.traffic_medium,
    source_medium,
    t.device_category,
    t.landing_path,
    t.page_view_count,
    t.session_duration_sec,
    landing_page_group
),
qualified_sessions AS (
  SELECT *
  FROM session_flags
  WHERE NOT (
    landing_path = '/'
    AND page_view_count <= 1
    AND NOT has_view_item
    AND NOT has_select_item
    AND NOT has_add_to_cart
    AND NOT has_begin_checkout
    AND NOT has_purchase
    AND NOT has_search
    AND NOT has_scroll
    AND NOT has_click
  )
),
segment_metrics AS (
  SELECT
    'source_medium' AS segment_type,
    source_medium AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM qualified_sessions
  GROUP BY segment_value

  UNION ALL

  SELECT
    'device_category' AS segment_type,
    device_category AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM qualified_sessions
  GROUP BY segment_value

  UNION ALL

  SELECT
    'landing_page_group' AS segment_type,
    landing_page_group AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM qualified_sessions
  GROUP BY segment_value

  UNION ALL

  SELECT
    'has_search' AS segment_type,
    CAST(has_search AS STRING) AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM qualified_sessions
  GROUP BY segment_value

  UNION ALL

  SELECT
    'has_scroll' AS segment_type,
    CAST(has_scroll AS STRING) AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM qualified_sessions
  GROUP BY segment_value

  UNION ALL

  SELECT
    'has_click' AS segment_type,
    CAST(has_click AS STRING) AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM qualified_sessions
  GROUP BY segment_value
)
SELECT
  segment_type,
  segment_value,
  first_sessions,
  view_item_sessions,
  add_to_cart_sessions,
  begin_checkout_sessions,
  purchase_sessions,
  ROUND(SAFE_DIVIDE(view_item_sessions, first_sessions), 4) AS view_item_reach_rate,
  ROUND(SAFE_DIVIDE(add_to_cart_sessions, view_item_sessions), 4) AS view_to_cart_rate,
  ROUND(SAFE_DIVIDE(begin_checkout_sessions, add_to_cart_sessions), 4) AS cart_to_checkout_rate,
  ROUND(SAFE_DIVIDE(purchase_sessions, begin_checkout_sessions), 4) AS checkout_to_purchase_rate,
  ROUND(SAFE_DIVIDE(purchase_sessions, first_sessions), 4) AS first_session_purchase_rate
FROM segment_metrics
WHERE first_sessions >= 100
ORDER BY
  segment_type,
  first_sessions DESC;
