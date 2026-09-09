# 01. 주별 매출 성장 분석 흐름

## 프로젝트 제목

```text
주별 매출 성장을 위한 행동로그 기반 구매 전환 개선 분석
```

## Business Goal

```text
주별 매출 성장
```

## 분석 질문

```text
주별 매출 성장을 위해 어떤 active user cohort를 우선 개선해야 하며,
그 cohort의 어떤 전환 레버를 높일 수 있는가?
```

## 분석 스코프 결정

전체 데이터 기간은 아래와 같다.

```text
2020-11-01 to 2021-01-31
```

다만 본 분석은 특정 기간의 매출 변동 원인을 규명하는 방식이 아니라, 주별 매출 성장 관점에서 구매 전환 개선 기회를 찾는 방식으로 진행한다.

전체 기간을 그대로 사용하면 후반부의 큰 매출 변동을 설명하는 흐름으로 분석이 흘러갈 수 있다.

따라서 주요 분석 기간은 아래 4주로 설정한다.

```text
2020-11-23 to 2020-12-20
```

이 기간은 관측 초반 warm-up 이후라 NAU/EAU/RAU 구분에 필요한 prior activity가 확보되어 있고, 주별 active user segment와 구매 전환율을 비교하기에 적합한 기준 구간으로 사용한다.

전체 기간 그래프는 데이터 구조와 변동성을 확인하는 보조 자료로만 사용하고, 본 분석의 핵심 해석과 퍼널 분석은 주요 분석 기간을 기준으로 진행한다.

분석 단위를 week로 둔 이유:

```text
Daily는 요일/트래픽 변동 노이즈가 커서 user segment와 구매 전환율을 해석하기 어렵고,
Monthly는 샘플 데이터 기간상 관측치가 적어 cohort/funnel 비교가 둔해진다.

Weekly는 WAU, Weekly Buyer CVR, ARPPU를 안정적으로 비교하면서
제품 실험의 planning/duration과도 연결하기 좋은 단위다.
```

## Growth Formula

본 프로젝트에서는 주별 매출을 아래 구조로 분해한다.

```text
Weekly Revenue
= WAU
x Weekly Buyer CVR
x ARPPU
```

| 구성요소 | 의미 |
|---|---|
| WAU | 해당 주에 1회 이상 방문한 익명 사용자 수 |
| Weekly Buyer CVR | 주별 active user 중 구매자가 된 비율 |
| ARPPU | 주별 구매 사용자 1명당 평균 매출 |

상위 매출 구조는 user-level weekly metric으로 본다.

퍼널은 첫 방문 경험의 흐름을 보기 위해 session-level로 분석한다.

## Cohort Operational Definition

주별 active user segment는 `anonymous_id x week` 단위로 정의한다.

```text
Active User-Week
= 특정 week에 1회 이상 session을 발생시킨 anonymous_id
```

각 active user-week는 이전 active week 이력을 기준으로 아래 세 segment 중 하나에만 속한다.

| Segment | 조작적 정의 | 해석 |
|---|---|---|
| NAU | `first_active_week = current_week` | 관측 기간 내 해당 주에 처음 active가 된 사용자 |
| EAU | `previous_active_week = current_week - 1 week` | 직전 주에도 active였고 이번 주에도 active인 사용자 |
| RAU | `first_active_week < current_week` AND `previous_active_week < current_week - 1 week` | 과거 active 이력은 있으나 직전 주에는 inactive였다가 돌아온 사용자 |

주의:

```text
NAU는 실제 가입 신규 고객이 아니라 GA4 anonymous_id 기준 observed new active user다.

이후 first-session funnel은 먼저 user-week를 NAU/EAU/RAU로 분류한 뒤,
각 user-week에서 가장 먼저 발생한 session을 선택해 분석한다.
```

## 분석 흐름

본 분석은 아래 순서로 진행한다.

```text
1. Business Goal
   주별 매출 성장

2. Revenue Decomposition
   Weekly Revenue = WAU x Weekly Buyer CVR x ARPPU

3. Weekly Active User Cohort Composition
   WAU를 NAU / EAU / RAU로 분해

4. WHO
   어떤 active user cohort를 우선 개선할 것인가?

5. Segment Evaluation
   규모, Buyer CVR, Revenue Share, ARPPU 비교

6. Focus Rationale
   비즈니스 맥락과 행동로그 관측 가능성을 기준으로 전환 레버 선택

7. Focus Decision
   NAU Buyer CVR 개선을 우선 분석 대상으로 설정

8. Funnel Analysis
   전체 NAU/EAU/RAU first-session sequential funnel 확인

9. Behavior Context
   NAU 중 가장 큰 초기 접점인 home landing의 상품 발견 흐름 확인

10. A/B Test Hypothesis
   home landing 신규 사용자의 상품 상세 진입을 높이는 실험 가설 도출
```

