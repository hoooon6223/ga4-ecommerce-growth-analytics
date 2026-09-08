# Portfolio Defense Notes

## 목적

이 문서는 포트폴리오를 만들면서 생길 수 있는 의문과 그에 대한 방어 논리를 정리하는 메모다.

모든 예상 질문을 미리 작성하지 않고, 프로젝트를 진행하면서 실제로 의문이 생긴 항목만 추가한다.

## Q1. 왜 첫 방문 구매 전환을 분석 초점으로 잡았는가?

### 문제 제기

매출을 높이기 위해 유입 확대, 재방문 유도, 객단가 개선 등 여러 방향이 가능한데,
왜 첫 방문 구매 전환을 분석 초점으로 잡았는가?

### 방어 논리

GA4 Merchandise Store는 브랜드 굿즈/기념품 성격의 상품을 판매하는 이커머스에 가깝다.

이런 비즈니스에서 매출은 최종 후행 지표지만, 매출만 보면 방문자가 부족한 문제인지,
방문자는 있지만 상품을 발견하지 못하는 문제인지,
상품은 봤지만 구매로 이어지지 않는 문제인지 구분하기 어렵다.

따라서 본 프로젝트에서는 Weekly Revenue를 `WAU x Weekly Buyer CVR x ARPPU`로 분해해
방문 규모, 구매 전환 효율, 구매자당 매출로 나누어 확인했다.

그중 GA4 행동로그는 사용자의 첫 방문, 상품 조회, 장바구니, 체크아웃, 구매 이벤트를 관측할 수 있으므로
구매 전환 과정의 병목을 분석하기에 적합하다.

실제 데이터에서도 주요 분석 기간의 Active User-Weeks 중 NAU는 90.4%로 가장 큰 비중을 차지했고, Buyer CVR은 1.63%로 EAU 7.32%, RAU 8.09%보다 낮게 관측되었다.

이에 따라 본 분석은 NAU의 first-session 경험에서 상품 탐색과 구매 고려로 전환되는 과정에 어떤 병목이 있는지 확인하고, 초기 상품 발견 행동을 개선할 수 있는 실험 가설을 도출하는 것을 목표로 한다.

### 표현 시 주의사항

이 주장은 다른 성장 레버가 중요하지 않다는 의미가 아니다.

현재 프로젝트에서는 상품 특성과 관측 데이터 구조를 고려했을 때,
행동로그로 직접 관측하고 실험 가설로 연결하기 좋은 첫 방문 구매 전환을 우선 분석 대상으로 설정했다는 의미다.

또한 "반복 구매 주기가 길다"는 것은 데이터에서 직접 검증한 사실이 아니라 상품 특성에 기반한 비즈니스 가정이므로, 포트폴리오에서는 "가능성이 있다", "판단했다"처럼 단정하지 않는 표현을 사용한다.

## Q2. 왜 Weekly Buyer CVR 개선을 우선 분석 대상으로 잡았는가?

### 문제 제기

주별 매출은 `WAU x Weekly Buyer CVR x ARPPU`로 분해할 수 있다.

주별 방문 사용자 수를 늘리거나 구매자당 매출을 높이는 방향도 가능한데, 왜 Weekly Buyer CVR 개선을 먼저 보는가?

### 방어 논리

WAU, Weekly Buyer CVR, ARPPU는 모두 주별 매출 성장 레버가 될 수 있다.

다만 WAU 확대는 보통 추가 유입 또는 재방문 유도 비용을 수반한다. 전환 효율이 낮은 상태에서 유입만 늘리면 추가 방문자가 구매자로 전환되지 못해 비효율이 커질 수 있다.

따라서 추가 유입 확대 전에, 현재 유입된 사용자가 첫 방문에서 상품을 발견하고 구매 고려 단계로 진입하고 있는지 먼저 점검할 필요가 있다.

또한 ARPPU 개선은 가격, 할인, 번들, 무료배송 기준, 추천 상품 구성 등 상품/가격 정책을 직접 건드리는 전략과 연결된다.

이런 전략은 단기 매출을 높일 수 있지만, 가격 민감도, 구매 장벽, 사용자 경험, 전환율에 부정적인 영향을 줄 수 있다.

반면 Weekly Buyer CVR 개선은 이미 유입된 사용자를 구매자로 전환시키는 접근이다.

