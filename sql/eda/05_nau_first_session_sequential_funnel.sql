-- NAU first-session sequential funnel EDA.
--
-- Status:
--   Historical NAU-only exploration query.
--   Use 08_main_period_segment_week_first_session_sequential_funnel.sql
--   for the current primary funnel definition.
--
-- Operational definition:
--   NAU = observed new active user whose first active week is the current week
--   First Session = the first session in the user's first active week
--   Primary Funnel = Sequential Funnel
--
-- Funnel:
--   Session -> View Item -> Add to Cart -> Begin Checkout -> Purchase
--
-- Notes:
--   anonymous_id is based on GA4 user_pseudo_id, not a backend customer ID.
--   NAU means observed new within the available data window, not necessarily a true first-time customer.
--   The first 4 observed weeks are excluded because prior activity history is insufficient for stable cohort interpretation.

WITH session_base AS (
  SELECT
    DATE_TRUNC(partition_day, WEEK(MONDAY)) AS week_start,
    session_id,
    anonymous_id,
    session_start_at,
    traffic_source,
    traffic_medium,
    landing_page,
    landing_page_title
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
  WHERE anonymous_id IS NOT NULL
),
user_week_activity AS (
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
  FROM user_week_activity
),
observed_weeks AS (
  SELECT
    week_start,
    DENSE_RANK() OVER (ORDER BY week_start) AS observed_week_number
  FROM (
    SELECT DISTINCT week_start
    FROM user_week_activity
  )
),
nau_users AS (
  SELECT
    h.week_start,
    h.anonymous_id
  FROM user_week_history h
  INNER JOIN observed_weeks w
    USING (week_start)
  WHERE h.first_active_week = h.week_start
    AND w.observed_week_number > 4
),
nau_first_sessions AS (
  SELECT
    s.week_start,
    s.anonymous_id,
    s.session_id,
    s.session_start_at,
    s.traffic_source,
    s.traffic_medium,
    COALESCE(NULLIF(REGEXP_EXTRACT(s.landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    s.landing_page_title,
    ROW_NUMBER() OVER (
      PARTITION BY s.anonymous_id
      ORDER BY s.session_start_at, s.session_id
    ) AS session_rank
  FROM session_base s
  INNER JOIN nau_users u
    ON s.week_start = u.week_start
    AND s.anonymous_id = u.anonymous_id
),
target_sessions AS (
  SELECT
    *
  FROM nau_first_sessions
  WHERE session_rank = 1
),
session_event_steps AS (
  SELECT
    t.week_start,
    t.anonymous_id,
    t.session_id,
    t.traffic_source,
    t.traffic_medium,
    t.landing_path,
    t.landing_page_title,
    MIN(IF(e.event_name = 'view_item', e.event_seq, NULL)) AS view_item_seq,
    MIN(IF(e.event_name = 'add_to_cart', e.event_seq, NULL)) AS first_add_to_cart_seq,
    MIN(IF(e.event_name = 'begin_checkout', e.event_seq, NULL)) AS first_begin_checkout_seq,
    MIN(IF(e.event_name = 'purchase', e.event_seq, NULL)) AS first_purchase_seq
  FROM target_sessions t
  LEFT JOIN `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
    USING (session_id)
  GROUP BY
    t.week_start,
    t.anonymous_id,
    t.session_id,
    t.traffic_source,
    t.traffic_medium,
    t.landing_path,
    t.landing_page_title
),
sequential_steps AS (
  SELECT
    *,
    view_item_seq IS NOT NULL AS reached_view_item,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'add_to_cart'
        AND e.event_seq > s.view_item_seq
    ) AS add_to_cart_seq
  FROM session_event_steps s
),
sequential_steps_with_checkout AS (
  SELECT
    *,
    add_to_cart_seq IS NOT NULL AS reached_add_to_cart,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'begin_checkout'
        AND e.event_seq > s.add_to_cart_seq
    ) AS begin_checkout_seq
  FROM sequential_steps s
),
sequential_steps_with_purchase AS (
  SELECT
    *,
    begin_checkout_seq IS NOT NULL AS reached_begin_checkout,
    (
      SELECT MIN(e.event_seq)
      FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide` e
      WHERE e.session_id = s.session_id
        AND e.event_name = 'purchase'
        AND e.event_seq > s.begin_checkout_seq
    ) AS purchase_seq
  FROM sequential_steps_with_checkout s
),
session_funnel_flags AS (
  SELECT
    *,
    purchase_seq IS NOT NULL AS reached_purchase
  FROM sequential_steps_with_purchase
),
overall AS (
  SELECT
    'all_nau_first_session' AS analysis_segment,
    COUNT(*) AS first_sessions,
    COUNTIF(reached_view_item) AS view_item_sessions,
    COUNTIF(reached_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(reached_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(reached_purchase) AS purchase_sessions
  FROM session_funnel_flags
),
by_week AS (
  SELECT
    FORMAT_DATE('%Y-%m-%d', week_start) AS analysis_segment,
    COUNT(*) AS first_sessions,
    COUNTIF(reached_view_item) AS view_item_sessions,
    COUNTIF(reached_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(reached_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(reached_purchase) AS purchase_sessions
  FROM session_funnel_flags
  GROUP BY week_start
)
SELECT
  analysis_segment,
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
FROM overall
UNION ALL
SELECT
  analysis_segment,
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
FROM by_week
ORDER BY
  CASE WHEN analysis_segment = 'all_nau_first_session' THEN 1 ELSE 2 END,
  analysis_segment;
