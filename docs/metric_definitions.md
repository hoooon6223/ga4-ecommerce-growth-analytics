# Metric Definition Dictionary

## 문서 목적

이 문서는 GA4 ecommerce 분석에서 사용할 지표 정의서다.

분석자가 같은 지표를 매번 다른 방식으로 계산하지 않도록, 지표의 비즈니스 의미와 계산 기준을 한곳에 모아두는 문서다.

현재 단계에서는 분석에 활용할 가능성이 높은 기본 지표를 먼저 정리한다.

EDA와 문제 정의가 진행되면서 최종 사용할 지표의 분자, 분모, 필터, 해석 기준을 계속 업데이트한다.

## Documentation Rules

```text
1. 모든 지표는 분자, 분모, 기준 테이블, 계산 단위를 명시한다.
2. User, Session, Order, Event, Item grain을 혼용하지 않는다.
3. Revenue, Order Count, Session Count는 JOIN으로 중복 집계되지 않도록 주의한다.
4. 관측적 차이와 인과적 해석을 구분한다.
5. 실험 지표는 primary, secondary, guardrail, diagnostic 역할을 구분해 정의한다.
6. 정의가 변경되면 해당 지표를 사용하는 downstream 분석도 함께 확인한다.
```

## 기본 분석 단위

| 분석 단위 | 정의 | 기준 테이블 | 주의사항 |
|---|---|---|---|
| Event | GA4 이벤트 1개 | base_f_event_wide | 사용자 행동 로그의 최소 단위 |
| Session | 분석용 session_id 1개 | core_f_sessions | session_id는 anonymous_id + ga_session_id로 생성 |
| User | 분석 기간 내 anonymous_id 1개 | core_f_sessions / core_f_orders | 실제 회원 ID가 아니라 GA4 user_pseudo_id 기반 익명 식별자 |
| User-Week | anonymous_id x week 1개 | derived from core_f_sessions | 주요 분석 기간 합산 시 동일 사용자가 여러 주에 반복 집계될 수 있음 |
| Order | GA4 purchase 이벤트 1개 | core_f_orders | backend order DB와 1:1 검증 불가 |
| Order Item | purchase 이벤트 x 상품 1개 | base_f_order_items | item grain과 order grain 혼용 주의 |
| Item | 관측된 item_id 1개 | core_d_items | 실제 product master가 아니라 observed item dimension |
| Eligible First Session | 실험 또는 deep dive 조건을 만족한 user-week first session | derived from core_f_sessions + base_f_event_wide | 분석 단위는 session이지만 실험 배정 단위는 user일 수 있음 |

## 매출 성장 구조

본 프로젝트의 Business Goal은 주별 매출 성장이다.

주별 매출은 방문 유저 규모, 구매자 전환율, 구매자당 매출로 분해한다.

```text
Weekly Revenue
= WAU
x Weekly Buyer CVR
x ARPPU
```

## 주요 분석 기간

본 분석의 주요 분석 기간은 `2020-11-23`부터 `2020-12-20`까지의 4주로 정의한다.

해당 기간은 주별 active user segment를 비교할 수 있는 prior activity가 확보된 이후이며, 주별 매출 성장과 구매 전환율 개선 기회를 탐색하기 위한 기준 기간으로 사용한다.

주의:

```text
주요 분석 기간은 문제를 확정하기 위한 관찰 구간이다.
기간 밖의 데이터는 전체 흐름과 지표 안정성을 확인하는 보조 자료로 사용한다.
```

| 구성요소 | 정의 | 계산식 | 기준 Mart | 주의사항 |
|---|---|---|---|---|
| Weekly Revenue | 주별 구매 매출 | SUM(purchase_revenue) | core_f_orders | purchase event 기준 매출 |
| WAU | 해당 주 1회 이상 방문한 익명 사용자 | COUNT(DISTINCT anonymous_id) | core_f_sessions | 구매 의도나 상품 탐색이 아니라 방문 기준 active |
| Weekly Buyer Users | 해당 주 1회 이상 구매한 익명 사용자 | COUNT(DISTINCT anonymous_id) | core_f_orders | 동일 사용자가 여러 주문해도 1명 |
| Weekly Buyer CVR | 주별 방문 사용자 중 구매 사용자 비율 | Weekly Buyer Users / WAU | core_f_sessions + core_f_orders | Session CVR과 다른 user-level 전환율 |
| ARPPU | 주별 구매 사용자 1명당 평균 매출 | Weekly Revenue / Weekly Buyer Users | core_f_orders | AOV와 다름. 여러 주문을 한 구매자의 매출이 합산됨 |

주의:

```text
상위 매출 구조는 weekly user-level로 정의하지만,
구매 퍼널 병목은 first-session experience를 보기 위해 session-level로 확인한다.

Session CVR 상승이 Weekly Buyer CVR 상승과 항상 1:1로 같지는 않다.
다만 신규 사용자의 첫 세션은 구매자로 전환되는 첫 접점이므로,
first-session purchase rate 개선은 Weekly Buyer CVR 개선 가능성과 연결된다.
```

## 주별 Active User 코호트 구성 정의

