# GA4 이커머스 매출 성장 분석

GA4 ecommerce public dataset을 활용해 **주별 매출 성장**이라는 비즈니스 목표를 행동로그 분석과 제품 실험 설계로 연결한 데이터 분석 포트폴리오입니다.

단순 EDA에서 끝내지 않고, raw event log를 분석 가능한 mart로 모델링한 뒤 `Business Goal -> Revenue Structure -> WHO -> WHERE -> WHY -> Product Hypothesis -> A/B Test -> Revenue Opportunity` 흐름으로 문제를 좁혔습니다.

## 최종 산출물

| Output | Path |
|---|---|
| 분석 문서 | `docs/analysis_notes/` |
| 지표 정의 | `docs/metric_definitions.md` |
| 마트 정의 | `docs/mart_data_dictionary.md` |
| 코드 인벤토리 | `docs/code_inventory.md` |
| 최종 분석 SQL | `sql/analysis/` |
| A/B Test SQL | `sql/ab_tests/` |

## 프로젝트 질문

```text
주별 매출 성장을 위해 어떤 사용자 세그먼트와 전환 구간을 우선 개선해야 하는가?
```

본 프로젝트는 주별 매출을 아래와 같이 분해했습니다.

```text
Weekly Revenue = WAU x Weekly Buyer CVR x ARPPU
```

이 분해는 단순 프레임워크가 아니라 매출을 구성하는 수학적 identity입니다. 이 중 GA4 행동로그로 제품 경험을 직접 진단하고 실험 가설로 연결하기 좋은 `Weekly Buyer CVR`을 분석 scope로 설정했습니다.

## 데이터

BigQuery public dataset:

```sql
`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
```

분석용 BigQuery dataset:

```sql
`bigquery-457902.ga4_ops_bi`
```

전체 데이터 기간:

```text
2020-11-01 to 2021-01-31
```

주요 분석 기간:

```text
2020-11-23 to 2020-12-20
```

주요 분석 기간은 NAU/EAU/RAU를 비교할 수 있는 prior activity가 확보된 이후의 4주로 설정했습니다.

## 왜 Weekly인가

Daily는 요일과 트래픽 변동 노이즈가 커서 user segment와 구매 전환율을 안정적으로 해석하기 어렵습니다.

Monthly는 샘플 데이터 기간상 관측치가 적어 cohort/funnel 비교가 둔해집니다.

Weekly는 `WAU`, `Weekly Buyer CVR`, `ARPPU`를 안정적으로 비교하면서, 후속 A/B test의 traffic sizing과 duration planning으로 연결하기 좋은 단위입니다.

## 데이터 마트

GA4 raw event log는 nested field와 event-level grain 때문에 바로 지표를 계산하면 중복과 grain 혼동이 생기기 쉽습니다. 따라서 분석 전 mart를 먼저 구성했습니다.

```text
Raw GA4 Events
  -> base_f_event_wide
  -> base_f_order_items
  -> core_f_sessions
  -> core_f_orders
  -> core_d_items