실제 데이터에서도 주요 분석 기간의 NAU는 Active User-Weeks의 90.4%를 차지하지만, Buyer CVR은 1.63%로 낮게 관측되었다.

따라서 본 분석은 주별 매출 성장 관점에서 신규 사용자의 구매 전환 가능성을 높이는 것을 우선 분석 범위로 설정했다.

### 표현 시 주의사항

본 프로젝트에서는 현재 데이터와 비즈니스 맥락상, 유입 확대나 가격/상품 정책 변경보다 구매 여정의 전환 병목을 먼저 확인하는 것이 더 직접적인 접근이라고 판단했다.

## Q3. 매출 구조는 유저 기준인데, 왜 퍼널은 세션 기준으로 보는가?

### 문제 제기

주별 매출을 `WAU x Weekly Buyer CVR x ARPPU`로 분해했다면, 퍼널도 user 기준으로 봐야 하는 것 아닌가?

### 방어 논리

상위 매출 구조는 사람을 구매자로 전환시키는 관점에서 weekly user-level로 정의했다.

하지만 본 프로젝트에서 개선하려는 문제는 신규 사용자의 첫 방문 경험이다. 홈 랜딩 이후 상품을 발견하고, 상품 상세를 보고, 장바구니와 체크아웃으로 이동하는 흐름은 한 번의 방문 안에서 발생하는 UX 흐름에 가깝다.

user-level funnel로 보면 여러 세션에 걸친 행동이 섞일 수 있다. 예를 들어 첫 세션에서 상품을 보고 며칠 뒤 다른 세션에서 구매한 사용자를 하나의 퍼널 통과자로 보면, 첫 방문 홈 경험의 병목을 해석하기 어려워진다.

따라서 본 분석에서는 상위 KPI는 user-level로 분해하되, 병목 확인은 신규 사용자의 first-session behavior를 session-level funnel로 진행한다.

또한 Session CVR과 Weekly Buyer CVR은 같은 지표가 아니다. 다만 신규 사용자의 첫 세션은 구매자로 전환되는 첫 접점이므로, first-session purchase rate 개선은 Weekly Buyer CVR 개선 가능성과 연결된다고 보았다.

### 표현 시 주의사항

`Session CVR이 오르면 Weekly Buyer CVR도 오른다`처럼 1:1 관계로 단정하지 않는다.

포트폴리오에서는 `first-session purchase rate 개선은 신규 사용자의 Weekly Buyer CVR 개선으로 이어질 가능성이 있다`처럼 가능성과 검증 대상으로 표현한다.

## Q3-1. A/B Test의 실험 단위와 분석 단위를 왜 다르게 두었는가?

### 문제 제기

분석 대상은 NAU Home Landing first session인데, 왜 Randomization Unit은 session이 아니라 anonymous_id인가?

### 방어 논리

실험 eligibility는 treatment 이전에 판단 가능한 NAU Home Landing first session으로 정의한다.

Qualified Home Landing은 사용자가 Home에 들어온 뒤 scroll/search/item_list/view_item 여부를 보고 사후적으로 정의한 분석 세그먼트다.
따라서 이를 실험 eligibility로 사용하면 treatment가 바꾼 행동으로 모집단을 다시 고르는 post-treatment selection 문제가 생길 수 있다.

하지만 실제 제품 실험에서는 같은 사용자가 이후 다시 방문하거나 다른 주에 다시 eligible 상태가 될 수 있다.

만약 session 기준으로 무작위 배정하면 동일 사용자가 한 번은 Control, 다른 한 번은 Treatment를 경험할 수 있어 UX가 섞이고 treatment effect 해석이 흐려질 수 있다.

따라서 배정은 `anonymous_id` 기준으로 고정하고, 분석은 eligible first session 단위로 수행한다.

```text
Eligibility Unit = NAU first session with Home Landing
Randomization Unit = anonymous_id
Analysis Unit = eligible Home Landing first session
```

### 표현 시 주의사항

`분석 단위가 session이므로 session randomization을 했다`고 말하지 않는다.

포트폴리오에서는 `노출 eligibility와 분석은 first session 단위지만, 사용자 경험 일관성을 위해 variant 배정은 anonymous_id 기준으로 고정했다`고 설명한다.

## Q4. 왜 2020-11-23부터 2020-12-20까지를 주요 분석 기간으로 설정했는가?

### 문제 제기