주별 매출 구조를 해석하기 위해 WAU를 이전 방문 이력 기준의 NAU, EAU, RAU로 분해한다.

본 분석에서 말하는 주별 코호트 구성은 특정 가입 cohort를 시간에 따라 추적하는 분석이 아니라, 각 주의 active user를 lifecycle segment로 나눈 구성 분석을 의미한다.

```text
Active User
= 해당 주에 1회 이상 세션을 발생시킨 anonymous_id

Active User-Week
= anonymous_id x week 단위의 active user 관측치
```

| Segment | 정의 | 계산 기준 | 주의사항 |
|---|---|---|---|
| NAU | 관측 기간 내 해당 주에 처음 active가 된 사용자 | first_active_week = current_week | 실제 신규 고객이 아니라 observed new active user |
| EAU | 직전 주에도 active였고 이번 주에도 active인 사용자 | previous_active_week = current_week - 1 week | 기존/유지 active user 성격 |
| RAU | 과거 active 이력이 있지만 직전 주에는 inactive였다가 이번 주에 다시 active가 된 사용자 | first_active_week < current_week AND previous_active_week < current_week - 1 week | returned active user 성격 |

주의:

```text
anonymous_id는 실제 회원 ID가 아니므로 주별 코호트 구성도 익명 식별자 기준이다.
주요 분석 기간을 합산한 segment 표의 사용자 수는 4주 unique user가 아니라 active user-week 합계다.
동일 anonymous_id가 여러 주에 active하면 여러 user-week로 집계될 수 있다.
관측 기간 초반에는 이전 활동 이력이 부족하므로 NAU가 과대계상되고 EAU/RAU가 과소계상될 수 있다.
따라서 cohort 해석에서는 초반 warm-up 기간을 제외하거나 별도 표시한다.
```

## 기본 지표 정의

`Status`는 계산식의 확정 수준을 나타낸다.

| Status | 의미 |
|---|---|
| Confirmed | 현재 mart grain과 계산 기준이 명확한 기본 지표 |
| Candidate | 분석 문제에 따라 핵심 지표로 사용할 수 있는 후보 지표 |
| Draft | 계산 로직 또는 해석 기준을 추가 검증해야 하는 지표 |

