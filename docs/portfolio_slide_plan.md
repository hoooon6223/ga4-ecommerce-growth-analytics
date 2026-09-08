# Portfolio Slide Plan

## 목적

GA4 ecommerce 행동로그 기반 매출 성장 분석 프로젝트를 13장 포트폴리오로 구성한다.

슬라이드는 단순 결과 나열이 아니라 아래 흐름이 보이도록 설계한다.

```text
Data Mart
-> Business Goal
-> Revenue Decomposition
-> WHO
-> WHERE
-> WHY
-> Product Hypothesis
-> A/B Test Simulation
-> Modeled Revenue Opportunity
```

## 1. 프로젝트 개요: 주별 매출 성장을 위한 행동 분석

핵심 메시지:

```text
GA4 ecommerce 행동로그를 mart로 모델링하고,
주별 매출 성장을 위한 구매 전환 개선 기회를 찾았다.
```

넣을 내용:

| 항목 | 값 |
|---|---|
| Dataset | GA4 Obfuscated Sample Ecommerce |
| Data Period | 2020-11-01 to 2021-01-31 |
| Main Period | 2020-11-23 to 2020-12-20 |
| Business Goal | Weekly Revenue Growth |

Why Weekly:

```text
Daily는 요일/트래픽 변동 노이즈가 커서 user segment와 구매 전환율을 해석하기 어렵고,
Monthly는 샘플 데이터 기간상 관측치가 적어 cohort/funnel 비교가 둔해진다.

Weekly는 WAU, Weekly Buyer CVR, ARPPU를 안정적으로 비교하면서
제품 실험의 planning/duration과 연결하기 좋은 단위다.
```

시각화:

| 유형 | 내용 | 상태 |
|---|---|---|
| 흐름 다이어그램 | Mart -> Analysis -> Experiment -> Opportunity | 신규 제작 |

## 2. 분석 기반 구축: GA4 데이터 마트 설계

핵심 메시지:

```text
Raw event log를 event, session, order, item grain으로 분리해
퍼널과 매출 분석이 가능한 mart를 설계했다.
```

넣을 내용:

| Table | Grain | Purpose |
|---|---|---|
| base_f_event_wide | 1 row = 1 event | GA4 event_params wide event fact |
| base_f_order_items | 1 row = 1 purchase event x item | item-level revenue/category 분석 |
| core_f_sessions | 1 row = 1 session | session behavior/acquisition summary |
| core_f_orders | 1 row = 1 purchase event | order-level revenue fact |
| core_d_items | 1 row = observed item_id | observed item dimension |

시각화:

| 유형 | 내용 | 상태 |
|---|---|---|
| Mart architecture diagram | GA4 Raw Events -> base/core marts | 신규 제작 |

발표 포인트:

```text
event_seq로 sequential funnel을 만들 수 있게 했고,
purchase_revenue와 item_revenue의 grain을 분리했다.
```

## 3. 비즈니스 목표 구조화: 주별 매출 분해

핵심 메시지:

```text
Weekly Revenue를 WAU, Weekly Buyer CVR, ARPPU로 분해해
개선 가능한 growth lever를 찾았다.
```

공식:

```text
Weekly Revenue = WAU x Weekly Buyer CVR x ARPPU
```

핵심 수치:

| Metric | Value |
|---|---:|
| Average Weekly Revenue | $49.5K |
| Main Period | 4 weeks |

시각화:

| 유형 | 내용 | 상태 | 파일 |
|---|---|---|---|
| Small multiples | Weekly Revenue, WAU, Buyer CVR, ARPPU | 기존 사용 | `outputs/figures/main_period_weekly_revenue_decomposition_small_multiples.png` |

발표 포인트:

```text
WAU는 acquisition/traffic lever,
ARPPU는 pricing/basket/promotion lever,
Buyer CVR은 GA4 행동로그로 product experience 병목을 직접 진단할 수 있는 lever다.
```

## 4. 타겟 선정: 어떤 사용자를 우선 볼 것인가

핵심 메시지:

```text
NAU는 가장 큰 user-week pool이면서 Buyer CVR이 낮아,
first-session 전환 개선 기회를 보기 좋은 대상이었다.
```

핵심 수치:

| Segment | Active User-Weeks Share | Buyer CVR |
|---|---:|---:|
| NAU | 90.4% | 1.63% |
| EAU | 5.7% | 7.32% |
| RAU | 3.9% | 8.09% |

시각화:

| 유형 | 내용 | 상태 | 파일 |
|---|---|---|---|
| Combo/bar chart | segment별 규모와 Buyer CVR | 기존 사용 | `outputs/figures/main_period_segment_opportunity.png` |

발표 포인트:

```text
NAU가 항상 더 중요하다는 의미가 아니라,
규모가 크고 first-session behavior가 관측 가능해 실험 가설로 연결하기 좋은 scope다.
```

## 5. 병목 진단: 신규 유저 첫 세션 퍼널

핵심 메시지:

```text
NAU first session에서는 구매 후반보다
상품 상세 진입 전 discovery 구간이 더 큰 병목으로 보였다.
```