전체 데이터가 더 있는데 왜 특정 4주를 주요 분석 기간으로 두는가?

### 방어 논리

본 분석의 목적은 주별 매출 성장 관점에서 구매 전환율 개선 기회를 찾는 것이다.

이를 위해서는 NAU, EAU, RAU처럼 이전 방문 이력을 사용하는 active user segment가 안정적으로 분류될 수 있어야 한다.

`2020-11-23`부터 `2020-12-20`까지의 4주는 관측 초반 warm-up 구간 이후에 위치해 있어, prior activity를 활용한 segment 비교가 가능하다.

또한 4주 단위는 주별 매출, WAU, Weekly Buyer CVR, ARPPU를 비교하면서도 지나치게 긴 기간의 구조 변화가 섞이는 것을 줄일 수 있는 기준 기간으로 적절하다고 판단했다.

따라서 본 프로젝트에서는 해당 4주를 주요 분석 기간으로 두고, 기간 밖의 데이터는 전체 흐름과 지표 안정성을 확인하는 보조 자료로 사용한다.

### 표현 시 주의사항

이 기간 설정은 특정 기간만 임의로 선택해 결론을 만들기 위한 것이 아니다.

포트폴리오에서는 `주별 active user segment를 비교할 수 있는 prior activity가 확보된 이후의 4주를 주요 분석 기간으로 설정했다`고 설명한다.

## Q5. 왜 NAU Buyer CVR 개선을 우선 분석 대상으로 보았는가?

### 문제 제기

EAU/RAU의 Buyer CVR이 NAU보다 높은데, 왜 NAU Buyer CVR을 우선 분석 대상으로 보았는가?

### 방어 논리

주요 분석 기간에서 NAU는 WAU의 90.4%를 차지했다. EAU는 5.7%, RAU는 3.9%였다.

EAU와 RAU는 Buyer CVR이 각각 7.32%, 8.09%로 높지만, 절대 사용자 규모는 작다.

반면 NAU는 Buyer CVR이 1.63%로 낮지만 대상 규모가 크다.

따라서 NAU는 이미 많은 사용자가 유입되고 있으나 구매 전환 효율이 낮은 cohort로 해석할 수 있다.

또한 본 프로젝트는 GA4 행동로그를 기반으로 상품 발견과 구매 전환 경험에서 개선 기회를 찾는 것이 목적이다.
NAU의 first-session behavior는 landing, search, scroll, view_item, add_to_cart, checkout, purchase 이벤트로 관측할 수 있어
퍼널 분석과 A/B Test 가설로 연결하기 좋다.

따라서 본 프로젝트에서는 NAU Buyer CVR 개선을 우선 분석 대상으로 설정했다.

### 표현 시 주의사항

`EAU/RAU보다 NAU가 더 중요하다` 또는 `신규 유입이 기존 사용자 관리보다 낫다`처럼 표현하지 않는다.

포트폴리오에서는 `NAU는 규모가 크지만 Buyer CVR이 낮고, 행동로그로 first-session 전환 병목을 직접 관측할 수 있어 우선 분석 대상으로 설정했다`처럼 표현한다.

## Q6. 왜 Qualified funnel/deep dive에서 homepage no-action 세션을 제외했는가?

### 문제 제기

홈에 들어와 아무 행동 없이 이탈한 사용자도 active user인데, 왜 Qualified funnel/맥락 분석에서는 제외하는가?

### 방어 논리

전체 사용자 규모와 주별 Active User 구성은 방문 기준 Active User로 확인한다.

따라서 WAU, NAU/EAU/RAU 구성, Weekly Buyer CVR 평가에서는 homepage no-action 세션을 임의로 제거하지 않는다.

다만 본 프로젝트의 후속 분석 목적은 첫 방문자의 상품 발견 경험과 구매 전환 개선 가능성을 확인하는 것이다.

홈에 진입했지만 page view 1회 외에 스크롤, 검색, 상품 선택, 상품 조회, 장바구니, 체크아웃, 구매가 모두 관측되지 않은 세션은 상품 탐색 의도가 거의 드러나지 않은 즉시 이탈 세션에 가깝다.

이 세션을 상품 발견 경험 deep dive의 분모에 그대로 포함하면, 실제로 탐색 가능성이 있었던 사용자와 낮은 의도 또는 우연 유입 사용자가 섞여 퍼널 병목 해석이 흐려질 수 있다.

