-- Build reusable core marts from source-close base marts.
--
-- Core model:
--   1. core_f_sessions : one row per session
--   2. core_f_orders   : one row per purchase event
--   3. core_d_items    : one row per observed item_id
--
-- These tables contain shared business grains and conservative derived fields.
-- Purpose-specific segmentation or scoring belongs in analysis marts, not here.

CREATE OR REPLACE TABLE `bigquery-457902.ga4_ops_bi.core_f_sessions`
PARTITION BY partition_day AS
WITH session_events AS (
  SELECT
    *
  FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide`
  WHERE session_id IS NOT NULL
),
session_rollup AS (
  SELECT
    session_id,
    ARRAY_AGG(anonymous_id IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS anonymous_id,
    MIN(partition_day) AS partition_day,
    MIN(event_at) AS session_start_at,
    MAX(event_at) AS session_end_at,
    TIMESTAMP_DIFF(MAX(event_at), MIN(event_at), SECOND) AS session_duration_sec,
    ARRAY_AGG(ga_session_id IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS ga_session_id,
    ARRAY_AGG(ga_session_number IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS ga_session_number,
    ARRAY_AGG(user_first_touch_at IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS user_first_touch_at,
    ARRAY_AGG(platform IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS platform,
    ARRAY_AGG(hostname IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS hostname,
    ARRAY_AGG(device_category IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS device_category,
    ARRAY_AGG(operating_system IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS operating_system,
    ARRAY_AGG(browser IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS browser,
    ARRAY_AGG(country IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS country,
    ARRAY_AGG(region IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS region,
    ARRAY_AGG(city IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS city,
    ARRAY_AGG(traffic_source IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS traffic_source,
    ARRAY_AGG(traffic_medium IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS traffic_medium,
    ARRAY_AGG(traffic_campaign IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS traffic_campaign,
    ARRAY_AGG(event_param_source IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS event_param_source,
    ARRAY_AGG(event_param_medium IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS event_param_medium,
    ARRAY_AGG(event_param_campaign IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS event_param_campaign,
    ARRAY_AGG(IF(entrances = 1, page_location, NULL) IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS landing_page,
    ARRAY_AGG(IF(entrances = 1, page_title, NULL) IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS landing_page_title,
    ARRAY_AGG(IF(entrances = 1, page_referrer, NULL) IGNORE NULLS ORDER BY event_seq LIMIT 1)[SAFE_OFFSET(0)] AS landing_page_referrer,
    COUNT(*) AS event_count,
    COUNTIF(event_name = 'page_view') AS page_view_count,
    COUNTIF(event_name = 'view_item') AS view_item_count,
    COUNTIF(event_name = 'select_item') AS select_item_count,
    COUNTIF(event_name = 'add_to_cart') AS add_to_cart_count,
    COUNTIF(event_name = 'begin_checkout') AS begin_checkout_count,
    COUNTIF(event_name = 'purchase') AS purchase_count,
    COUNTIF(event_name = 'view_search_results') AS search_count,
    COUNTIF(event_name = 'scroll') AS scroll_count,
    SUM(COALESCE(engagement_time_msec, 0)) AS engagement_time_msec,
    MAX(percent_scrolled) AS max_percent_scrolled,
    COUNTIF(event_name = 'view_item') > 0 AS has_view_item,
    COUNTIF(event_name = 'select_item') > 0 AS has_select_item,
    COUNTIF(event_name = 'add_to_cart') > 0 AS has_add_to_cart,
    COUNTIF(event_name = 'begin_checkout') > 0 AS has_begin_checkout,
    COUNTIF(event_name = 'purchase') > 0 AS has_purchase,
    COUNTIF(event_name = 'view_search_results') > 0 AS has_search,
    COUNTIF(event_name = 'scroll') > 0 AS has_scroll,
    SUM(IF(event_name = 'purchase', COALESCE(purchase_revenue, 0), 0)) AS session_purchase_revenue,
    SUM(IF(event_name = 'purchase', COALESCE(total_item_quantity, 0), 0)) AS session_total_item_quantity
  FROM session_events
  GROUP BY session_id
)
SELECT
  *
FROM session_rollup;

CREATE OR REPLACE TABLE `bigquery-457902.ga4_ops_bi.core_f_orders`
PARTITION BY partition_day AS
WITH purchase_events AS (
  SELECT
    event_key AS purchase_event_key,
    event_key AS order_id,
    session_id,
    anonymous_id,
    partition_day,
    event_at AS order_event_at,
    transaction_id,
    event_param_transaction_id,
    event_currency AS currency,
    payment_type,
    shipping_tier,
    event_coupon AS order_coupon,
    event_promotion_name AS order_promotion_name,
    purchase_revenue,
    device_category,
    operating_system,
    browser,
    country,
    city,
    traffic_source,
    traffic_medium,
    traffic_campaign
  FROM `bigquery-457902.ga4_ops_bi.base_f_event_wide`
  WHERE event_name = 'purchase'
),
item_rollup AS (
  SELECT
    purchase_event_key,
    SUM(COALESCE(item_revenue, 0)) AS item_revenue,
    SUM(COALESCE(quantity, 0)) AS item_quantity,
    COUNT(*) AS order_item_count,
    COUNT(DISTINCT item_id) AS distinct_item_count,
    COUNT(DISTINCT item_category) AS distinct_category_count
  FROM `bigquery-457902.ga4_ops_bi.base_f_order_items`
  GROUP BY purchase_event_key
)
SELECT
  purchase_events.purchase_event_key,
  purchase_events.order_id,
  purchase_events.session_id,
  purchase_events.anonymous_id,
  purchase_events.partition_day,
  purchase_events.order_event_at,
  purchase_events.transaction_id,
  purchase_events.event_param_transaction_id,
  purchase_events.currency,
  purchase_events.payment_type,
  purchase_events.shipping_tier,
  purchase_events.order_coupon,
  purchase_events.order_promotion_name,
  purchase_events.purchase_revenue,
  COALESCE(item_rollup.item_revenue, 0) AS item_revenue,
  COALESCE(item_rollup.item_quantity, 0) AS item_quantity,
  COALESCE(item_rollup.order_item_count, 0) AS order_item_count,
  COALESCE(item_rollup.distinct_item_count, 0) AS distinct_item_count,
  COALESCE(item_rollup.distinct_category_count, 0) AS distinct_category_count,
  purchase_events.device_category,
  purchase_events.operating_system,
  purchase_events.browser,
  purchase_events.country,
  purchase_events.city,
  purchase_events.traffic_source,
  purchase_events.traffic_medium,
  purchase_events.traffic_campaign
FROM purchase_events
LEFT JOIN item_rollup
  USING (purchase_event_key);

CREATE OR REPLACE TABLE `bigquery-457902.ga4_ops_bi.core_d_items`
PARTITION BY first_seen_day AS
WITH item_stats AS (
  SELECT
    item_id,
    ARRAY_AGG(item_name IGNORE NULLS ORDER BY order_event_at DESC LIMIT 1)[SAFE_OFFSET(0)] AS item_name,
    ARRAY_AGG(item_brand IGNORE NULLS ORDER BY order_event_at DESC LIMIT 1)[SAFE_OFFSET(0)] AS item_brand,
    ARRAY_AGG(item_variant IGNORE NULLS ORDER BY order_event_at DESC LIMIT 1)[SAFE_OFFSET(0)] AS item_variant,
    ARRAY_AGG(item_category IGNORE NULLS ORDER BY order_event_at DESC LIMIT 1)[SAFE_OFFSET(0)] AS item_category,
    MIN(partition_day) AS first_seen_day,
    MAX(partition_day) AS last_seen_day
  FROM `bigquery-457902.ga4_ops_bi.base_f_order_items`
  WHERE item_id IS NOT NULL
  GROUP BY item_id
)
SELECT
  *
FROM item_stats;
