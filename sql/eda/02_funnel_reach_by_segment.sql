-- Funnel reach EDA by segment.
--
-- Operational definition:
--   Funnel Reach = whether each funnel event occurred at least once in a session.
--   This is not a sequential funnel because event order is not enforced.
--
-- Funnel steps:
--   Session -> View Item -> Add to Cart -> Begin Checkout -> Purchase

WITH sessions AS (
  SELECT
    session_id,
    CASE
      WHEN ga_session_number = 1 THEN 'new_session'
      WHEN ga_session_number > 1 THEN 'returning_session'
      ELSE 'unknown'
    END AS session_type,
    traffic_source,
    traffic_medium,
    has_view_item,
    has_add_to_cart,
    has_begin_checkout,
    has_purchase
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
),
segmented_sessions AS (
  SELECT
    'all_new_session' AS analysis_segment,
    *
  FROM sessions
  WHERE session_type = 'new_session'

  UNION ALL

  SELECT
    'google_organic_new_session' AS analysis_segment,
    *
  FROM sessions
  WHERE session_type = 'new_session'
    AND traffic_source = 'google'
    AND traffic_medium = 'organic'

  UNION ALL

  SELECT
    'all_returning_session' AS analysis_segment,
    *
  FROM sessions
  WHERE session_type = 'returning_session'
),
segment_rollup AS (
  SELECT
    analysis_segment,
    COUNT(*) AS sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions
  FROM segmented_sessions
  GROUP BY analysis_segment
)
SELECT
  analysis_segment,
  sessions,
  view_item_sessions,
  add_to_cart_sessions,
  begin_checkout_sessions,
  purchase_sessions,
  ROUND(SAFE_DIVIDE(view_item_sessions, sessions), 4) AS view_item_reach_rate,
  ROUND(SAFE_DIVIDE(add_to_cart_sessions, sessions), 4) AS add_to_cart_reach_rate,
  ROUND(SAFE_DIVIDE(begin_checkout_sessions, sessions), 4) AS checkout_reach_rate,
  ROUND(SAFE_DIVIDE(purchase_sessions, sessions), 4) AS purchase_reach_rate
FROM segment_rollup
ORDER BY
  CASE analysis_segment
    WHEN 'all_new_session' THEN 1
    WHEN 'google_organic_new_session' THEN 2
    WHEN 'all_returning_session' THEN 3
    ELSE 4
  END;