| 지표명 | Status | 비즈니스 의미 | 계산식 | 분자 | 분모 | Grain | 기준 Mart | 필터/조건 | 주의사항 |
|---|---|---|---|---|---|---|---|---|---|
| Sessions | Confirmed | 전체 방문 규모 | COUNT(*) | - | - | Session | core_f_sessions | 분석 기간 | 1 row = 1 session 전제 |
| First Sessions | Confirmed | user-week별 첫 방문 경험 규모 | COUNT(*) | - | - | User x Week First Session | core_f_sessions | `ROW_NUMBER() OVER (PARTITION BY week_start, anonymous_id ORDER BY session_start_at, session_id) = 1` | first-session funnel의 분모 |
| Users | Confirmed | 고유 익명 사용자 규모 | COUNT(DISTINCT anonymous_id) | - | - | User | core_f_sessions | 분석 기간 | 실제 회원 ID 아님 |
| Active Users | Confirmed | 분석 기간 내 활성 익명 사용자 수 | COUNT(DISTINCT anonymous_id) | - | - | User | core_f_sessions | 분석 기간 | 방문 기준 active user |
| Qualified NAU First Sessions | Confirmed | NAU 전환 deep dive용 first-session 관측치 | COUNT(*) | - | - | User x Week First Session | core_f_sessions + base_f_event_wide | NAU 중 분석 목적별 no-exploration first session 제외 | 전체 WAU/NAU 정의와 구분 |
| Qualified Home Landing Sessions | Confirmed | Home landing 초반 discovery 분석 대상 세션 수 | COUNT(*) | - | - | User x Week First Session | core_f_sessions + base_f_event_wide | Home landing NAU first session 중 Home No-exploration Session 제외 | 전체 home landing baseline과 구분 |
| Active User-Weeks | Confirmed | 주별 active user 관측치 합 | COUNT(*) | - | - | User x Week | derived from core_f_sessions | user-week 단위 cohort table | 여러 주에 active한 동일 anonymous_id는 여러 번 집계될 수 있음 |
| Buyer User-Weeks | Confirmed | 주별 구매 사용자 관측치 합 | COUNT(*) | - | - | User x Week | derived from core_f_sessions + core_f_orders | user-week 단위 cohort table | 4주 unique buyer가 아니라 weekly buyer 관측치 합 |
| WAU | Confirmed | 주별 활성 익명 사용자 수 | COUNT(DISTINCT anonymous_id) | - | - | User x Week | core_f_sessions | 주 단위 분석 기간 | Weekly Revenue decomposition의 첫 구성요소 |
| Active User-Week Share | Confirmed | 주요 분석 기간 user-week 중 segment 비중 | Segment Active User-Weeks / Total Active User-Weeks | Segment Active User-Weeks | Total Active User-Weeks | User x Week | derived from core_f_sessions | 4주 unique user share가 아님 |
| Buyer User-Week Share | Confirmed | 주요 분석 기간 buyer user-week 중 segment 비중 | Segment Buyer User-Weeks / Total Buyer User-Weeks | Segment Buyer User-Weeks | Total Buyer User-Weeks | User x Week | derived from core_f_sessions + core_f_orders | 4주 unique buyer share가 아님 |
| Revenue Share | Confirmed | 주요 분석 기간 revenue 중 segment 기여 비중 | Segment Revenue / Total Revenue | Segment Revenue | Total Revenue | Segment x Period | core_f_orders | segment attribution은 order가 발생한 user-week 기준 |
| Buyer Users | Confirmed | 분석 기간 내 구매 익명 사용자 수 | COUNT(DISTINCT anonymous_id) | - | - | User | core_f_orders | 분석 기간 | 주문 수가 아니라 구매자 수 |
| Buyer CVR | Candidate | 활성 사용자 중 구매자로 전환된 비율 | Buyer Users / Active Users | COUNT(DISTINCT buyer anonymous_id) | COUNT(DISTINCT active anonymous_id) | User | core_f_sessions + core_f_orders | 분석 기간 | Session CVR과 구분 |
| Weekly Buyer CVR | Candidate | 주별 방문 사용자 중 구매자로 전환된 비율 | Weekly Buyer Users / WAU | COUNT(DISTINCT weekly buyer anonymous_id) | COUNT(DISTINCT weekly active anonymous_id) | User x Week | core_f_sessions + core_f_orders | 주 단위 분석 기간 | Session CVR과 구분 |
| ARPPU | Candidate | 구매 사용자 1명당 평균 매출 | Revenue / Buyer Users | SUM(purchase_revenue) | COUNT(DISTINCT buyer anonymous_id) | User | core_f_orders | 분석 기간 | AOV와 구분 |
| Purchase Sessions | Confirmed | 구매가 발생한 세션 수 | COUNTIF(has_purchase) | - | - | Session | core_f_sessions | 분석 기간 | purchase event 기반 |
| Orders | Confirmed | 주문 수 | COUNT(*) | - | - | Order | core_f_orders | 분석 기간 | GA4 purchase event 기준 |
| Revenue | Confirmed | 전체 매출 | SUM(purchase_revenue) | - | - | Order | core_f_orders | 분석 기간 | 전체 매출 기준 |
| Item Revenue | Confirmed | 상품 row 기준 매출 | SUM(item_revenue) | - | - | Order Item | base_f_order_items | 분석 기간 | 상품/카테고리 분석 기준 |
| Session CVR | Candidate | 세션 기준 구매 전환율 | Purchase Sessions / Sessions | COUNTIF(has_purchase) | COUNT(*) | Session | core_f_sessions | 분석 기간 | 퍼널 분석용 지표. Buyer CVR과 구분 |
| AOV | Candidate | 주문 1건당 평균 매출 | Revenue / Orders | SUM(purchase_revenue) | COUNT(*) | Order | core_f_orders | 분석 기간 | purchase session 기준으로 나누지 않음 |
| Revenue per Session | Candidate | 세션당 매출 | Revenue / Sessions | SUM(purchase_revenue) | COUNT(*) | Session | core_f_orders + core_f_sessions | 분석 기간 | order와 session grain JOIN 주의 |
| Revenue per Active User | Candidate | active user 1명당 평균 매출 | Revenue / Active Users | SUM(purchase_revenue) | COUNT(DISTINCT active anonymous_id) | User | core_f_sessions + core_f_orders | 분석 기간 | ARPPU와 다름. 비구매자도 분모에 포함 |
| View Item Sessions | Confirmed | 상품 조회 세션 수 | COUNTIF(has_view_item) | - | - | Session | core_f_sessions | 분석 기간 | event count 아님 |
| Add to Cart Sessions | Confirmed | 장바구니 담기 세션 수 | COUNTIF(has_add_to_cart) | - | - | Session | core_f_sessions | 분석 기간 | event count 아님 |
| Checkout Sessions | Confirmed | 체크아웃 시작 세션 수 | COUNTIF(has_begin_checkout) | - | - | Session | core_f_sessions | 분석 기간 | event count 아님 |
| Search Sessions | Confirmed | 검색 결과 조회 세션 수 | COUNTIF(has_search) | - | - | Session | core_f_sessions | 분석 기간 | view_search_results 이벤트 기준 |
| Scroll Sessions | Confirmed | 스크롤 발생 세션 수 | COUNTIF(has_scroll) | - | - | Session | core_f_sessions | 분석 기간 | engagement 원인으로 단정하지 않음 |

## Funnel 지표 정의

본 프로젝트의 primary funnel은 `Segment-week First-session Sequential Funnel`로 정의한다.

전체 segment 비교에서는 NAU/EAU/RAU의 주간 첫 세션을 그대로 확인한다.
이후 NAU를 타겟으로 좁힌 뒤, NAU 전환 개선 deep dive에서는
분석 목적에 맞는 no-exploration first session을 분리한 `Qualified` 모집단을 사용한다.

```text
분석 모집단
= 전체 segment 비교: 주별 NAU/EAU/RAU active user의 first session
= NAU deep dive: Qualified NAU first session

Grain
= 1 row = 1 active user x week first session

Primary Funnel
= Sequential Funnel
```