```

| Table | Grain | Purpose |
|---|---|---|
| `base_f_event_wide` | 1 row = 1 event | GA4 event_params를 wide하게 펼친 event fact |
| `base_f_order_items` | 1 row = 1 purchase event x 1 item | 구매 이벤트 안의 item-level fact |
| `core_f_sessions` | 1 row = 1 session | 세션 단위 행동 및 유입 요약 |
| `core_f_orders` | 1 row = 1 purchase event | purchase event 기준 order fact |
| `core_d_items` | 1 row = 1 item_id | 관측된 상품 dimension |

주의할 점:

```text
purchase_revenue는 order-level revenue입니다.
item grain 분석에서는 base_f_order_items.item_revenue를 사용합니다.
```

## 핵심 분석 흐름

1. GA4 raw event log를 분석 가능한 base/core mart로 모델링
2. Weekly Revenue를 `WAU x Weekly Buyer CVR x ARPPU`로 분해
3. WAU를 NAU/EAU/RAU로 나누어 user-week segment별 규모와 구매 전환율 비교
4. NAU first-session sequential funnel에서 초기 상품 상세 진입 병목 확인
5. Home Landing NAU를 deep dive 대상으로 설정
6. Qualified Home을 진단용 세그먼트로 분리해 Home -> View Item 이전 행동 경로 분석
7. WHY 후보를 source/device/bounce/non-product/discovery selection 관점에서 검정
8. Discovery entry point 강화 제품 가설로 연결
9. 가상 데이터 기반 A/B test 설계와 평가 파이프라인 검정
10. 행동 metric 개선을 modeled revenue opportunity로 환산

## 주요 결과

### 1. NAU가 가장 큰 분석 대상이었다

주요 분석 기간의 Active User-Weeks 기준:

| Segment | Share | Buyer CVR |
|---|---:|---:|
| NAU | 90.4% | 1.63% |
| EAU | 5.7% | 7.32% |
| RAU | 3.9% | 8.09% |

Merchandise Store는 상품 구매 목적의 이커머스이므로 신규/첫 방문 경험이 중요한 서비스 맥락입니다.
이번 데이터에서도 NAU가 가장 큰 user-week pool로 관측되었고, 첫 세션 행동로그로 제품 경험을 진단해 실험 가설로 연결하기 좋은 scope였기 때문에 NAU를 선택했습니다.

### 2. NAU의 병목은 첫 상품 상세 진입에서 크게 나타났다

First-session sequential funnel 기준:

| Segment | View Item Reach | Overall Purchase |
|---|---:|---:|
| NAU | 21.28% | 0.75% |
| EAU | 30.31% | 2.34% |
| RAU | 40.69% | 3.80% |

퍼널은 같은 first session 안에서 `event_seq` 순서를 강제해 계산했습니다.

```text
view_item_seq < add_to_cart_seq < begin_checkout_seq < purchase_seq
```

### 3. Home Landing은 큰 기회 영역이었다

Home Landing NAU first session 전체 기준:

| Metric | Sessions | Rate |
|---|---:|---:|
| Home Landing | 46,923 | 100.00% |
| Reached Item List | 16,909 | 36.04% |
| Reached View Item | 9,711 | 20.70% |
| Cart after View Item | 3,516 | 36.21% |

Home에서 View Item으로 가는 경로는 item_list, search, direct, other 등 여러 갈래가 있으므로, item_list를 메인 퍼널 단계로 강제하지 않고 route segment로 분해했습니다.

### 4. WHY 후보는 Discovery 선택 전환 부족으로 좁혔다

Qualified Home에서 가장 큰 미전환 풀은 `home/other exploration -> no view_item` 세그먼트였습니다.

WHY 후보를 source, device, 단순 이탈, 비상품 목적, discovery selection 관점에서 확인한 결과, 가장 설득력 있는 후보는 아래였습니다.

```text
Home에서 상품 discovery 요소는 노출되지만,
실제 선택 행동으로 이어지는 비율이 낮다.
```

관측 근거:

```text
Target segment = home/other exploration -> no_view_item
n = 17,711 sessions
```

| Event | Session Share |
|---|---:|
| scroll | 87.78% |
| view_promotion | 43.12% |
| select_promotion | 0.10% |

이 결과는 원인 확정이 아니라, A/B test로 검증할 WHY/HOW 후보를 좁힌 것입니다.

### 5. A/B Test는 Home Landing 전체 ITT로 설계했다

분석 단계에서는 Qualified Home을 사후 진단 세그먼트로 사용했습니다. 하지만 실험에서는 treatment 이후 행동으로 eligibility를 정의하면 편향이 생길 수 있으므로, A/B test는 treatment 이전에 판단 가능한 전체 Home Landing을 대상으로 설계했습니다.

| 항목 | 정의 |
|---|---|
| Eligibility Unit | NAU first session with Home Landing |
| Randomization Unit | `anonymous_id` |
| Analysis Unit | eligible Home Landing first session |
| Analysis Principle | ITT, all eligible sessions included |

실험 지표:

| 역할 | 지표 |
|---|---|
| Primary | Home -> Item List Rate |
| Key Secondary | Home -> View Item Rate |
| Guardrail | Item List -> View Item Rate |
| Downstream | Purchase Rate, Revenue per Session |

## A/B Test Simulation

실제 실험 로그가 없기 때문에, A/B test는 관측 baseline을 기반으로 synthetic data를 생성해 설계와 평가 방식을 시뮬레이션했습니다.

Sample size 설계:

| 항목 | 값 |
|---|---:|
| Baseline Home -> Item List Rate | 36.04% |
| MDE | +3.50%p |
| alpha | 0.05 |
| power | 80% |
| Required sample | 2,372 / variant |
| Simulation sample | 24,000 / variant |

가상 데이터 기반 실험 결과:

| Metric | Control | Treatment | Lift | p-value |
|---|---:|---:|---:|---:|
| Home -> Item List Rate | 35.73% | 39.73% | +3.99%p | < .001 |
| Home -> View Item Rate | 20.14% | 22.68% | +2.54%p | < .001 |
| Item List -> View Item Rate | 56.37% | 57.10% | +0.73%p | Guardrail pass |

해석:

```text
Synthetic A/B에서 사전에 설정한 효과가 분석 파이프라인에서
기대 방향으로 검출되는지 확인했다.