퍼널:

```text
View Item -> Add to Cart -> Begin Checkout -> Purchase
```

핵심 수치:

| Segment | First Sessions | View Item Rate | View -> Cart | Cart -> Checkout | Checkout -> Purchase |
|---|---:|---:|---:|---:|---:|
| NAU | 95,490 | 21.28% | 25.75% | 32.43% | 42.07% |
| EAU | 5,985 | 30.31% | 28.45% | 39.34% | 68.97% |
| RAU | 4,104 | 40.69% | 32.69% | 41.94% | 68.12% |

시각화:

| 유형 | 내용 | 상태 | 파일 |
|---|---|---|---|
| Funnel/bar chart | segment별 first-session sequential funnel | 기존 사용 | `outputs/figures/main_period_first_session_funnel_by_cohort.png` |

발표 포인트:

```text
같은 first session 안에서 event_seq 기준 순서를 강제했다.
```

## 6. 진입 맥락 분석: Home Landing의 기회 영역

핵심 메시지:

```text
Home Landing은 큰 entry context지만,
View Item까지 이어지는 비율은 20.70%에 그쳤다.
```

핵심 수치:

| Metric | Sessions | Rate |
|---|---:|---:|
| Home Landing NAU First Sessions | 46,923 | 100.00% |
| Reached Item List | 16,909 | 36.04% |
| Used Search | 2,593 | 5.53% |
| Reached View Item | 9,711 | 20.70% |
| Reached Cart after View Item | 3,516 | 36.21% of View Item |

시각화:

| 유형 | 내용 | 상태 | 데이터 |
|---|---|---|---|
| Reach funnel | Home -> Item List/Search/View Item/Cart | 신규 제작 | `sql/analysis/02_home_discovery_routes.sql` |

발표 포인트:

```text
Home에서 View Item까지의 discovery 구간을 더 깊게 볼 필요가 있다.
```

## 7. 진단 세그먼트 분리: Qualified Home

핵심 메시지:

```text
No-exploration은 별도 engagement 문제로 분리하고,
최소 탐색 행동이 시작된 Qualified Home에서 WHY를 진단했다.
```

Home split:

| Segment | Sessions |
|---|---:|
| Home Landing Total | 46,923 |
| No-exploration | 11,562 |
| Qualified Home | 35,361 |

WHY 질문:

```text
Home에 진입한 뒤 최소한의 탐색 행동을 시작한 사용자는
왜 View Item까지 이어지지 않는가?
```

Route 수치:

| Route Segment | Sessions | Share of Qualified Home |
|---|---:|---:|
| home/other exploration -> no view_item | 17,711 | 50.09% |
| item_list only -> view_item | 8,425 | 23.83% |
| item_list only -> no view_item | 6,937 | 19.62% |

시각화:

| 유형 | 내용 | 상태 | 데이터 |
|---|---|---|---|
| Split tree | Home Total -> No-exploration / Qualified | 신규 제작 | `sql/analysis/02_home_discovery_routes.sql` |
| Horizontal bar | Qualified route segment share | 신규 제작 | `sql/analysis/02_home_discovery_routes.sql` |

발표 포인트:

```text
Qualified는 실험 대상이 아니라 WHY 진단용 사후 세그먼트다.
```

## 8. 원인 진단: 왜 View Item까지 이어지지 않는가

핵심 메시지:

```text
Source, device, 단순 이탈, 비상품 목적만으로는
View Item 미도달을 충분히 설명하기 어려웠다.
```

WHY 후보:

| Candidate | Diagnostic Signal |
|---|---|
| Source issue | 큰 국소 문제로 보기 어려움 |
| Device issue | 큰 국소 문제로 보기 어려움 |
| Simple bounce | scroll 87.78%로 설명 약함 |
| Non-product intent | moved_to_other_non_item_page 2,016으로 일부만 설명 |
| Discovery selection gap | view_promotion 43.12%, select_promotion 0.10% |

시각화:

| 유형 | 내용 | 상태 | 데이터 |
|---|---|---|---|
| Evidence matrix | WHY 후보별 지표와 판단 | 신규 제작 | `sql/analysis/03_home_discovery_why.sql` |
| Bar chart | scroll/view_promotion/select_promotion 발생률 | 신규 제작 | `sql/analysis/03_home_discovery_why.sql` |

발표 포인트:

```text
관측 데이터는 원인을 확정하지 않고,
가장 설명력 있는 WHY candidate를 좁히는 데 사용한다.
```

## 9. 제품 가설: Discovery 진입점 강화

핵심 메시지:

```text
관측된 WHY 후보를 제품 가설과 실험 질문으로 변환했다.
```

흐름:

```text
Observed Evidence
promotion exposure 높음
selection 낮음
selected session에서 item_list/view_item 도달률 높음

-> WHY Candidate
Discovery exposure -> selection conversion 부족

-> Product Hypothesis
Home discovery entry point의 명확성/매력도를 높이면
Item List 진입과 View Item 도달이 증가할 것이다.

-> Causal Validation
A/B Test
```

