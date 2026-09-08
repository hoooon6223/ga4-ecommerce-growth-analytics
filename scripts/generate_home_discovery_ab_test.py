#!/usr/bin/env python3
"""Generate a reproducible synthetic A/B test dataset for home discovery.

The baseline rates come from the GA4 analysis notes:
- Home Landing NAU first sessions: 46,923
- Home -> Item List Rate: 16,909 / 46,923
- Home -> View Item Rate: 9,711 / 46,923
- View Item -> Add to Cart Rate: 3,516 / 9,711

This script creates one synthetic row per eligible first session to demonstrate
experiment design, ITT metric calculation, and statistical decision logic.
"""

from __future__ import annotations

import csv
import math
import random
from dataclasses import dataclass
from pathlib import Path
from statistics import NormalDist


ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "outputs" / "ab_tests" / "home_discovery_ab_test_synthetic.csv"
SUMMARY_PATH = ROOT / "outputs" / "ab_tests" / "home_discovery_ab_test_summary.csv"
POWER_PLAN_PATH = ROOT / "outputs" / "ab_tests" / "home_discovery_ab_test_power_plan.csv"

SEED = 20260908
N_PER_VARIANT = 24000
ALPHA = 0.05
POWER = 0.80
PRIMARY_MDE = 0.035
GUARDRAIL_NONINFERIORITY_MARGIN = -0.02

HOME_LANDING_SESSIONS = 46923
HOME_ITEM_LIST_SESSIONS = 16909
HOME_VIEW_ITEM_SESSIONS = 9711
HOME_ITEM_LIST_TO_VIEW_SESSIONS = 9301
HOME_VIEW_TO_CART_SESSIONS = 3516
HOME_CART_TO_PURCHASE_SESSIONS = 502

BASE_ITEM_LIST_RATE = HOME_ITEM_LIST_SESSIONS / HOME_LANDING_SESSIONS
BASE_ITEM_LIST_TO_VIEW_RATE = 9301 / 16909
BASE_DIRECT_VIEW_RATE = max(
    0.0,
    (HOME_VIEW_ITEM_SESSIONS - HOME_ITEM_LIST_TO_VIEW_SESSIONS)
    / HOME_LANDING_SESSIONS,
)
BASE_VIEW_TO_CART_RATE = HOME_VIEW_TO_CART_SESSIONS / HOME_VIEW_ITEM_SESSIONS
BASE_CART_TO_PURCHASE_RATE = HOME_CART_TO_PURCHASE_SESSIONS / HOME_VIEW_TO_CART_SESSIONS
BASE_ARPPU = 76.30

TREATMENT_ITEM_LIST_RATE = BASE_ITEM_LIST_RATE + 0.035
TREATMENT_ITEM_LIST_TO_VIEW_RATE = BASE_ITEM_LIST_TO_VIEW_RATE
TREATMENT_DIRECT_VIEW_RATE = BASE_DIRECT_VIEW_RATE
TREATMENT_VIEW_TO_CART_RATE = BASE_VIEW_TO_CART_RATE
TREATMENT_CART_TO_PURCHASE_RATE = BASE_CART_TO_PURCHASE_RATE


@dataclass(frozen=True)
class VariantParams:
    variant: str
    item_list_rate: float
    item_list_to_view_rate: float
    direct_view_rate: float
    view_to_cart_rate: float
    cart_to_purchase_rate: float


def trial(rng: random.Random, p: float) -> int:
    return int(rng.random() < p)


def revenue_for_purchase(rng: random.Random) -> float:
    # Gamma distribution gives positive skew common in order values.
    value = rng.gammavariate(alpha=4.0, beta=BASE_ARPPU / 4.0)
    return round(value, 2)


