-- Main-period Qualified NAU first-session funnel by source/medium and landing context.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
--
-- Population:
--   Qualified NAU user-weeks in the main analysis period.
--   Homepage no-action first sessions are excluded because this analysis focuses
--   on users with at least minimal exploration intent.
--
-- Observation:
--   The user's first session in that week.
--
-- Metric definitions:
--   First Sessions = NAU user-week first sessions
--   View Item Reach Rate = sessions with at least one view_item / first sessions
--   Sequential Purchase Rate = sessions that complete
--     View Item -> Add to Cart -> Begin Checkout -> Purchase in order / first sessions
--   Source/Medium = traffic_source / traffic_medium from core_f_sessions
--   Landing Path = path extracted from the landing_page URL

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
target_sessions AS (
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
view_steps AS (
  SELECT
    t.week_start,
    t.anonymous_id,
    t.session_id,
    t.source_medium,
    t.device_category,
    t.landing_path,
    t.landing_page_title,
    MIN(IF(e.event_name = 'view_item', e.event_seq, NULL)) AS view_item_seq
  FROM target_sessions t
  LEFT JOIN `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
    ON t.session_id = e.session_id
    AND e.event_name = 'view_item'
  GROUP BY
    t.week_start,
    t.anonymous_id,
    t.session_id,
    t.source_medium,
    t.device_category,
    t.landing_path,
    t.landing_page_title
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
session_flags AS (
  SELECT
    *,
    view_item_seq IS NOT NULL AS reached_view_item,
    add_to_cart_seq IS NOT NULL AS reached_add_to_cart,
    begin_checkout_seq IS NOT NULL AS reached_begin_checkout,
    purchase_seq IS NOT NULL AS reached_purchase
  FROM purchase_steps
),
source_funnel AS (
  SELECT
    'source_funnel' AS analysis_type,
    source_medium AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(reached_view_item) AS view_item_sessions,
    COUNTIF(reached_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(reached_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(reached_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_view_item), COUNT(*)), 4) AS view_item_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_add_to_cart), COUNTIF(reached_view_item)), 4) AS view_to_cart_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_begin_checkout), COUNTIF(reached_add_to_cart)), 4) AS cart_to_checkout_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_purchase), COUNTIF(reached_begin_checkout)), 4) AS checkout_to_purchase_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_purchase), COUNT(*)), 4) AS sequential_purchase_rate
  FROM session_flags
  GROUP BY
    segment_value
),
landing_by_source AS (
  SELECT
    CONCAT('landing_by_source: ', source_medium) AS analysis_type,
    COALESCE(landing_path, '(unknown)') AS segment_value,
    COUNT(*) AS first_sessions,
    COUNTIF(reached_view_item) AS view_item_sessions,
    COUNTIF(reached_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(reached_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(reached_purchase) AS purchase_sessions,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_view_item), COUNT(*)), 4) AS view_item_reach_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_add_to_cart), COUNTIF(reached_view_item)), 4) AS view_to_cart_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_begin_checkout), COUNTIF(reached_add_to_cart)), 4) AS cart_to_checkout_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_purchase), COUNTIF(reached_begin_checkout)), 4) AS checkout_to_purchase_rate,
    ROUND(SAFE_DIVIDE(COUNTIF(reached_purchase), COUNT(*)), 4) AS sequential_purchase_rate
  FROM session_flags
  WHERE source_medium IN (
    'google / organic',
    'direct / none',
    'google / cpc',
    'shop.googlemerchandisestore.com / referral',
    '(not set) / (not set)'
  )
  GROUP BY
    analysis_type,
    segment_value
)
SELECT *
FROM source_funnel
WHERE first_sessions >= 100

UNION ALL

SELECT *
FROM landing_by_source
WHERE first_sessions >= 100

ORDER BY
  analysis_type,
  first_sessions DESC;
