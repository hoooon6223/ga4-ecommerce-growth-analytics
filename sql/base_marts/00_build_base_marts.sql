-- Build source-level fact tables for GA4 ecommerce product analytics.
--
-- Final base model:
--   1. base_f_event_wide   : one row per GA4 event
--   2. base_f_order_items  : one row per purchase event x item
--
-- Both tables stay close to the GA4 source structure. They standardize keys and
-- flatten repeated fields only where needed for analysis.

DECLARE start_date STRING DEFAULT '20201101';
DECLARE end_date STRING DEFAULT '20210131';

CREATE TEMP FUNCTION clean_string_value(value STRING) AS (
  CASE
    WHEN value IN ('(data deleted)', '<data deleted>') THEN NULL
    WHEN REGEXP_CONTAINS(value, r'^\(.+\)$') THEN REGEXP_REPLACE(value, r'^\((.*)\)$', r'\1')
    WHEN REGEXP_CONTAINS(value, r'^<.+>$') THEN REGEXP_REPLACE(value, r'^<(.*)>$', r'\1')
    ELSE value
  END
);

CREATE OR REPLACE TABLE `bigquery-457902.ga4_ops_bi.base_f_event_wide`
PARTITION BY partition_day AS
SELECT
  CONCAT(
    user_pseudo_id,
    '-',
    CAST(event_timestamp AS STRING),
    '-',
    event_name,
    '-',
    CAST(event_bundle_sequence_id AS STRING)
  ) AS event_key,
  CASE
    WHEN (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') IS NOT NULL
      THEN ROW_NUMBER() OVER (
        PARTITION BY
          user_pseudo_id,
          (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
        ORDER BY
          event_timestamp,
          event_bundle_sequence_id,
          event_name,
          CONCAT(
            user_pseudo_id,
            '-',
            CAST(event_timestamp AS STRING),
            '-',
            event_name,
            '-',
            CAST(event_bundle_sequence_id AS STRING)
          )
      )
  END AS event_seq,
  PARSE_DATE('%Y%m%d', event_date) AS partition_day,
  TIMESTAMP_MICROS(event_timestamp) AS event_at,
  event_timestamp,
  event_bundle_sequence_id,
  event_name,
  user_pseudo_id AS anonymous_id,
  TIMESTAMP_MICROS(user_first_touch_timestamp) AS user_first_touch_at,
  clean_string_value(platform) AS platform,
  clean_string_value(event_dimensions.hostname) AS hostname,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS ga_session_number,
  CONCAT(
    user_pseudo_id,
    '-',
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
  ) AS session_id,
  clean_string_value(device.category) AS device_category,
  clean_string_value(device.operating_system) AS operating_system,
  clean_string_value(device.operating_system_version) AS operating_system_version,
  clean_string_value(device.language) AS language,
  clean_string_value(device.web_info.browser) AS browser,
  clean_string_value(device.web_info.browser_version) AS browser_version,
  clean_string_value(geo.country) AS country,
  clean_string_value(geo.region) AS region,
  clean_string_value(geo.city) AS city,
  clean_string_value(traffic_source.source) AS traffic_source,
  clean_string_value(traffic_source.medium) AS traffic_medium,
  clean_string_value(traffic_source.name) AS traffic_campaign,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source')) AS event_param_source,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium')) AS event_param_medium,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign')) AS event_param_campaign,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')) AS page_location,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title')) AS page_title,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_referrer')) AS page_referrer,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engaged_session_event') AS engaged_session_event,
  COALESCE(
    clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged')),
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS STRING)
  ) AS session_engaged,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'percent_scrolled') AS percent_scrolled,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'entrances') AS entrances,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'term')) AS term,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'search_term')) AS search_term,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'unique_search_term') AS unique_search_term,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'currency')) AS event_currency,
  COALESCE(
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'value') AS FLOAT64),
    (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'value'),
    (SELECT value.float_value FROM UNNEST(event_params) WHERE key = 'value')
  ) AS event_value,
  COALESCE(
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'tax') AS FLOAT64),
    (SELECT value.double_value FROM UNNEST(event_params) WHERE key = 'tax'),
    (SELECT value.float_value FROM UNNEST(event_params) WHERE key = 'tax')
  ) AS event_tax,
  COALESCE(
    clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id')),
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
  ) AS event_param_transaction_id,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'payment_type')) AS payment_type,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'shipping_tier')) AS shipping_tier,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'coupon')) AS event_coupon,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'promotion_name')) AS event_promotion_name,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'link_url')) AS link_url,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'link_domain')) AS link_domain,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'outbound')) AS outbound,
  ecommerce.total_item_quantity,
  ecommerce.purchase_revenue,
  ecommerce.refund_value,
  ecommerce.shipping_value,
  ecommerce.tax_value,
  ecommerce.unique_items,
  clean_string_value(ecommerce.transaction_id) AS transaction_id,
  ARRAY_LENGTH(items) AS item_row_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN start_date AND end_date;