def generate_rows() -> list[dict[str, object]]:
    rng = random.Random(SEED)
    params = [
        VariantParams(
            "control",
            BASE_ITEM_LIST_RATE,
            BASE_ITEM_LIST_TO_VIEW_RATE,
            BASE_DIRECT_VIEW_RATE,
            BASE_VIEW_TO_CART_RATE,
            BASE_CART_TO_PURCHASE_RATE,
        ),
        VariantParams(
            "treatment",
            TREATMENT_ITEM_LIST_RATE,
            TREATMENT_ITEM_LIST_TO_VIEW_RATE,
            TREATMENT_DIRECT_VIEW_RATE,
            TREATMENT_VIEW_TO_CART_RATE,
            TREATMENT_CART_TO_PURCHASE_RATE,
        ),
    ]

    rows: list[dict[str, object]] = []
    for variant_params in params:
        for idx in range(N_PER_VARIANT):
            anonymous_id = f"user_{variant_params.variant}_{idx + 1:05d}"
            reached_item_list = trial(rng, variant_params.item_list_rate)
            if reached_item_list:
                reached_view_item = trial(rng, variant_params.item_list_to_view_rate)
            else:
                reached_view_item = trial(rng, variant_params.direct_view_rate)

            reached_cart = trial(rng, variant_params.view_to_cart_rate) if reached_view_item else 0
            purchased = trial(rng, variant_params.cart_to_purchase_rate) if reached_cart else 0
            revenue = revenue_for_purchase(rng) if purchased else 0.0

            rows.append(
                {
                    "experiment_id": "home_discovery_entrypoint_v1",
                    "anonymous_id": anonymous_id,
                    "eligible_first_session_id": f"session_{variant_params.variant}_{idx + 1:05d}",
                    "variant": variant_params.variant,
                    "is_home_landing_nau_first_session": 1,
                    "reached_item_list": reached_item_list,
                    "reached_view_item": reached_view_item,
                    "reached_add_to_cart": reached_cart,
                    "purchased": purchased,
                    "revenue": revenue,
                }
            )
    return rows


