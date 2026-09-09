# Code and Output Inventory

## 문서 목적

이 문서는 포트폴리오 분석에 사용한 SQL, Python script, output file을 한곳에 정리한 실행 인벤토리다.

분석 문서의 논리 흐름은 `docs/analysis_notes/`에서 관리하고,
이 문서는 해당 분석을 재현하거나 검토할 때 어떤 코드와 산출물을 봐야 하는지 안내한다.

## Mart Build SQL

| Path | 역할 | 주요 산출물 |
|---|---|---|
| `sql/base_marts/00_build_base_marts.sql` | GA4 raw event log를 분석 가능한 base fact로 변환 | `base_f_event_wide`, `base_f_order_items` |
| `sql/core_marts/00_build_core_marts.sql` | base mart를 session/order/item 중심 core mart로 변환 | `core_f_sessions`, `core_f_orders`, `core_d_items` |

## EDA SQL

`sql/eda`는 분석 방향을 탐색하고 중간 질문을 확인한 히스토리 쿼리다.
최종 포트폴리오 문서의 재현 기준은 아래 `Final Analysis SQL`을 우선 사용한다.

| Path | 역할 | 연결 문서 | 주요 output |
|---|---|---|---|
| `sql/eda/00_problem_context_eda.sql` | 전체 데이터 기간, 이벤트 구성, 초기 문제 맥락 확인 | `01_revenue_growth_flow.md` | - |
| `sql/eda/01_new_session_source_medium.sql` | 초기 신규/재방문 및 source/medium 맥락 확인 | exploratory | - |
| `sql/eda/02_funnel_reach_by_segment.sql` | 초기 reach funnel과 segment 차이 확인 | exploratory | - |
| `sql/eda/03_new_session_landing_page_funnel.sql` | 초기 landing page별 funnel 확인 | exploratory | - |
| `sql/eda/04_weekly_user_cohort_nau_eau_rau.sql` | NAU/EAU/RAU user-week segment 생성 및 비교 | `01_revenue_growth_flow.md` | `outputs/data/weekly_user_cohort_nau_eau_rau.csv` |
| `sql/eda/05_nau_first_session_sequential_funnel.sql` | NAU first-session sequential funnel 초안 확인 | `01_revenue_growth_flow.md` | - |
| `sql/eda/06_weekly_revenue_decomposition.sql` | 전체 기간 weekly revenue decomposition 확인 | `01_revenue_growth_flow.md` | `outputs/data/weekly_revenue_decomposition.csv` |
| `sql/eda/07_main_period_weekly_revenue_decomposition.sql` | 주요 분석 기간 weekly revenue decomposition 확정 | `01_revenue_growth_flow.md` | `outputs/data/weekly_revenue_decomposition_main_period.csv` |
| `sql/eda/08_main_period_segment_week_first_session_sequential_funnel.sql` | 주요 분석 기간 NAU/EAU/RAU first-session sequential funnel | `01_revenue_growth_flow.md` | `outputs/data/segment_week_first_session_funnel_main_period.csv` |
| `sql/eda/09_main_period_nau_front_funnel_context.sql` | Qualified NAU first-session 기준 front-funnel context 분석 | `02_home_discovery_funnel.md`, `03_home_discovery_why_hypothesis.md` | `outputs/data/main_period_nau_front_funnel_context.csv` |
| `sql/eda/10_main_period_nau_funnel_by_source_and_landing.sql` | NAU source/landing별 funnel과 landing 구성 확인 | `02_home_discovery_funnel.md` | `outputs/data/main_period_nau_funnel_by_source_and_landing.csv`, `outputs/data/main_period_nau_top_landing_by_selected_source.csv` |
| `sql/eda/11_main_period_nau_home_no_action_sizing.sql` | Strict Homepage Bounce-like Session 규모 산정 | `01_revenue_growth_flow.md`, `02_home_discovery_funnel.md` | `outputs/data/main_period_nau_home_no_action_sizing.csv` |
| `sql/eda/12_main_period_nau_landing_view_item_opportunity.sql` | Home/item_list landing별 View Item opportunity 비교 | `02_home_discovery_funnel.md` | - |

## Final Analysis SQL

`sql/analysis`는 문서 `01~03`의 최종 정의와 맞춘 재현용 SQL이다.