시각화:

| 유형 | 내용 | 상태 |
|---|---|---|
| Flow diagram | Evidence -> WHY -> Product Hypothesis -> A/B Test | 신규 제작 |

발표 포인트:

```text
데이터로 UI 문제가 확정된 것이 아니라,
검증 가능한 causal question으로 변환한 것이다.
```

## 10. 실험 설계: A/B 테스트 구조

핵심 메시지:

```text
A/B Test는 Qualified가 아니라
treatment 이전에 정의 가능한 Home Landing 전체를 ITT로 분석한다.
```

실험 설계:

| 항목 | 정의 |
|---|---|
| Eligibility Unit | NAU first session with Home Landing |
| Randomization Unit | anonymous_id |
| Analysis Unit | eligible Home Landing first session |
| Analysis Principle | ITT, all eligible sessions included |

Metric hierarchy:

| Role | Metric |
|---|---|
| Primary | Home -> Item List Rate |
| Key Secondary | Home -> View Item Rate |
| Guardrail | Item List -> View Item Rate |
| Downstream | Purchase Rate / Revenue per Session |

시각화:

| 유형 | 내용 | 상태 |
|---|---|---|
| Metric ladder | Primary -> Secondary -> Guardrail -> Downstream | 신규 제작 |

발표 포인트:

```text
Qualified Home은 사후 행동으로 정의되므로 실험 eligibility로 사용하지 않는다.
```

## 11. 실험 결과: 가상 데이터 기반 효과 검정

핵심 메시지:

```text
Synthetic A/B test에서 Home discovery entry point 강화는
초기 discovery 행동을 유의하게 개선했다.
```

Sample size:

| 항목 | 값 |
|---|---:|
| Baseline Primary Rate | 36.04% |
| MDE | +3.50%p |
| Alpha | 0.05, one-sided |
| Power | 80% |
| Required Sample | 2,372 / variant |
| Simulation Sample | 24,000 / variant |

결과:

| Metric | Control | Treatment | Lift | 95% CI | p-value |
|---|---:|---:|---:|---:|---:|
| Home -> Item List Rate | 35.73% | 39.73% | +3.99%p | [+3.13, +4.86%p] | < 0.001 |
| Home -> View Item Rate | 20.14% | 22.68% | +2.54%p | [+1.81, +3.28%p] | < 0.001 |
| Item List -> View Item Rate | 56.37% | 57.10% | +0.73%p | [-0.71, +2.18%p] | pass |

시각화:

| 유형 | 내용 | 상태 | 데이터 |
|---|---|---|---|
| Bar chart with CI | Control vs Treatment for primary/key secondary/guardrail | 신규 제작 | `outputs/ab_tests/home_discovery_ab_test_summary.csv` |

발표 포인트:

```text
Required sample은 MDE 검출 최소 기준이고,
24,000 per variant는 4주 Home Landing traffic scale을 반영한 simulation setting이다.
```

## 12. 매출 기회 추정: Modeled Revenue Opportunity

핵심 메시지:

```text
초기 discovery 행동 개선이 기존 downstream 전환율로 이어진다면,
전체 주 매출 기준 약 +2.3%의 modeled opportunity가 있다.
```

계산:

```text
Average Weekly Revenue = $49,477.5
Weekly Home Landing eligible sessions = 46,923 / 4 = 11,731
Home -> View Item lift = +2.54%p

Additional View Item
= 11,731 x 2.54%p
= 약 298 / week

Modeled incremental revenue
= 298 x 5.1% x $75
= 약 $1,140 / week

Weekly Revenue impact
= $1,140 / $49,477.5
= 약 +2.3%
```

Impact assumption:

```text
Incremental View Item users are assumed to retain
the observed downstream View Item -> Purchase rate
and Revenue per Purchase.

따라서 이 수치는 실제 revenue uplift 검정값이 아니라
directional modeled revenue opportunity다.
```

시각화:

| 유형 | 내용 | 상태 |
|---|---|---|
| Waterfall | View Item lift -> additional purchase -> revenue opportunity -> weekly revenue % | 신규 제작 |

발표 포인트:

```text
매출 효과를 직접 검증했다고 말하지 않고,
행동 uplift를 business goal로 환산한 modeled opportunity로 표현한다.
```

## 시각화 제작 우선순위

| 우선순위 | Slide | 필요한 그래프 |
|---:|---|---|
| 1 | 6 | Home Landing reach funnel |
| 2 | 7 | Home split tree + route segment bar |
| 3 | 8 | WHY evidence matrix + event rate bar |
| 4 | 11 | A/B result bar with CI |
| 5 | 12 | Modeled revenue opportunity waterfall |
| 6 | 1, 2, 9, 10 | 흐름/구조 다이어그램 |

기존 그래프 재사용:

| Slide | 파일 |
|---|---|
| 3 | `outputs/figures/main_period_weekly_revenue_decomposition_small_multiples.png` |
| 4 | `outputs/figures/main_period_segment_opportunity.png` |
| 5 | `outputs/figures/main_period_first_session_funnel_by_cohort.png` |