따라서 전체 first-session funnel은 원본 기준으로 먼저 확인하고, NAU를 타겟으로 좁힌 이후의 source/search/scroll/landing deep dive에서만 homepage no-action first session을 제외한 `Qualified NAU`를 사용했다.

```text
Qualified NAU First Sessions
= NAU user-week first session 중 homepage no-action first session을 제외한 deep dive 분석 대상
```

주요 분석 기간 기준 NAU homepage no-action 규모는 아래와 같다.

| Segment | First Sessions | Homepage No-action | Qualified NAU First Sessions | No-action Share |
|---|---:|---:|---:|---:|
| NAU | 95,490 | 8,425 | 87,065 | 8.82% |

따라서 이후 source/search/scroll/landing context deep dive는 Qualified NAU first-session 모집단을 중심으로 진행한다.

### 표현 시 주의사항

`no-action 사용자는 가치가 없다`처럼 표현하지 않는다.

포트폴리오에서는 `전체 규모와 전체 퍼널은 원본 기준으로 먼저 확인하고, NAU를 타겟으로 좁힌 뒤 상품 발견 경험 개선 가능성을 보는 deep dive에서는 즉시 이탈 성격의 homepage no-action 세션을 NAU 분석 모집단에서 제외했다`고 설명한다.

또한 no-action 제외 후 전환율이 높아지는 것은 성과 개선이 아니라 모집단 재정의의 결과이므로, 제외 전후 수치를 직접 성과처럼 비교하지 않는다.

## Q7. A/B Test에서 왜 Purchase나 Revenue를 성공 기준으로 두지 않았는가?

### 문제 제기

Business Goal이 주별 매출 성장이라면, 왜 A/B Test의 primary metric을 Purchase Rate나 Revenue per Session으로 두지 않았는가?

### 방어 논리

이 실험은 매출 전체를 한 번에 검증하는 실험이 아니라, 앞선 분석에서 좁힌 초기 discovery 병목을 검증하는 실험이다.

03 WHY 분석에서 확인한 핵심 문제 후보는 Home landing에서 상품 discovery 요소의 노출은 발생하지만 실제 선택 행동으로 이어지는 비율이 낮다는 점이었다.

따라서 Treatment의 직접 목표는 사용자를 상품 탐색 경로로 더 잘 진입시키는 것이다.

이에 맞춰 Primary Metric은 `Home -> Item List Rate`, Key Secondary는 `Home -> View Item Rate`로 둔다.

Purchase Rate와 Revenue per Session은 Business Goal과 연결되는 downstream metric이지만, 초기 discovery 변경만으로 단기 실험에서 충분한 구매/매출 효과가 통계적으로 검출되지 않을 수 있다.

따라서 downstream은 방향성을 확인하되, 실험 성공 판정의 핵심 지표로 사용하지 않는다.

### 표현 시 주의사항

`A/B Test로 매출 성장을 입증했다`고 말하지 않는다.

포트폴리오에서는 `매출 성장이라는 Business Goal 아래에서 초기 discovery 행동 레버의 causal validation을 수행했다`고 표현한다.

## Q8. 왜 24,000 eligible first sessions per variant를 사용했는가?

### 문제 제기

Synthetic experiment result에서 Control/Treatment 각각 24,000개가 등장하는데, 왜 이 숫자를 사용했는가?

### 방어 논리

Primary metric인 Home -> Item List Rate의 baseline은 36.04%이고, MDE는 +3.50%p로 설정했다.

alpha 0.05, power 80%, one-sided two-proportion z-test 기준으로 필요한 최소 샘플은 약 2,372 eligible first sessions per variant다.

다만 시뮬레이션에서는 주요 분석 기간 4주의 Home Landing 규모를 재현하기 위해 variant당 24,000개를 사용했다.

주요 분석 기간의 Home Landing은 46,923개이므로 50:50 배정 시 variant당 약 23,462개가 된다.

따라서 24,000은 최소 필요 샘플 수가 아니라, 관측된 4주 eligible traffic scale에 맞춘 simulation size다.

### 표현 시 주의사항

`24,000이 sample size calculation 결과다`라고 말하지 않는다.

포트폴리오에서는 `sample size requirement는 약 2,372 per variant이고, 24,000 per variant는 4주 Home Landing traffic 규모를 반영한 simulation setting`이라고 구분한다.