실제 제품 효과는 production A/B test에서 검증해야 한다.
Purchase/Revenue downstream metric은 방향성 확인 및
modeled opportunity 계산에만 사용한다.
```

## Modeled Revenue Opportunity

Synthetic A/B test의 Home -> View Item lift를 기존 downstream baseline에 연결하면 다음과 같은 기회 규모가 추정됩니다.

```text
Weekly Eligible NAU Home First Sessions = 46,923 / 4 = 11,731
Home -> View Item lift = +2.54%p

Additional View Item
= 11,731 x 2.54%p
= 298 / week

Revenue Opportunity
= 298 x 5.1% x $75
= 약 $1,140 / week

Weekly Revenue Share
= $1,140 / $49,477.5
= 약 2.3%
```

주의:

```text
위 수치는 실제 매출 uplift가 아니라 directional modeled opportunity입니다.
새롭게 View Item에 도달한 사용자가 기존 View Item 사용자와 동일한 downstream purchase rate와 revenue per purchase를 가진다는 가정이 포함됩니다.
```

## 폴더 구조

```text
.
├── README.md
├── docs/
│   ├── analysis_notes/
│   ├── code_inventory.md
│   ├── event_dictionary.md
│   ├── mart_data_dictionary.md
│   ├── metric_definitions.md
│   └── learning/
├── outputs/
│   ├── ab_tests/
│   ├── data/
│   └── figures/
├── scripts/
└── sql/
    ├── ab_tests/
    ├── analysis/
    ├── base_marts/
    ├── core_marts/
    └── eda/
```

## 재현 방법

### 1. BigQuery mart 생성

```text
sql/base_marts/00_build_base_marts.sql
sql/core_marts/00_build_core_marts.sql
```

### 2. 최종 분석 재현

```text
sql/analysis/01_main_period_revenue_cohort_funnel.sql
sql/analysis/02_home_discovery_routes.sql
sql/analysis/03_home_discovery_why.sql
```

### 3. A/B test simulation 재현

```bash
python3 scripts/generate_home_discovery_ab_test.py
```

생성되는 주요 output:

```text
outputs/ab_tests/home_discovery_ab_test_summary.csv
outputs/ab_tests/home_discovery_ab_test_power_plan.csv
```

`home_discovery_ab_test_synthetic.csv`는 row-level synthetic data이므로 GitHub에는 포함하지 않고, 스크립트로 재생성합니다.

## 참고 문서

| Document | Purpose |
|---|---|
| `docs/analysis_notes/01_revenue_growth_flow.md` | Revenue decomposition, WHO, first-session funnel |
| `docs/analysis_notes/02_home_discovery_funnel.md` | Home Landing route segment 분석 |
| `docs/analysis_notes/03_home_discovery_why_hypothesis.md` | WHY 후보 검정과 제품 가설 |
| `docs/analysis_notes/04_ab_test_design_and_evaluation.md` | A/B test 설계, sample size, simulated result |
| `docs/metric_definitions.md` | 지표 정의와 분자/분모 |
| `docs/mart_data_dictionary.md` | mart grain과 주요 컬럼 |
| `docs/code_inventory.md` | SQL, script, output 인벤토리 |

## 해석 시 주의사항

```text
1. anonymous_id는 GA4 user_pseudo_id 기반 익명 식별자이며 실제 회원 ID가 아닙니다.
2. 4주 합산값은 unique user가 아니라 Active User-Weeks 기준입니다.
3. Qualified Home은 분석용 사후 행동 세그먼트이며 A/B eligibility가 아닙니다.
4. A/B test는 실제 운영 실험이 아니라 synthetic data 기반 시뮬레이션입니다.
5. Modeled Revenue Opportunity는 방향성 추정치이며 실제 매출 uplift로 해석하지 않습니다.
```