## Q1. 주별 매출은 어떤 구조로 움직였는가?

주요 분석 기간:

```text
2020-11-23 to 2020-12-20
```

전체 주별 지표:

| Week Start | Weekly Revenue | WAU | Weekly Buyer CVR | ARPPU |
|---|---:|---:|---:|---:|
| 2020-11-23 | 47,897 | 22,126 | 2.25% | 96.37 |
| 2020-11-30 | 42,872 | 24,534 | 2.33% | 74.95 |
| 2020-12-07 | 59,865 | 31,498 | 2.34% | 81.23 |
| 2020-12-14 | 47,276 | 27,421 | 1.91% | 90.39 |

관찰:

```text
1. 2020-12-07 주차는 WAU가 크게 증가하면서 주별 매출도 가장 높았다.
2. Weekly Buyer CVR은 2.25% -> 2.33% -> 2.34%로 유사하다가 2020-12-14 주차에 1.91%로 낮아졌다.
3. ARPPU는 주차별 변동이 존재하며, 특히 2020-11-30 주차에는 WAU가 증가했지만 ARPPU가 낮아 매출이 감소했다.
```

해석:

```text
주별 매출은 WAU, Weekly Buyer CVR, ARPPU가 함께 움직인 결과다.

다만 본 프로젝트의 목적은 가격/주문 금액 정책보다 행동로그 기반 구매 전환 개선 기회를 찾는 것이므로,
이후 분석에서는 Weekly Buyer CVR과 연결되는 사용자 세그먼트와 first-session funnel을 우선 확인한다.
```

사용 그래프:

```text
outputs/figures/main_period_weekly_revenue_decomposition_small_multiples.svg
```

## Q2. Weekly Active User는 어떤 cohort로 구성되어 있는가?

WAU를 NAU, EAU, RAU로 나눈 뒤 주요 분석 기간 4주를 합산하면 아래와 같다.

주의:

```text
아래 표의 Active User-Weeks는 4주간 unique user 수가 아니라,
주별 active user 관측치의 합이다.

동일 사용자가 여러 주에 active하면 여러 user-week로 집계될 수 있다.
Buyer User-Weeks도 주별 구매 사용자 관측치의 합이다.
```

| Segment | Active User-Weeks | Share | Buyer User-Weeks | Buyer Share | Revenue | Revenue Share | Buyer CVR | ARPPU |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| NAU | 95,490 | 90.4% | 1,559 | 66.9% | 118,957 | 60.1% | 1.63% | 76.30 |
| EAU | 5,985 | 5.7% | 438 | 18.8% | 47,715 | 24.1% | 7.32% | 108.94 |
| RAU | 4,104 | 3.9% | 332 | 14.3% | 31,238 | 15.8% | 8.09% | 94.09 |

관찰:

```text
1. NAU는 Active User-Week 기준 가장 큰 user-week pool로 관측되었다.
2. 하지만 NAU의 Buyer CVR은 1.63%로 EAU 7.32%, RAU 8.09%보다 낮다.
3. EAU/RAU는 규모는 작지만 구매 전환 효율과 구매자당 매출이 높다.
```

해석:

```text
EAU/RAU는 이미 구매 의도나 재방문 성향이 더 강한 사용자일 가능성이 있다.

반면 NAU는 규모가 크지만 구매 전환율이 낮기 때문에,
주별 매출 성장 관점에서 NAU의 구매 전환 개선 여지를 우선 확인할 필요가 있다.
```

사용 그래프:

```text
outputs/figures/main_period_segment_opportunity.svg
outputs/figures/wau_composition_main_period.svg
```

## Q3. 왜 NAU Buyer CVR 개선을 우선 볼 수 있는가?

NAU를 우선 개선 대상으로 선택하더라도, NAU를 성장시키는 방법은 다시 나눠볼 수 있다.

```text
NAU Revenue
= NAU
x NAU Buyer CVR
x NAU ARPPU
```

가능한 선택지는 아래와 같다.

