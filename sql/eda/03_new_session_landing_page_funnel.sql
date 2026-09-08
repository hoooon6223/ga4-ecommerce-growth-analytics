-- New session landing page funnel reach EDA.
--
-- Operational definition:
--   New Session = ga_session_number = 1
--   Landing Page = first page_location where entrances = 1, materialized in core_f_sessions
--   Landing Page Type = analyst-defined page grouping based on landing_path and landing_page_title
--   Funnel Reach = whether each funnel event occurred at least once in the session
--
-- Notes:
--   This is not a sequential funnel because event order is not enforced.
--   Landing page type is a heuristic grouping for EDA, not a source-system field.

WITH new_sessions AS (
  SELECT
    session_id,
    traffic_source,
    traffic_medium,
    COALESCE(NULLIF(REGEXP_EXTRACT(landing_page, r'^https?://[^/]+([^?#]*)'), ''), '/') AS landing_path,
    landing_page_title,
    has_view_item,
    has_add_to_cart,
    has_begin_checkout,
    has_purchase,
    session_purchase_revenue
  FROM `bigquery-457902.ga4_ops_bi.core_f_sessions`
  WHERE ga_session_number = 1
),
classified_sessions AS (
  SELECT
    *,
    CASE
      WHEN landing_path IN ('/', '/store.html')
        OR landing_page_title = 'Home'
        THEN 'home'
      WHEN landing_page_title = 'Page Unavailable'
        THEN 'unavailable'
      WHEN REGEXP_CONTAINS(LOWER(landing_path), r'(basket|cart|checkout|signin|login)')
        THEN 'cart_or_account'
      WHEN REGEXP_CONTAINS(LOWER(landing_path), r'(store-policies|frequently-asked-questions|faq)')
        THEN 'support_or_policy'
      WHEN landing_page_title IS NOT NULL
        AND REGEXP_CONTAINS(landing_page_title, r'\| Google Merchandise Store$')
        THEN 'category_or_collection'
      WHEN landing_page_title IS NOT NULL
        THEN 'product_detail'
      ELSE 'other'
    END AS landing_page_type,
    traffic_source = 'google' AND traffic_medium = 'organic' AS is_google_organic
  FROM new_sessions
),
segmented_sessions AS (
  SELECT
    'all_new_session' AS analysis_segment,
    *
  FROM classified_sessions

  UNION ALL

  SELECT
    'google_organic_new_session' AS analysis_segment,
    *
  FROM classified_sessions
  WHERE is_google_organic
),
landing_type_rollup AS (
  SELECT
    analysis_segment,
    landing_page_type,
    COUNT(*) AS new_sessions,
    COUNTIF(has_view_item) AS view_item_sessions,
    COUNTIF(has_add_to_cart) AS add_to_cart_sessions,
    COUNTIF(has_begin_checkout) AS begin_checkout_sessions,
    COUNTIF(has_purchase) AS purchase_sessions,
    ROUND(SUM(session_purchase_revenue), 2) AS revenue
  FROM segmented_sessions
  GROUP BY
    analysis_segment,
    landing_page_type
)
SELECT
  analysis_segment,
  landing_page_type,
  new_sessions,
  ROUND(SAFE_DIVIDE(new_sessions, SUM(new_sessions) OVER (PARTITION BY analysis_segment)), 4) AS segment_session_share,
  view_item_sessions,
  add_to_cart_sessions,
  begin_checkout_sessions,
  purchase_sessions,
  ROUND(SAFE_DIVIDE(view_item_sessions, new_sessions), 4) AS view_item_reach_rate,
  ROUND(SAFE_DIVIDE(add_to_cart_sessions, new_sessions), 4) AS add_to_cart_reach_rate,
  ROUND(SAFE_DIVIDE(begin_checkout_sessions, new_sessions), 4) AS checkout_reach_rate,
  ROUND(SAFE_DIVIDE(purchase_sessions, new_sessions), 4) AS purchase_reach_rate,
  revenue,
  ROUND(SAFE_DIVIDE(revenue, new_sessions), 4) AS revenue_per_session
FROM landing_type_rollup
WHERE new_sessions >= 100
ORDER BY
  CASE analysis_segment
    WHEN 'all_new_session' THEN 1
    WHEN 'google_organic_new_session' THEN 2
    ELSE 3
  END,
  new_sessions DESC;
