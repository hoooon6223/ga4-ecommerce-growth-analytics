-- A/B test evaluation SQL for the Home discovery experiment.
--
-- This query is self-contained: it generates deterministic synthetic
-- experiment rows in SQL, then evaluates the experiment.
--
-- Experiment design:
--   Eligibility Unit = NAU first session with Home Landing
--   Randomization Unit = anonymous_id
--   Analysis Unit = eligible Home Landing first session
--
-- Decision rules:
--   Primary: Home -> Item List Rate, one-sided alpha = 0.05
--   Key Secondary: Home -> View Item Rate lift and 95% CI
--   Guardrail: Item List -> View Item Rate non-inferiority margin = -2.00%p
--   Downstream: Purchase Rate and Revenue per Session direction only

DECLARE guardrail_noninferiority_margin FLOAT64 DEFAULT -0.02;

CREATE TEMP FUNCTION normal_cdf(x FLOAT64) AS (
  CASE
    WHEN x >= 0 THEN 1 - 0.5 * EXP(-0.717 * x - 0.416 * x * x)
    ELSE 0.5 * EXP(0.717 * x - 0.416 * x * x)
  END
);

WITH experiment_rows AS (
  SELECT
    'home_discovery_entrypoint_v1' AS experiment_id,
    anonymous_id,
    eligible_first_session_id,
    variant,
    reached_item_list,
    reached_view_item,
    reached_add_to_cart,
    purchased,
    IF(purchased = 1, ROUND(76.30 * (0.5 + revenue_random), 2), 0.0) AS revenue
  FROM (
    SELECT
      *,
      IF(item_list_random < item_list_rate, 1, 0) AS reached_item_list,
      IF(
        IF(item_list_random < item_list_rate, 1, 0) = 1,
        IF(item_list_to_view_random < item_list_to_view_rate, 1, 0),
        IF(direct_view_random < direct_view_rate, 1, 0)
      ) AS reached_view_item,
      IF(
        IF(
          IF(item_list_random < item_list_rate, 1, 0) = 1,
          IF(item_list_to_view_random < item_list_to_view_rate, 1, 0),
          IF(direct_view_random < direct_view_rate, 1, 0)
        ) = 1
        AND cart_random < view_to_cart_rate,
        1,
        0
      ) AS reached_add_to_cart,
      IF(
        IF(
          IF(
            IF(item_list_random < item_list_rate, 1, 0) = 1,
            IF(item_list_to_view_random < item_list_to_view_rate, 1, 0),
            IF(direct_view_random < direct_view_rate, 1, 0)
          ) = 1
          AND cart_random < view_to_cart_rate,
          1,
          0
        ) = 1
        AND purchase_random < cart_to_purchase_rate,
        1,
        0
      ) AS purchased
    FROM (
      SELECT
        variant,
        FORMAT('user_%s_%05d', variant, idx) AS anonymous_id,
        FORMAT('session_%s_%05d', variant, idx) AS eligible_first_session_id,
        item_list_rate,
        item_list_to_view_rate,
        direct_view_rate,
        view_to_cart_rate,
        cart_to_purchase_rate,
        ABS(MOD(FARM_FINGERPRINT(CONCAT(variant, '|', CAST(idx AS STRING), '|item_list')), 1000000)) / 1000000.0 AS item_list_random,
        ABS(MOD(FARM_FINGERPRINT(CONCAT(variant, '|', CAST(idx AS STRING), '|item_list_to_view')), 1000000)) / 1000000.0 AS item_list_to_view_random,
        ABS(MOD(FARM_FINGERPRINT(CONCAT(variant, '|', CAST(idx AS STRING), '|direct_view')), 1000000)) / 1000000.0 AS direct_view_random,
        ABS(MOD(FARM_FINGERPRINT(CONCAT(variant, '|', CAST(idx AS STRING), '|cart')), 1000000)) / 1000000.0 AS cart_random,
        ABS(MOD(FARM_FINGERPRINT(CONCAT(variant, '|', CAST(idx AS STRING), '|purchase')), 1000000)) / 1000000.0 AS purchase_random,
        ABS(MOD(FARM_FINGERPRINT(CONCAT(variant, '|', CAST(idx AS STRING), '|revenue')), 1000000)) / 1000000.0 AS revenue_random
      FROM (
        SELECT
          'control' AS variant,
          16909 / 46923 AS item_list_rate,
          9301 / 16909 AS item_list_to_view_rate,
          GREATEST(0.0, (9711 - 9301) / 46923) AS direct_view_rate,
          3516 / 9711 AS view_to_cart_rate,
          502 / 3516 AS cart_to_purchase_rate

        UNION ALL

        SELECT
          'treatment',
          16909 / 46923 + 0.035,
          9301 / 16909,
          GREATEST(0.0, (9711 - 9301) / 46923),
          3516 / 9711,
          502 / 3516
      ) params
      CROSS JOIN UNNEST(GENERATE_ARRAY(1, 24000)) AS idx
    )
  )
),
srm AS (
  SELECT
    variant,
    COUNT(*) AS row_count,
    COUNT(DISTINCT anonymous_id) AS randomized_users
  FROM experiment_rows
  GROUP BY
    variant
),
variant_metrics AS (
  SELECT
    variant,
    COUNT(*) AS eligible_first_sessions,
    COUNT(DISTINCT anonymous_id) AS randomized_users,
    SUM(reached_item_list) AS item_list_sessions,
    SUM(reached_view_item) AS view_item_sessions,
    SUM(reached_add_to_cart) AS add_to_cart_sessions,
    SUM(purchased) AS purchase_sessions,
    ROUND(SUM(revenue), 2) AS revenue,
    SAFE_DIVIDE(SUM(reached_item_list), COUNT(*)) AS home_to_item_list_rate,
    SAFE_DIVIDE(SUM(reached_view_item), COUNT(*)) AS home_to_view_item_rate,
    SAFE_DIVIDE(SUM(reached_view_item), SUM(reached_item_list)) AS item_list_to_view_item_rate,
    SAFE_DIVIDE(SUM(reached_add_to_cart), SUM(reached_view_item)) AS view_to_cart_rate,
    SAFE_DIVIDE(SUM(purchased), COUNT(*)) AS purchase_rate,
    SAFE_DIVIDE(SUM(revenue), COUNT(*)) AS revenue_per_session
  FROM experiment_rows
  GROUP BY
    variant
),
pivoted AS (
  SELECT
    MAX(IF(variant = 'control', eligible_first_sessions, NULL)) AS n_c,
    MAX(IF(variant = 'treatment', eligible_first_sessions, NULL)) AS n_t,
    MAX(IF(variant = 'control', item_list_sessions, NULL)) AS item_list_c,
    MAX(IF(variant = 'treatment', item_list_sessions, NULL)) AS item_list_t,
    MAX(IF(variant = 'control', view_item_sessions, NULL)) AS view_item_c,
    MAX(IF(variant = 'treatment', view_item_sessions, NULL)) AS view_item_t,
    MAX(IF(variant = 'control', purchase_sessions, NULL)) AS purchase_c,
    MAX(IF(variant = 'treatment', purchase_sessions, NULL)) AS purchase_t,
    MAX(IF(variant = 'control', revenue_per_session, NULL)) AS rps_c,
    MAX(IF(variant = 'treatment', revenue_per_session, NULL)) AS rps_t
  FROM variant_metrics
),
metric_tests AS (
  SELECT
    'Home -> Item List Rate' AS metric,
    SAFE_DIVIDE(item_list_c, n_c) AS control_rate,
    SAFE_DIVIDE(item_list_t, n_t) AS treatment_rate,
    SAFE_DIVIDE(item_list_t, n_t) - SAFE_DIVIDE(item_list_c, n_c) AS abs_lift,
    SAFE_DIVIDE(SAFE_DIVIDE(item_list_t, n_t), SAFE_DIVIDE(item_list_c, n_c)) - 1 AS rel_lift,
    (
      SAFE_DIVIDE(item_list_t, n_t) - SAFE_DIVIDE(item_list_c, n_c)
      - 1.96 * SQRT(
        SAFE_DIVIDE(item_list_t, n_t) * (1 - SAFE_DIVIDE(item_list_t, n_t)) / n_t
        + SAFE_DIVIDE(item_list_c, n_c) * (1 - SAFE_DIVIDE(item_list_c, n_c)) / n_c
      )
    ) AS ci_low,
    (
      SAFE_DIVIDE(item_list_t, n_t) - SAFE_DIVIDE(item_list_c, n_c)
      + 1.96 * SQRT(
        SAFE_DIVIDE(item_list_t, n_t) * (1 - SAFE_DIVIDE(item_list_t, n_t)) / n_t
        + SAFE_DIVIDE(item_list_c, n_c) * (1 - SAFE_DIVIDE(item_list_c, n_c)) / n_c
      )
    ) AS ci_high,
    1 - normal_cdf(
      (SAFE_DIVIDE(item_list_t, n_t) - SAFE_DIVIDE(item_list_c, n_c))
      / SQRT(
        SAFE_DIVIDE(item_list_t + item_list_c, n_t + n_c)
        * (1 - SAFE_DIVIDE(item_list_t + item_list_c, n_t + n_c))
        * (SAFE_DIVIDE(1, n_t) + SAFE_DIVIDE(1, n_c))
      )
    ) AS p_value,
    'primary_one_sided' AS test_role
  FROM pivoted

  UNION ALL

  SELECT
    'Home -> View Item Rate',
    SAFE_DIVIDE(view_item_c, n_c),
    SAFE_DIVIDE(view_item_t, n_t),
    SAFE_DIVIDE(view_item_t, n_t) - SAFE_DIVIDE(view_item_c, n_c),
    SAFE_DIVIDE(SAFE_DIVIDE(view_item_t, n_t), SAFE_DIVIDE(view_item_c, n_c)) - 1,
    (
      SAFE_DIVIDE(view_item_t, n_t) - SAFE_DIVIDE(view_item_c, n_c)
      - 1.96 * SQRT(
        SAFE_DIVIDE(view_item_t, n_t) * (1 - SAFE_DIVIDE(view_item_t, n_t)) / n_t
        + SAFE_DIVIDE(view_item_c, n_c) * (1 - SAFE_DIVIDE(view_item_c, n_c)) / n_c
      )
    ),
    (
      SAFE_DIVIDE(view_item_t, n_t) - SAFE_DIVIDE(view_item_c, n_c)
      + 1.96 * SQRT(
        SAFE_DIVIDE(view_item_t, n_t) * (1 - SAFE_DIVIDE(view_item_t, n_t)) / n_t
        + SAFE_DIVIDE(view_item_c, n_c) * (1 - SAFE_DIVIDE(view_item_c, n_c)) / n_c
      )
    ),
    NULL,
    'key_secondary_ci'
  FROM pivoted

  UNION ALL

  SELECT
    'Item List -> View Item Rate',
    SAFE_DIVIDE(view_item_c, item_list_c),
    SAFE_DIVIDE(view_item_t, item_list_t),
    SAFE_DIVIDE(view_item_t, item_list_t) - SAFE_DIVIDE(view_item_c, item_list_c),
    SAFE_DIVIDE(SAFE_DIVIDE(view_item_t, item_list_t), SAFE_DIVIDE(view_item_c, item_list_c)) - 1,
    (
      SAFE_DIVIDE(view_item_t, item_list_t) - SAFE_DIVIDE(view_item_c, item_list_c)
      - 1.96 * SQRT(
        SAFE_DIVIDE(view_item_t, item_list_t) * (1 - SAFE_DIVIDE(view_item_t, item_list_t)) / item_list_t
        + SAFE_DIVIDE(view_item_c, item_list_c) * (1 - SAFE_DIVIDE(view_item_c, item_list_c)) / item_list_c
      )
    ),
    (
      SAFE_DIVIDE(view_item_t, item_list_t) - SAFE_DIVIDE(view_item_c, item_list_c)
      + 1.96 * SQRT(
        SAFE_DIVIDE(view_item_t, item_list_t) * (1 - SAFE_DIVIDE(view_item_t, item_list_t)) / item_list_t
        + SAFE_DIVIDE(view_item_c, item_list_c) * (1 - SAFE_DIVIDE(view_item_c, item_list_c)) / item_list_c
      )
    ),
    NULL,
    'guardrail_noninferiority'
  FROM pivoted
),
downstream AS (
  SELECT
    'Purchase Rate' AS metric,
    SAFE_DIVIDE(purchase_c, n_c) AS control_value,
    SAFE_DIVIDE(purchase_t, n_t) AS treatment_value,
    SAFE_DIVIDE(purchase_t, n_t) - SAFE_DIVIDE(purchase_c, n_c) AS abs_lift,
    SAFE_DIVIDE(SAFE_DIVIDE(purchase_t, n_t), SAFE_DIVIDE(purchase_c, n_c)) - 1 AS rel_lift
  FROM pivoted

  UNION ALL

  SELECT
    'Revenue per Session',
    rps_c,
    rps_t,
    rps_t - rps_c,
    SAFE_DIVIDE(rps_t, rps_c) - 1
  FROM pivoted
)
SELECT
  'srm_check' AS section,
  TO_JSON_STRING(ARRAY_AGG(STRUCT(variant, row_count, randomized_users) ORDER BY variant)) AS result