### Qualified 분석 모집단 보정

초기 EDA에서는 전체 NAU를 포함해 주별 사용자 구성과 전환 구조를 확인한다.

전체 first-session funnel도 no-action을 제외하지 않고 먼저 확인한다.

다만 NAU를 타겟으로 좁힌 뒤 상품 발견 경험과 전환 개선 가능성을 보는 context deep dive에서는
분석 목적에 맞는 no-exploration first session을 별도로 분리한다.

```text
Homepage No-action First Session
= NAU user-week의 first session
AND landing_path = '/'
AND page_view_count <= 1
AND has_view_item = FALSE
AND has_select_item = FALSE
AND has_add_to_cart = FALSE
AND has_begin_checkout = FALSE
AND has_purchase = FALSE
AND has_search = FALSE
AND has_scroll = FALSE
```

Home landing deep dive에서는 더 넓은 home landing 기준의 no-exploration을 별도로 사용한다.

```text
Home No-exploration Session
= Home landing NAU user-week first session
AND View Item 미도달
AND Item List 미도달
AND Search 미사용
AND Other Page 미이동
AND 추가 page_view 없음
AND Scroll 없음

Home landing
= landing_path IN ('/', '/store.html')
OR landing_page_title IN ('Home', 'Google Online Store')
```

해석 기준:

```text
이 제외는 전환율을 좋게 보이기 위한 보정이 아니라,
상품 탐색 의도가 거의 관측되지 않은 세션과
상품 탐색 가능성이 있는 세션을 분리하기 위한 모집단 정의다.

따라서 WAU/NAU 구성, Weekly Buyer CVR, 전체 규모 평가, 최초 first-session funnel은 전체 기준으로 보고,
no-action 제외는 전체 세그먼트 비교가 아니라 NAU 타겟 선정 이후의 deep dive 모집단 정의로만 사용한다.

이후 home landing discovery deep dive는 Qualified Home Landing first session 기준으로 진행한다.

Strict Homepage Bounce-like Session과 Home No-exploration Session은 서로 다른 모집단 기준이다.
전자는 landing_path = '/'만 보는 좁은 기준이고,
후자는 home landing 정의를 '/store.html'과 Home title까지 확장한 home discovery 분석 기준이다.
```

정의:

| 개념 | 정의 |
|---|---|
| NAU | 관측 기간 내 해당 주에 처음 active가 된 anonymous_id |
| EAU | 직전 주에도 active였고 이번 주에도 active인 anonymous_id |
| RAU | 과거 active 이력이 있지만 직전 주에는 inactive였다가 이번 주에 다시 active가 된 anonymous_id |
| First Session | 해당 사용자가 해당 주에 발생시킨 첫 번째 session |
| Qualified NAU First Sessions | NAU first session 중 분석 목적별 no-exploration 세션을 제외한 deep dive 모집단 |
| Qualified Home Landing | Home landing NAU first session 중 Home No-exploration Session을 제외한 deep dive 모집단 |
| Strict Homepage Bounce-like Session | landing_path = '/'인 NAU first session 중 주요 탐색/전환 행동이 없는 세션 |
| Home No-exploration Session | Home landing NAU first session 중 상품 발견 경로와 View Item으로 이어지지 않은 무탐색 세션 |
| Sequential Funnel | 한 세션 안에서 이벤트가 정해진 순서대로 발생했는지 확인하는 funnel |

퍼널 분석 단위를 session으로 두는 이유:

```text
본 프로젝트의 상위 KPI는 weekly user-level 매출 구조로 정의하지만,
홈 랜딩 이후 상품 발견과 구매 고려는 한 번의 방문 경험 안에서 발생하는 UX 흐름이다.

user-level funnel은 여러 방문에 걸친 행동이 섞여 방문 경험의 병목을 해석하기 어려우므로,
각 segment의 주별 first-session behavior를 session-level funnel로 확인한다.

NAU를 주요 분석 대상으로 보되, EAU/RAU는 비교 기준으로 함께 확인한다.
```

NAU first-session deep dive에서는 landing bucket별로 시작점이 다르다.
다만 home landing deep dive에서는 `item_list`를 메인 퍼널 단계로 강제하지 않고,
`Home Landing -> View Item` 사이의 route segment로 분해한다.

```text
Landing Bucket
= home_landing
= item_list_landing
= other_landing
```

| Landing Bucket | 정의 | 주요 예시 | 분석 목적 |
|---|---|---|---|
| home_landing | 홈 성격의 페이지로 시작한 NAU first session | `/`, `/store.html` | 홈에서 상품 목록/상품 상세로 넘어가는 discovery 흐름 확인 |
| item_list_landing | 상품 목록, 카테고리, 브랜드, 상품군 성격의 페이지로 시작한 NAU first session | `/Google+Redesign/Apparel`, `/Google+Redesign/Shop+by+Brand/YouTube`, `/Google+Redesign/Apparel/Google+Dino+Game+Tee` | 목록/카테고리 진입 후 상품 상세와 구매 고려로 이어지는 흐름 확인 |
| other_landing | home_landing과 item_list_landing에 속하지 않는 나머지 | FAQ, signin, basket, search 등 | 전체 구성에서는 포함하되 핵심 discovery funnel 해석에서는 보조로 확인 |