CREATE OR REPLACE TABLE `bigquery-457902.ga4_ops_bi.base_f_order_items`
PARTITION BY partition_day AS
SELECT
  CONCAT(
    user_pseudo_id,
    '-',
    CAST(event_timestamp AS STRING),
    '-',
    event_name,
    '-',
    CAST(event_bundle_sequence_id AS STRING),
    '-',
    CAST(item_index AS STRING)
  ) AS item_order_id,
  CONCAT(
    user_pseudo_id,
    '-',
    CAST(event_timestamp AS STRING),
    '-',
    event_name,
    '-',
    CAST(event_bundle_sequence_id AS STRING)
  ) AS purchase_event_key,
  CONCAT(
    user_pseudo_id,
    '-',
    CAST(event_timestamp AS STRING),
    '-',
    event_name,
    '-',
    CAST(event_bundle_sequence_id AS STRING)
  ) AS order_id,
  CONCAT(
    user_pseudo_id,
    '-',
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
  ) AS session_id,
  user_pseudo_id AS anonymous_id,
  PARSE_DATE('%Y%m%d', event_date) AS partition_day,
  TIMESTAMP_MICROS(event_timestamp) AS order_event_at,
  event_name,
  clean_string_value(ecommerce.transaction_id) AS transaction_id,
  COALESCE(
    clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'transaction_id')),
    CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'transaction_id') AS STRING)
  ) AS event_param_transaction_id,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'currency')) AS currency,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'payment_type')) AS payment_type,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'shipping_tier')) AS shipping_tier,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'coupon')) AS order_coupon,
  clean_string_value((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'promotion_name')) AS order_promotion_name,
  ecommerce.purchase_revenue,
  item_index AS item_seq,
  clean_string_value(item.item_id) AS item_id,
  clean_string_value(item.item_name) AS item_name,
  clean_string_value(item.item_brand) AS item_brand,
  clean_string_value(item.item_variant) AS item_variant,
  clean_string_value(item.item_category) AS item_category,
  item.price,
  item.quantity,
  item.item_revenue,
  item.item_refund,
  clean_string_value(item.coupon) AS item_coupon,
  clean_string_value(item.item_list_name) AS item_list_name,
  clean_string_value(item.promotion_id) AS promotion_id,
  clean_string_value(item.promotion_name) AS item_promotion_name,
  clean_string_value(device.category) AS device_category,
  clean_string_value(device.operating_system) AS operating_system,
  clean_string_value(device.web_info.browser) AS browser,
  clean_string_value(geo.country) AS country,
  clean_string_value(geo.city) AS city,
  clean_string_value(traffic_source.source) AS traffic_source,
  clean_string_value(traffic_source.medium) AS traffic_medium,
  clean_string_value(traffic_source.name) AS traffic_campaign
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
CROSS JOIN UNNEST(items) AS item WITH OFFSET AS item_index
WHERE _TABLE_SUFFIX BETWEEN start_date AND end_date
  AND event_name = 'purchase';