FROM srm

UNION ALL

SELECT
  'variant_metrics',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    variant,
    eligible_first_sessions,
    randomized_users,
    item_list_sessions,
    view_item_sessions,
    add_to_cart_sessions,
    purchase_sessions,
    revenue,
    home_to_item_list_rate,
    home_to_view_item_rate,
    item_list_to_view_item_rate,
    view_to_cart_rate,
    purchase_rate,
    revenue_per_session
  ) ORDER BY variant))
FROM variant_metrics

UNION ALL

SELECT
  'metric_tests',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    metric,
    control_rate,
    treatment_rate,
    abs_lift,
    rel_lift,
    ci_low,
    ci_high,
    p_value,
    test_role,
    IF(
      metric = 'Item List -> View Item Rate',
      ci_low > guardrail_noninferiority_margin,
      NULL
    ) AS guardrail_pass
  ) ORDER BY
    CASE test_role
      WHEN 'primary_one_sided' THEN 1
      WHEN 'key_secondary_ci' THEN 2
      WHEN 'guardrail_noninferiority' THEN 3
      ELSE 4
    END
  ))
FROM metric_tests

UNION ALL

SELECT
  'downstream_directional',
  TO_JSON_STRING(ARRAY_AGG(STRUCT(
    metric,
    control_value,
    treatment_value,
    abs_lift,
    rel_lift
  ) ORDER BY metric))
FROM downstream;