현재 과거 GA4 데이터에서는 `/Google+Redesign/...` 하위 경로를 상품 목록/카테고리/상품군 성격의 `item_list_landing`으로 본다.
현재 운영 사이트의 `/product/...` 형태 URL은 상품 상세 페이지 성격이므로 별도 분석 시 `view_item_landing` 후보로 볼 수 있지만,
본 과거 데이터의 primary landing bucket에서는 별도 bucket으로 분리하지 않는다.

### Primary Sequential Funnel Metric

Sequential Funnel은 `base_f_event_wide.event_seq`를 사용해 한 세션 안에서 이벤트 발생 순서를 확인한 뒤 계산한다.

Sequential Funnel Rule:

```text
1. Grain = active user-week first session
2. 같은 first session 안에서만 행동을 추적한다.
3. event_seq 기준 순서를 강제한다.
4. 다음 단계는 이전 단계 이후에 발생한 경우에만 도달로 인정한다.

view_item_seq
< add_to_cart_seq
< begin_checkout_seq
< purchase_seq
```

Landing bucket별 primary sequential funnel:

```text
home_landing
= Home
-> View Item
-> Add to Cart
-> Begin Checkout
-> Purchase

item_list_landing
= Item List
-> View Item
-> Add to Cart
-> Begin Checkout
-> Purchase

other_landing
= 별도 일방향 discovery funnel을 강제하지 않고,
  View Item -> Add to Cart -> Begin Checkout -> Purchase 흐름을 보조로 확인
```

home_landing에서 `item_list`, `search`, `other page`, `direct view_item`은
`Home -> View Item` 사이의 route segment로 사용한다.

```text
Home to View Item Route Segment
= item_list only -> view_item
= item_list -> search -> view_item
= search only -> view_item
= search -> item_list -> view_item
= direct/unknown -> view_item
= other page -> view_item
= home/other exploration -> no view_item
= item_list only -> no view_item
= search only -> no view_item
= item_list + search -> no view_item
```

통과 조건:

| Funnel Step | 한국어 설명 | 통과 조건 | 기준 Mart | 주의사항 |
|---|---|---|---|---|
| Start Session | 세그먼트별 주간 첫 세션 | 해당 segment user의 week first session이 존재 | core_f_sessions | landing bucket별 분모 |
| Home | 홈 진입/도달 | `/`, `/store.html`, Home title 계열 page_view | base_f_event_wide | home_landing funnel의 시작점 |
| Item List | 상품 목록/카테고리/브랜드/상품군 도달 | `/Google+Redesign/...` 계열 page_view | base_f_event_wide | home_landing에서는 route segment, item_list_landing에서는 시작점으로 사용 |
| View Item | 상품 조회 | 이전 step 이후 view_item 이벤트가 1회 이상 존재 | base_f_event_wide | 첫 번째 view_item seq 사용 |
| Add to Cart | 장바구니 담기 | view_item 이후 add_to_cart 이벤트가 1회 이상 존재 | base_f_event_wide | view_item 이전 add_to_cart는 sequential 통과로 보지 않음 |
| Begin Checkout | 체크아웃 시작 | add_to_cart 이후 begin_checkout 이벤트가 1회 이상 존재 | base_f_event_wide | 이전 step 통과 후 발생해야 함 |
| Purchase | 구매 | begin_checkout 이후 purchase 이벤트가 1회 이상 존재 | base_f_event_wide | 이전 step 통과 후 발생해야 함 |

전환율 정의:

| 지표 | 계산식 | 설명 |
|---|---|---|
| Landing Share | Landing Bucket First Sessions / NAU First Sessions | 전체 NAU first session 중 landing bucket 비중 |
| Home to View Item Rate | View Item Sessions / Home Landing Sessions | home_landing 중 상품 상세까지 도달한 비율 |
| Qualified Home to View Item Rate | View Item Sessions / Qualified Home Landing Sessions | no-exploration을 제외한 home discovery deep dive 기준 상품 상세 도달률 |
| Home to Item List Rate | Item List Sessions / Home Landing Sessions | home_landing 중 상품 목록/카테고리로 이동한 비율 |
| Qualified Home to Item List Rate | Item List Sessions / Qualified Home Landing Sessions | no-exploration을 제외한 home discovery deep dive 기준 상품 목록/카테고리 도달률 |
| Item List to View Item Rate | View Item Sessions after Item List / Item List Sessions | 상품 목록/카테고리 이후 상품 조회까지 도달한 비율. route quality guardrail로 사용 |
| View to Cart Rate | Sequential Add to Cart Sessions / View Item Sessions | view_item 이후 add_to_cart까지 도달한 비율 |
| Cart to Checkout Rate | Sequential Checkout Sessions / Sequential Add to Cart Sessions | add_to_cart 이후 begin_checkout까지 도달한 비율 |
| Checkout to Purchase Rate | Sequential Purchase Sessions / Sequential Checkout Sessions | begin_checkout 이후 purchase까지 도달한 비율 |
| Full Sequential Purchase Rate | Sequential Purchase Sessions / Landing Bucket First Sessions | landing bucket별 시작 세션 중 순서대로 구매까지 도달한 비율 |
| First-session Purchase Rate | Purchase Sessions / First Sessions | first-session 기준 구매 전환율. sequential purchase와 reach purchase 중 어떤 기준인지 문서에서 명시 |