| 선택지 | 의미 | 고려사항 |
|---|---|---|
| NAU 규모 확대 | 신규 active user 유입을 더 늘림 | 추가 유입 비용이 필요할 수 있음 |
| NAU Buyer CVR 개선 | 이미 유입된 NAU가 구매자로 전환되는 비율을 높임 | 행동로그 기반 퍼널 분석과 직접 연결 |
| NAU ARPPU 개선 | NAU 구매자당 매출을 높임 | 가격, 번들, 업셀링 등 상품/가격 정책과 연결될 수 있음 |

NAU 규모 확대는 추가 유입 비용을 수반할 수 있고, 전환 효율이 낮은 상태에서 유입만 늘리면 매출 효율이 제한될 수 있다.

NAU ARPPU 개선은 가격, 번들, 업셀링, 무료배송 기준 등 상품/가격 정책 변화와 연결되며, 구매 장벽이나 사용자 경험에 영향을 줄 수 있다.

또한 GA4 Merchandise Store는 브랜드 굿즈/기념품 성격의 상품을 판매하는 이커머스에 가깝다.
이런 비즈니스에서 매출은 중요한 후행 지표지만, 매출만 보면 방문 규모 문제인지,
상품 발견과 구매 고려로 이어지지 않는 문제인지, 구매자당 매출 문제인지 구분하기 어렵다.

따라서 Weekly Revenue를 `WAU x Weekly Buyer CVR x ARPPU`로 분해해
방문 규모, 구매 전환 효율, 구매자당 매출이라는 레버로 나누어 확인했다.

해석 기준:

```text
본 프로젝트는 가격/상품 정책 최적화보다
GA4 행동로그를 활용해 사용자의 상품 발견과 구매 전환 경험에서
개선 기회를 찾는 것을 목표로 한다.

따라서 유입 확대나 객단가 개선보다,
이미 유입된 사용자가 첫 방문에서 상품을 발견하고
구매 고려 단계로 진입하는지 먼저 확인한다.
```

Merchandise Store는 상품 구매 목적의 이커머스이므로 신규/첫 방문 경험이 중요한 서비스 맥락이다.
이번 데이터에서도 NAU가 가장 큰 user-week pool로 관측되었고, Buyer CVR은 1.63%로 낮았다.

따라서 본 분석에서는 현재 유입된 NAU가 구매자로 전환되는 과정,
즉 NAU Buyer CVR 개선 기회를 우선 확인한다.

주의:

```text
이는 다른 성장 레버보다 NAU 전환이 더 낫다는 전략적 우열 판단이 아니다.
현재 데이터와 프로젝트 목적상 행동로그로 직접 관측하고
실험 가설로 연결하기 좋은 레버가 NAU Buyer CVR이기 때문에 우선 분석하는 것이다.
```

## Q4. 전체 first-session funnel에서 어느 구간에 전환 개선 여지가 있는가?

NAU Buyer CVR 개선을 우선 분석 대상으로 설정한 뒤, 먼저 전체 NAU/EAU/RAU의 주간 첫 세션에서 구매 전환 흐름이 어떻게 진행되는지 확인했다.

퍼널은 아래 순서로 정의한다.

```text
Session
-> View Item
-> Add to Cart
-> Begin Checkout
-> Purchase
```

분석 단위:

```text
1 row = active user x week first session
```

Sequential Funnel Rule:

```text
1. Grain = active user-week first session
2. 같은 first session 안에서만 행동을 추적한다.
3. base_f_event_wide.event_seq 기준으로 이벤트 발생 순서를 강제한다.
4. 다음 단계는 이전 단계 이후에 발생한 경우에만 도달로 인정한다.

view_item_seq
< add_to_cart_seq
< begin_checkout_seq
< purchase_seq
```

주의:

```text
first session은 관측 기간 전체의 첫 세션이 아니라,
해당 사용자가 해당 주에 발생시킨 첫 번째 세션이다.

이 단계에서는 no-action 세션을 제외하지 않고, 전체 first-session funnel을 기준으로 원래 전환 구조를 확인한다.
```

주요 분석 기간 합산 결과:

| Segment | First Sessions | View Item | Add to Cart | Begin Checkout | Purchase | View Item Reach | View to Cart | Cart to Checkout | Checkout to Purchase | Funnel Completion Rate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| NAU | 95,490 | 20,319 | 5,233 | 1,697 | 714 | 21.3% | 25.8% | 32.4% | 42.1% | 0.75% |
| EAU | 5,985 | 1,814 | 516 | 203 | 140 | 30.3% | 28.4% | 39.3% | 69.0% | 2.34% |
| RAU | 4,104 | 1,670 | 546 | 229 | 156 | 40.7% | 32.7% | 41.9% | 68.1% | 3.80% |