| Path | 역할 | 연결 문서 |
|---|---|---|
| `sql/analysis/01_main_period_revenue_cohort_funnel.sql` | 매출 분해, NAU/EAU/RAU cohort summary, first-session sequential funnel 재현 | `01_revenue_growth_flow.md` |
| `sql/analysis/02_home_discovery_routes.sql` | Home landing baseline, Qualified Home Landing, search route, Home -> View Item route segment 재현 | `02_home_discovery_funnel.md` |
| `sql/analysis/03_home_discovery_why.sql` | source/device, no-view detail, first other page, event pattern, promotion behavior WHY 진단 재현 | `03_home_discovery_why_hypothesis.md` |

## A/B Test Simulation Script

| Path | 역할 | 주요 output |
|---|---|---|
| `scripts/generate_home_discovery_ab_test.py` | Home discovery 제품 가설 기반 synthetic A/B test data 생성, lift/CI/p-value/sample size 계산 | `outputs/ab_tests/home_discovery_ab_test_synthetic.csv`, `outputs/ab_tests/home_discovery_ab_test_summary.csv`, `outputs/ab_tests/home_discovery_ab_test_power_plan.csv` |

실행:

```bash
python3 scripts/generate_home_discovery_ab_test.py
```

주의:

```text
synthetic A/B test dataset은 실제 실험 로그가 아니라
실험 설계와 평가 방식을 보여주기 위한 산출물이다.

Eligibility Unit = NAU first session with Home Landing
Randomization Unit = anonymous_id
Analysis Unit = eligible Home Landing first session
```

## A/B Test SQL

| Path | 역할 | 입력 |
|---|---|---|
| `sql/ab_tests/01_home_discovery_ab_test_evaluation.sql` | SQL 안에서 deterministic synthetic experiment rows를 생성한 뒤 lift, CI, p-value, guardrail 판정 재현 | self-contained |

## Figure Outputs

| Path | 연결 문서 | 내용 |
|---|---|---|
| `outputs/figures/main_period_weekly_revenue_decomposition_small_multiples.svg` | `01_revenue_growth_flow.md` | 주요 분석 기간 Weekly Revenue, WAU, Buyer CVR, ARPPU 흐름 |
| `outputs/figures/main_period_segment_opportunity.svg` | `01_revenue_growth_flow.md` | NAU/EAU/RAU segment별 규모와 전환 기회 |
| `outputs/figures/wau_composition_main_period.svg` | `01_revenue_growth_flow.md` | 주요 분석 기간 WAU 구성 |
| `outputs/figures/main_period_first_session_funnel_by_cohort.svg` | `01_revenue_growth_flow.md` | NAU/EAU/RAU first-session sequential funnel |
| `outputs/figures/main_period_nau_funnel_by_source_medium.svg` | exploratory | source/medium별 NAU funnel |

PNG 파일은 동일 figure의 렌더링 확인 또는 발표 자료 삽입용 이미지다.

## Analysis Notes

| Path | 역할 |
|---|---|
| `docs/analysis_notes/01_revenue_growth_flow.md` | Business Goal -> Revenue decomposition -> WHO/WHERE 분석 |
| `docs/analysis_notes/02_home_discovery_funnel.md` | Home landing route segment와 discovery pool 분석 |
| `docs/analysis_notes/03_home_discovery_why_hypothesis.md` | WHY 후보를 지표로 좁히고 제품 가설로 연결 |
| `docs/analysis_notes/04_ab_test_design_and_evaluation.md` | A/B test 설계, sample size, success criteria, simulated result 평가 |

## Supporting Docs

| Path | 역할 |
|---|---|
| `docs/event_dictionary.md` | GA4 event_name과 event_params 해석 |
| `docs/mart_data_dictionary.md` | mart grain, PK, 주요 컬럼 정의 |
| `docs/metric_definitions.md` | 분석 지표, 퍼널 지표, 실험 지표 정의 |
| `docs/learning/mart_design.md` | mart 설계 과정에서 배운 점 회고 |

## 정리 기준

```text
1. SQL은 mart build와 EDA/analysis로 분리한다.
2. Python은 재현 가능한 산출물 생성 script만 scripts/에 둔다.
3. 분석 결과 CSV는 outputs/data 또는 outputs/ab_tests에 둔다.
4. 시각화 산출물은 outputs/figures에 둔다.
5. 포트폴리오 논리 문서는 docs/analysis_notes에 둔다.
```
