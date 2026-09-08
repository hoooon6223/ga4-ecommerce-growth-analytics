-- Main-period segment-week first-session sequential funnel EDA.
--
-- Main analysis period:
--   2020-11-23 to 2020-12-20
--
-- Operational definition:
--   Population = weekly NAU/EAU/RAU active users
--   Observation = each user's first session in that week
--   Primary Funnel = Sequential Funnel
--
-- Funnel:
--   Session -> View Item -> Add to Cart -> Begin Checkout -> Purchase
--
-- Notes:
--   anonymous_id is based on GA4 user_pseudo_id, not a backend customer ID.
--   Segment classification uses all prior observed history, then filters to the main analysis period.

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    traffic_source,
    traffic_medium,
    landing_page,
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
),
segment_week_first_sessions AS (
  SELECT
    s.week_start,
    u.active_user_segment,
    s.anonymous_id,
    s.session_id,
    s.session_start_at,
    s.traffic_source,
    s.traffic_medium,
    COALESCE(NULLIF(REGEXP_EXTRACT(s.landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    s.landing_page_title,
    s.page_view_count,
    s.has_view_item,
    s.has_select_item,
    s.has_add_to_cart,
    s.has_begin_checkout,
    s.has_purchase,
    s.has_search,
    s.has_scroll,
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
  SELECT *
  FROM segment_week_first_sessions
  WHERE session_rank = 1
),
session_view_steps AS (
  SELECT
    t.week_start,
    t.active_user_segment,
    t.anonymous_id,
    t.session_id,
    t.traffic_source,
    t.traffic_medium,
    t.landing_path,
    t.landing_page_title,
    MIN(IF(e.event_name = 'view_item', e.event_seq, NULL)) AS view_item_seq
  FROM target_sessions t
  LEFT JOIN `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
    ON t.session_id = e.session_id
    AND e.event_name = 'view_item'
  GROUP BY
    t.week_start,
    t.active_user_segment,
    t.anonymous_id,
    t.session_id,
    t.traffic_source,
    t.traffic_medium,
    t.landing_path,
    t.landing_page_title
),
session_cart_steps AS (
  SELECT
    s.*,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'add_to_cart'
        AND e.event_seq > s.view_item_seq
    ) AS add_to_cart_seq
  FROM session_view_steps s
),
session_checkout_steps AS (
  SELECT
    s.*,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'begin_checkout'
        AND e.event_seq > s.add_to_cart_seq
    ) AS begin_checkout_seq
  FROM session_cart_steps s
),
session_purchase_steps AS (
  SELECT
    s.*,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'purchase'
        AND e.event_seq > s.begin_checkout_seq
    ) AS purchase_seq
  FROM session_checkout_steps s
),
session_funnel_flags AS (
  SELECT
    *,
    view_item_seq IS NOT NULL AS reached_view_item,
    add_to_cart_seq IS NOT NULL AS reached_add_to_cart,
    begin_checkout_seq IS NOT NULL AS reached_begin_checkout,
    purchase_seq IS NOT NULL AS reached_purchase
  FROM session_purchase_steps
),
overall_by_segment AS (
  SELECT
    'main_period_total' AS aggregation_level,
    CAST(NULL AS DATE) AS week_start,
    CAST(NULL AS DATE) AS week_end,
    active_user_segment,
    COUNT(*) AS first_sessions,
    COUNTIF(reached_view_item) AS view_item_sessions,
    COUNTIF(reached_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(reached_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(reached_purchase) AS purchase_sessions
  FROM session_funnel_flags
  GROUP BY
    active_user_segment
),
weekly_by_segment AS (
  SELECT
    'weekly' AS aggregation_level,
    week_start,
    DATE_ADD(week_start, INTERVAL 6 DAY) AS week_end,
    active_user_segment,
    COUNT(*) AS first_sessions,
    COUNTIF(reached_view_item) AS view_item_sessions,
    COUNTIF(reached_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(reached_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(reached_purchase) AS purchase_sessions
  FROM session_funnel_flags
  GROUP BY
    week_start,
    week_end,
    active_user_segment
),
combined AS (
  SELECT * FROM overall_by_segment
  UNION ALL
  SELECT * FROM weekly_by_segment
)
SELECT
  aggregation_level,
  week_start,
  week_end,
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
  ROUND(SAFE_DIVIDE(purchase_sessions, first_sessions), 4) AS overall_funnel_cvr
FROM combined
ORDER BY
  CASE aggregation_level
    WHEN 'main_period_total' THEN 0
    ELSE 1
  END,
  week_start,
  CASE active_user_segment
    WHEN 'NAU' THEN 1
    WHEN 'EAU' THEN 2
    WHEN 'RAU' THEN 3
    ELSE 4
  END;