관찰:

```text
1. NAU의 First-session Funnel Completion Rate는 0.75%로 EAU 2.34%, RAU 3.80%보다 낮다.
2. NAU는 첫 세션에서 View Item까지 도달하는 비율이 21.3%로 EAU/RAU 대비 낮다.
3. View Item 이후 Add to Cart, Checkout, Purchase까지의 단계별 전환율도 EAU/RAU보다 전반적으로 낮다.
4. 특히 Checkout to Purchase는 NAU 42.1%, EAU 69.0%, RAU 68.1%로 차이가 크다.
```

해석:

```text
전체 first-session funnel 기준으로 NAU는 첫 세션에서 상품 상세 조회까지 도달하는 비율이 낮고,
상품을 본 이후에도 장바구니와 구매 완료로 이어지는 전환 효율이 낮다.

따라서 NAU Buyer CVR 개선을 위해서는 첫 세션에서 상품을 발견하고,
상품 상세 조회 이후 구매 고려 단계로 넘어가도록 만드는 경험을 확인할 필요가 있다.
```

사용 그래프:

```text
outputs/figures/main_period_first_session_funnel_by_cohort.svg
```

사용 데이터:

```text
outputs/data/segment_week_first_session_funnel_main_period.csv
```

## Q4-1. Strict Homepage Bounce-like Session은 어느 정도인가?

전체 first-session funnel을 확인한 뒤 NAU를 타겟으로 좁혔고,
상품 발견 경험 deep dive에 앞서 가장 좁은 기준의 homepage bounce-like session 규모를 확인했다.

정의:

```text
Strict Homepage Bounce-like Session
= NAU user-week first session
AND landing_path = '/'
AND page_view_count <= 1
AND 주요 탐색/전환 행동이 모두 없음
```

주요 분석 기간 합산 결과:

| Segment | First Sessions | Strict Homepage Bounce-like Sessions | Remaining NAU First Sessions | Share |
|---|---:|---:|---:|---:|
| NAU | 95,490 | 8,425 | 87,065 | 8.82% |

해석:

```text
Strict Homepage Bounce-like Session은 '/' 홈에 진입했지만 스크롤, 검색, 상품 조회, 상품 선택 등
최소한의 탐색 행동이 관측되지 않은 세션이다.

이 세션은 전체 사용자 구조와 전체 first-session funnel에서는 포함하되,
NAU 상품 발견 경험 개선 가능성을 보기 위한 deep dive에서는 별도로 분리한다.

이후 02_home_discovery_funnel.md에서는 home landing 정의를 '/', '/store.html', Home title까지 넓혀
Home No-exploration Session을 별도로 정의한다. 따라서 01의 8,425와 02의 11,562는 서로 다른 모집단 기준의 지표다.
```

사용 데이터:

```text
outputs/data/main_period_nau_home_no_action_sizing.csv
```

## Q5. NAU 전환 개선은 어디서 더 구체화할 것인가?

전체 NAU first-session funnel에서 View Item 도달률은 21.3%로 낮았다.

상품 상세 조회는 신규 사용자가 실제 상품을 평가하기 시작하는 지점이므로,
이후 분석은 퍼널 후반보다 first session의 초기 상품 발견 흐름에 초점을 둔다.

분석 방향:

```text
NAU Buyer CVR 개선
-> NAU first-session 상품 발견 흐름 확인
-> 가장 큰 초기 접점인 home landing deep dive
-> Home Landing -> View Item 도달 개선 기회 탐색
```

홈 랜딩을 우선 보는 이유:

```text
1. home landing은 NAU first session에서 가장 큰 초기 접점이다.
2. View Item은 상품 고려가 시작되는 행동이므로 초기 discovery 개선과 직접 연결된다.
3. item_list/search는 최종 목표가 아니라 View Item 도달을 설명하는 보조 경로로 볼 수 있다.
4. 따라서 메인 퍼널은 Home Landing -> View Item -> Add to Cart -> Begin Checkout -> Purchase로 두고,
   Home -> View Item 사이의 route segment를 별도로 분해한다.
```

이후 상세 분석은 별도 문서에서 이어간다.

```text
docs/analysis_notes/02_home_discovery_funnel.md
```