주의:

```text
이 퍼널은 user-level Weekly Buyer CVR이 아니라 session-level first-session funnel이다.

Home/Qualified Home -> Item List Rate와 Home/Qualified Home -> View Item Rate는
분모가 전체 Home Landing인지 Qualified Home Landing인지 반드시 함께 표기한다.

02 문서의 deep dive는 Qualified Home Landing 35,361을 분모로 route를 해석하고,
04 A/B test baseline은 Home Landing Total 46,923을 분모로 한다.

다만 NAU의 첫 세션은 신규 사용자가 구매자로 전환될 수 있는 첫 접점이므로,
NAU first-session funnel 개선은 Weekly Buyer CVR 개선 가능성과 연결된다.
```

### 보조 Session Reach Metric

Session Reach Metric은 세션 안에 특정 행동이 1회 이상 있었는지만 보는 보조 확인 지표다.

```text
Reach Funnel
= 순서와 상관없이 각 행동 발생 여부를 보는 funnel
```

Reach Rate 정의:

| 지표 | 계산식 | 설명 |
|---|---|---|
| View Item Reach Rate | View Item Sessions / Sessions | 전체 세션 중 상품 조회 행동이 발생한 세션 비율 |
| Add to Cart Reach Rate | Add to Cart Sessions / Sessions | 전체 세션 중 장바구니 담기 행동이 발생한 세션 비율 |
| Checkout Reach Rate | Checkout Sessions / Sessions | 전체 세션 중 체크아웃 시작 행동이 발생한 세션 비율 |
| Purchase Reach Rate | Purchase Sessions / Sessions | 전체 세션 중 구매 행동이 발생한 세션 비율 |

주의:

```text
has_add_to_cart = TRUE는 장바구니 행동이 있었다는 뜻이다.
view_item 이후 add_to_cart가 발생했다는 뜻은 아니다.

따라서 Reach Funnel에서는 Add to Cart Sessions / View Item Sessions를
View -> Cart 전환율로 해석하지 않는다.
```

## Home Discovery Diagnostic 지표

Home discovery deep dive는 `Qualified Home Landing`을 기준 모집단으로 사용한다.

```text
Qualified Home Landing
= Home landing NAU user-week first session
  - Home No-exploration Session
```

Home discovery route 지표:

| 지표 | 계산식 | 분모 | 해석 기준 |
|---|---|---|---|
| Home Landing Total | COUNT(Home landing NAU first sessions) | - | home landing 전체 baseline |
| Home No-exploration Share | Home No-exploration Sessions / Home Landing Total | Home Landing Total | 상품 탐색 의도가 거의 관측되지 않은 세션 비중 |
| Qualified Home Share | Qualified Home Landing Sessions / Home Landing Total | Home Landing Total | deep dive 대상이 되는 home landing 비중 |
| Route Segment Sessions | COUNT(*) by route_segment | Qualified Home Landing Sessions | Home -> View Item 사이의 행동 경로별 규모 |
| Share of Qualified Home | Route Segment Sessions / Qualified Home Landing Sessions | Qualified Home Landing Sessions | 각 route segment가 개선 pool에서 차지하는 비중 |
| Search Route Share | Search Route Sessions / Search Sessions | Search Sessions | search가 View Item으로 이어지는 경로 구조 |
| Detail Bucket Share | Detail Bucket Sessions / home/other exploration -> no_view_item Sessions | home/other exploration -> no_view_item Sessions | 가장 큰 미전환 pool의 세부 행동 패턴 |

Home to View Item route segment 정의:

| Route Segment | 정의 |
|---|---|
| item_list only -> view_item | item_list page_view 이후 view_item 도달, search는 view_item 이전에 없음 |
| item_list -> search -> view_item | item_list page_view 이후 search, 그 이후 view_item 도달 |
| search -> item_list -> view_item | search 이후 item_list page_view, 그 이후 view_item 도달 |
| search only -> view_item | search 이후 view_item 도달, view_item 이전 item_list 없음 |
| direct/unknown -> view_item | item_list/search/other page 이전에 view_item 도달 |
| other page -> view_item | home/item_list/search 외 page 이동 이후 view_item 도달 |
| home/other exploration -> no view_item | Qualified Home Landing 중 item_list/search/view_item으로 이어지지 않은 홈/기타 탐색 세션 |
| item_list only -> no view_item | item_list에는 도달했지만 view_item 미도달 |
| search only -> no view_item | search는 사용했지만 view_item 미도달 |
| item_list + search -> no view_item | item_list와 search가 모두 있었지만 view_item 미도달 |

Home exploration no-view detail bucket:

| Detail Bucket | 정의 | 해석 |
|---|---|---|
| scroll_only_on_home | 추가 page_view 없이 scroll만 관측 | 홈에서 콘텐츠를 봤지만 상품 발견 경로로 이동하지 않음 |
| home_reloaded_or_store_home_only | home 계열 page_view가 2회 이상이고 item_list/search/view_item 없음 | 홈 계열 탐색에 머묾 |
| moved_to_other_non_item_page | item_list가 아닌 다른 page로 이동했지만 view_item 없음 | signin, basket, FAQ 등 비상품 목적 가능성 |
| other_event_pattern | 위 조건에 속하지 않는 기타 패턴 | 잔여 예외 bucket |

Promotion diagnostic 지표:

| 지표 | 계산식 | 분모 | 해석 기준 |
|---|---|---|---|
| Promotion View Rate | Sessions with view_promotion / Home Landing Sessions | Home Landing Sessions | home에서 discovery 요소 노출이 발생했는지 확인 |
| Promotion Select Rate | Sessions with select_promotion / Home Landing Sessions | Home Landing Sessions | 노출된 discovery 요소가 선택 행동으로 이어지는지 확인 |
| Promotion Selected Share | Promotion Selected Sessions / Home Landing Sessions | Home Landing Sessions | promotion selected 그룹의 규모 |
| Promotion Behavior Share | Sessions by promotion_behavior / Home Landing Sessions | Home Landing Sessions | no view, view no select, selected 세그먼트 구성 |
| Selected Item List Rate | Item List Sessions among promotion selected / Promotion Selected Sessions | Promotion Selected Sessions | promotion 선택 후 item_list 도달률 |
| Selected View Item Rate | View Item Sessions among promotion selected / Promotion Selected Sessions | Promotion Selected Sessions | promotion 선택 후 view_item 도달률 |

주의:

```text
Promotion selection과 item_list/view_item 도달률의 관계는 관측적 관계다.
promotion selection이 구매나 view_item을 인과적으로 증가시켰다고 단정하지 않는다.

WHY 단계에서는 "노출은 있으나 선택 전환이 낮다"는 후보를 좁히는 데 사용하고,
인과 검증은 A/B test 설계에서 수행한다.
```

## 매출 지표 기준

| 지표 | 기준 컬럼 | 기준 Mart | 설명 |
|---|---|---|---|
| 전체 매출 | purchase_revenue | core_f_orders | purchase 이벤트 단위 매출 |
| 상품별 매출 | item_revenue | base_f_order_items | 상품 row 단위 매출 |
| 카테고리별 매출 | item_revenue | base_f_order_items | item_category 기준 상품 매출 합계 |
| 주문당 매출 | purchase_revenue | core_f_orders | order grain의 매출 |
| 구매자당 매출 | purchase_revenue / buyer users | core_f_orders | user grain의 ARPPU |
| 세션당 매출 | purchase_revenue / sessions | core_f_orders + core_f_sessions | 방문 효율성 지표 |

현재 reconciliation:

```text
core_f_orders.purchase_revenue 합계 = 362,165
base_f_order_items.item_revenue 합계 = 362,110
차이 = 55
```

해석:

```text
purchase 이벤트 중 2개는 items row가 없어 item-level fact에 나타나지 않는다.
따라서 전체 매출은 order-level purchase_revenue를 기준으로 보고,
상품/카테고리별 매출은 item-level item_revenue를 기준으로 본다.
```

## 유입 기준 지표

현재 mart의 기본 유입 분석은 `traffic_source`, `traffic_medium`, `traffic_campaign`을 우선 사용한다.

다만 이 컬럼들은 session acquisition 정보라기보다 GA4의 first-user acquisition 정보에 가깝다.

따라서 현재 단계에서는 `Channel`이라는 표현보다 `First-touch Source/Medium/Campaign` 기준으로 해석한다.

| 지표 | 계산식 | 기준 Mart | 설명 |
|---|---|---|---|
| First-touch Source Sessions | COUNT(*) | core_f_sessions | 특정 first-touch source/medium/campaign 조합의 세션 수 |
| First-touch Source Purchase Sessions | COUNTIF(has_purchase) | core_f_sessions | 특정 first-touch 기준에서 구매가 발생한 세션 수 |
| First-touch Source CVR | Purchase Sessions / Sessions | core_f_sessions | first-touch 기준 세션 구매 전환율 |
| First-touch Source Revenue | SUM(purchase_revenue) | core_f_orders | first-touch 기준 주문 매출 |
| First-touch Revenue per Session | Revenue / Sessions | core_f_orders + core_f_sessions | first-touch 기준 세션당 매출 |

보조 확인 컬럼:

```text
event_param_source
event_param_medium
event_param_campaign
```

주의:

```text
traffic_source/medium/campaign은 사용자 최초 유입 정보에 가깝고,
event_param_source/medium/campaign은 이벤트 파라미터 기반 값이다.
두 값은 분석 목적에 따라 차이가 날 수 있으므로 혼용하지 않는다.
```

## 실험 분석 지표

Home discovery 개선 A/B test는 아래 metric hierarchy로 정의한다.