def summarize(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    summary: list[dict[str, object]] = []
    for variant in ["control", "treatment"]:
        subset = [row for row in rows if row["variant"] == variant]
        n = len(subset)
        item_list = sum(int(row["reached_item_list"]) for row in subset)
        view_item = sum(int(row["reached_view_item"]) for row in subset)
        cart = sum(int(row["reached_add_to_cart"]) for row in subset)
        purchase = sum(int(row["purchased"]) for row in subset)
        revenue = sum(float(row["revenue"]) for row in subset)

        summary.append(
            {
                "variant": variant,
                "sessions": n,
                "item_list_sessions": item_list,
                "view_item_sessions": view_item,
                "add_to_cart_sessions": cart,
                "purchase_sessions": purchase,
                "revenue": round(revenue, 2),
                "home_to_item_list_rate": item_list / n,
                "home_to_view_item_rate": view_item / n,
                "item_list_to_view_item_rate": view_item / item_list if item_list else 0.0,
                "view_to_cart_rate": cart / view_item if view_item else 0.0,
                "purchase_rate": purchase / n,
                "revenue_per_session": revenue / n,
            }
        )

    control = summary[0]
    treatment = summary[1]
    for metric in [
        "home_to_item_list_rate",
        "home_to_view_item_rate",
        "item_list_to_view_item_rate",
        "view_to_cart_rate",
        "purchase_rate",
        "revenue_per_session",
    ]:
        c = float(control[metric])
        t = float(treatment[metric])
        treatment[f"{metric}_abs_lift"] = t - c
        treatment[f"{metric}_rel_lift"] = (t / c - 1) if c else 0.0

    treatment["home_to_item_list_p_value_one_sided"] = two_proportion_p_value(
        int(treatment["item_list_sessions"]),
        int(treatment["sessions"]),
        int(control["item_list_sessions"]),
        int(control["sessions"]),
        alternative="greater",
    )
    treatment["home_to_view_item_p_value_two_sided"] = two_proportion_p_value(
        int(treatment["view_item_sessions"]),
        int(treatment["sessions"]),
        int(control["view_item_sessions"]),
        int(control["sessions"]),
        alternative="two-sided",
    )
    treatment.update(
        confidence_interval_fields(
            "home_to_item_list",
            int(treatment["item_list_sessions"]),
            int(treatment["sessions"]),
            int(control["item_list_sessions"]),
            int(control["sessions"]),
        )
    )
    treatment.update(
        confidence_interval_fields(
            "home_to_view_item",
            int(treatment["view_item_sessions"]),
            int(treatment["sessions"]),
            int(control["view_item_sessions"]),
            int(control["sessions"]),
        )
    )
    treatment.update(
        confidence_interval_fields(
            "item_list_to_view_item",
            int(treatment["view_item_sessions"]),
            int(treatment["item_list_sessions"]),
            int(control["view_item_sessions"]),
            int(control["item_list_sessions"]),
        )
    )
    treatment["guardrail_noninferiority_margin"] = GUARDRAIL_NONINFERIORITY_MARGIN
    treatment["guardrail_pass"] = (
        float(treatment["item_list_to_view_item_diff_ci_low"])
        > GUARDRAIL_NONINFERIORITY_MARGIN
    )

    return summary


def two_proportion_p_value(
    success_a: int,
    n_a: int,
    success_b: int,
    n_b: int,
    alternative: str,
) -> float:
    p_pool = (success_a + success_b) / (n_a + n_b)
    se = math.sqrt(p_pool * (1.0 - p_pool) * (1.0 / n_a + 1.0 / n_b))
    if se == 0:
        return 1.0
    z = ((success_a / n_a) - (success_b / n_b)) / se
    if alternative == "greater":
        return 1.0 - NormalDist().cdf(z)
    if alternative == "two-sided":
        return 2.0 * (1.0 - NormalDist().cdf(abs(z)))
    raise ValueError(f"unsupported alternative: {alternative}")


def confidence_interval_fields(
    metric_prefix: str,
    success_treatment: int,
    n_treatment: int,
    success_control: int,
    n_control: int,
) -> dict[str, float]:
    p_treatment = success_treatment / n_treatment
    p_control = success_control / n_control
    diff = p_treatment - p_control
    se = math.sqrt(
        p_treatment * (1.0 - p_treatment) / n_treatment
        + p_control * (1.0 - p_control) / n_control
    )
    z = NormalDist().inv_cdf(0.975)
    return {
        f"{metric_prefix}_diff_ci_low": diff - z * se,
        f"{metric_prefix}_diff_ci_high": diff + z * se,
    }


def required_n_per_variant(
    baseline_rate: float,
    mde: float,
    alpha: float,
    power: float,
    one_sided: bool = True,
) -> int:
    treatment_rate = baseline_rate + mde
    pooled_rate = (baseline_rate + treatment_rate) / 2.0
    z_alpha = NormalDist().inv_cdf(1.0 - alpha if one_sided else 1.0 - alpha / 2.0)
    z_beta = NormalDist().inv_cdf(power)
    numerator = (
        z_alpha * math.sqrt(2.0 * pooled_rate * (1.0 - pooled_rate))
        + z_beta
        * math.sqrt(
            baseline_rate * (1.0 - baseline_rate)
            + treatment_rate * (1.0 - treatment_rate)
        )
    ) ** 2
    return math.ceil(numerator / (mde**2))


def power_plan() -> list[dict[str, object]]:
    required_n = required_n_per_variant(
        BASE_ITEM_LIST_RATE,
        PRIMARY_MDE,
        ALPHA,
        POWER,
        one_sided=True,
    )
    expected_eligible_sessions_per_week = HOME_LANDING_SESSIONS / 4.0
    expected_sessions_per_variant_per_week = expected_eligible_sessions_per_week / 2.0
    return [
        {
            "primary_metric": "home_to_item_list_rate",
            "baseline_rate": BASE_ITEM_LIST_RATE,
            "mde_abs": PRIMARY_MDE,
            "alpha": ALPHA,
            "power": POWER,
            "test": "one-sided two-proportion z-test",
            "required_n_per_variant": required_n,
            "expected_eligible_sessions_per_week": expected_eligible_sessions_per_week,
            "expected_sessions_per_variant_per_week": expected_sessions_per_variant_per_week,
            "estimated_min_weeks": required_n / expected_sessions_per_variant_per_week,
            "simulated_n_per_variant": N_PER_VARIANT,
            "simulated_duration_weeks": N_PER_VARIANT
            / expected_sessions_per_variant_per_week,
        }
    ]


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    rows = generate_rows()
    summary = summarize(rows)
    plan = power_plan()
    write_csv(DATA_PATH, rows)
    write_csv(SUMMARY_PATH, summary)
    write_csv(POWER_PLAN_PATH, plan)
    print(f"Wrote {len(rows):,} rows to {DATA_PATH}")
    print(f"Wrote summary to {SUMMARY_PATH}")
    print(f"Wrote power plan to {POWER_PLAN_PATH}")


if __name__ == "__main__":
    main()