| 개념 | 정의 |
|---|---|
| Eligibility Unit | NAU first session with Home Landing |
| Randomization Unit | anonymous_id |
| Analysis Unit | eligible Home Landing first session |

주의:

```text
Qualified Home Landing은 treatment 이후 행동으로 정의되는 사후 분석 세그먼트이므로
실험 eligibility로 사용하지 않는다.

실험 배정은 anonymous_id 기준으로 고정하고,
NAU의 first Home Landing session 전체를 ITT 기준으로 분석한다.

각 eligible NAU는 하나의 first session만 분석에 기여한다.
```

확정 실험 지표:

| 지표 | 역할 | 계산식 | 해석 기준 |
|---|---|---|---|
| Home -> Item List Rate | Primary | Item List Sessions / Eligible Home Landing First Sessions | discovery pool이 확대되었는지 확인 |
| Home -> View Item Rate | Key Secondary | View Item Sessions / Eligible Home Landing First Sessions | 확대된 discovery pool이 상품 상세 진입까지 이어졌는지 확인 |
| Promotion Select Rate | Diagnostic | Select Promotion Sessions / Eligible First Sessions | 노출된 discovery 요소가 선택 행동으로 이어졌는지 확인 |
| Item List -> View Item Rate | Guardrail | View Item Sessions after Item List / Item List Sessions | 낮은 의도 클릭 증가로 route quality가 훼손되지 않았는지 확인 |
| Purchase Rate | Downstream | Purchase Sessions / Eligible First Sessions | 구매 방향성을 확인하되 단기 성공 판정의 핵심 지표로 사용하지 않음 |
| Revenue per Session | Downstream | Revenue / Eligible First Sessions | 매출 방향성을 확인하되 직접 매출 효과 검증으로 단정하지 않음 |

사전 의사결정 기준:

```text
Primary
= H0: p_T <= p_C
= H1: p_T > p_C
= alpha 0.05 one-sided test

Key Secondary
= Home -> View Item Rate lift와 95% CI 확인

Guardrail
= Item List -> View Item Rate가 Control 대비 -2.00%p 이상 악화되지 않을 것

Downstream
= Purchase Rate와 Revenue per Session은 방향성/CI만 확인
= 실험 성공 판정의 decision-critical metric으로 사용하지 않음
```

Sample size 기준:

```text
Primary baseline = 36.04%
MDE = +3.50%p
alpha = 0.05
power = 80%
required sample = 약 2,372 eligible first sessions per variant
```

실험 통계 지표:

| 지표 | 정의 | 해석 기준 |
|---|---|---|
| Absolute Lift | Treatment Metric - Control Metric | % 지표는 %p로 해석 |
| Relative Lift | Treatment Metric / Control Metric - 1 | Control 대비 상대 변화율 |
| 95% CI | Treatment - Control 차이에 대한 95% 신뢰구간 | effect size의 불확실성 확인 |
| p-value | 귀무가설 하에서 관측된 차이 이상이 나올 확률 | Primary는 one-sided alpha 0.05 기준 |
| MDE | 사전에 탐지하고자 정한 최소 효과 크기 | 본 실험에서는 Home -> Item List Rate +3.50%p |
| Power | 실제 효과가 MDE 이상일 때 실험이 이를 탐지할 확률 | 본 실험에서는 80% |
| Non-inferiority Margin | guardrail에서 허용 가능한 최대 악화폭 | Item List -> View Item Rate -2.00%p |
| SRM Check | variant별 배정 비율이 의도한 비율과 크게 어긋났는지 확인 | 실제 운영 실험에서 tracking/randomization QA로 사용 |
| Required Sample per Variant | 사전 alpha, power, baseline, MDE를 기준으로 필요한 variant별 최소 표본 수 | 실험 duration 산정 기준 |
| Expected Eligible Sessions per Week | 관측 baseline에서 추정한 주당 eligible first session 수 | 실험 예상 소요 기간 계산에 사용 |
| Simulated Traffic Scale | synthetic experiment가 재현한 baseline traffic 기간 규모 | sample size requirement와 구분 |

시뮬레이션 해석 기준:

```text
synthetic A/B test dataset은 실제 실험 로그가 아니라
실험 설계와 평가 방식을 보여주기 위한 산출물이다.

따라서 실험 결과는 "초기 discovery 행동 레버의 causal validation 예시"로 해석하고,
purchase/revenue 개선 효과가 실제로 검증되었다고 단정하지 않는다.
```

## 주요 주의사항

```text
1. anonymous_id는 실제 회원 ID가 아니므로 고객 단위 LTV/CRM 분석에는 한계가 있다.
2. GA4 purchase 이벤트는 backend order와 reconciliation되지 않았다.
3. session_id는 anonymous_id + ga_session_id로 생성한 분석용 key다.
4. item_id는 GA4 purchase log에서 관측된 상품 ID이며 실제 product master와 검증되지 않았다.
5. 상위 매출 구조의 CVR은 weekly user-level Buyer CVR이고, funnel 분석의 CVR은 session-level CVR이다.
6. 전체 매출과 상품별 매출은 기준 grain이 다르므로 같은 쿼리에서 무작정 합산하지 않는다.
```
