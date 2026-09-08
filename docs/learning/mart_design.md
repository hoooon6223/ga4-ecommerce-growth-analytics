# Mart Design Learning

## 목적

이 문서는 GA4 ecommerce 로그를 분석용 mart로 모델링하는 과정에서 배운 점을 정리한 회고 문서다.

단순히 어떤 테이블을 만들었는지가 아니라, 왜 그런 구조로 만들었는지와 어떤 판단 기준이 필요했는지를 기록한다.

## 1. Mart는 많이 만드는 것이 중요한 게 아니다

처음에는 분석에 필요해 보이는 테이블을 여러 개 만들 수 있다고 생각했다.

하지만 실제로는 mart를 많이 만드는 것보다, 어떤 grain과 정의를 재사용 가능한 데이터 자산으로 만들지 판단하는 것이 더 중요하다는 점을 배웠다.

이번 프로젝트에서는 아래처럼 layer를 나누었다.

```text
Raw
-> Base Mart
-> Core Mart
-> Analysis Mart
```

각 layer의 역할은 다르다.

| Layer | 역할 |
|---|---|
| Raw | GA4 원천 로그. 중첩 구조와 key-value 구조가 그대로 존재 |
| Base Mart | raw를 분석 가능한 기본 grain으로 펼친 source-close layer |
| Core Mart | 반복적으로 사용하는 session/order/item 단위를 표준화한 layer |
| Analysis Mart | 특정 분석 질문에 답하기 위해 필요할 때만 만드는 목적형 layer |

중요한 기준은 아래와 같다.

```text
일회성 탐색
-> SQL / CTE

반복 사용 가능성이 있는 로직
-> View 고려

복잡한 계산 + 반복 사용 + 정의 통일 + 성능 필요
-> Analysis Mart 생성
```

따라서 분석할 수 있다는 이유만으로 mart를 만드는 것은 좋지 않다.

## 2. 분석 단위와 Mart 생성은 다르다

분석을 하다 보면 새로운 분석 단위가 필요해질 수 있다.

예를 들어 sequential funnel을 보려면 아래와 같은 단위가 필요할 수 있다.

```text
session_id
funnel_step
step_order
step_reached
```

하지만 이런 분석 단위가 필요하다고 해서 반드시 물리 테이블을 만들어야 하는 것은 아니다.

한두 번 확인하는 EDA라면 CTE로 충분하다.

반복적으로 사용되거나, 대시보드/리포트/공통 지표 정의에 필요해질 때 analysis mart로 승격시키는 것이 더 자연스럽다.

## 3. Grain을 먼저 정해야 한다

Mart 설계에서 가장 중요한 것은 한 행이 무엇을 의미하는지 먼저 정하는 것이다.

이번 프로젝트의 핵심 grain은 아래처럼 정리했다.

| Mart | Grain | 의미 |
|---|---|---|
| base_f_event_wide | 1 row = 1 event | 사용자 행동 로그 1개 |
| base_f_order_items | 1 row = purchase event x item | 구매 이벤트 안의 상품 row 1개 |
| core_f_sessions | 1 row = 1 session | 세션 단위 행동 요약 |
| core_f_orders | 1 row = 1 purchase event | GA4 purchase 이벤트 기준 operational order |
| core_d_items | 1 row = 1 item_id | 관측된 상품 속성 dimension |

Grain이 섞이면 지표가 쉽게 부풀려진다.

특히 아래 개념은 서로 다르게 봐야 한다.

```text
event count != session count
session count != order count
purchase event != backend order
item row != product master
anonymous_id != 실제 회원 ID
```

## 4. 행동 로그에서 행동은 event_name에 있다

GA4 로그에서는 사용자가 어떤 행동을 했는지가 `event_name`에 들어간다.

예를 들면 아래와 같다.

| event_name | 해석 |
|---|---|
| page_view | 페이지 조회 |
| view_item | 상품 조회 |
| add_to_cart | 장바구니 담기 |
| begin_checkout | 체크아웃 시작 |
| purchase | 구매 |
| scroll | 스크롤 |
| click | 링크 클릭 |
| view_search_results | 검색 결과 조회 |

반면 `event_params`는 행동 자체가 아니라 그 행동에 붙은 속성이다.

```text
event_name
= 무엇을 했는가

event_params
= 그 행동의 대상, 맥락, 부가 정보
```

예를 들어 `event_name = click`이라면 `link_url`, `link_domain`, `outbound` 같은 값이 클릭 행동의 세부 정보를 설명한다.

## 5. 로그에 없는 행동은 분석으로 복원할 수 없다

이번 GA4 public dataset은 ecommerce 표준 이벤트 중심이다.

따라서 아래와 같은 큰 행동은 알 수 있다.

```text
상품 조회
장바구니 담기
체크아웃 시작
배송/결제 단계 진입
구매
검색 결과 조회
스크롤
프로모션 조회/선택
```

하지만 아래와 같은 세부 UX 행동은 알기 어렵다.

```text
어떤 버튼을 눌렀는지
어떤 배너를 눌렀는지
리뷰 탭을 열었는지
상품 옵션을 변경했는지
쿠폰 입력창을 눌렀는지
장바구니에서 수량을 바꿨는지
```

이런 행동을 분석하려면 분석 단계에서 억지로 추론하는 것이 아니라, tracking plan을 다시 설계해야 한다.

즉 중요한 교훈은 아래와 같다.

```text
분석하고 싶은 행동이 로그에 없다면,
그것은 분석 문제가 아니라 수집 설계 문제다.
```

## 6. Tracking Plan과 Event Dictionary는 다르다

이번 프로젝트에서 만든 `Event Dictionary`는 이미 수집된 로그를 해석하기 위한 observed dictionary다.

반면 tracking plan은 앞으로 어떤 이벤트를 어떻게 수집할지 정의하는 수집 설계 문서다.

| 문서 | 목적 |
|---|---|
| Tracking Plan | 어떤 이벤트를 언제, 어떤 property와 함께 수집할지 정의 |
| Event Dictionary | 이미 수집된 이벤트와 파라미터를 분석자가 어떻게 해석할지 정리 |

현재 데이터에는 내부 tracking plan이 없기 때문에, 이벤트 이름과 GA4 구조, 실제 관측값을 기준으로 observed event dictionary를 만들었다.

## 7. Order 정의는 신중해야 한다

처음에는 `order_id`를 `session_id`처럼 생각할 수 있었다.

하지만 실제로 한 세션에서 여러 purchase 이벤트가 발생할 수 있음을 확인했다.

```text
한 세션에 여러 order가 있는 세션 = 552개
```

따라서 session_id를 order_id로 사용하는 것은 잘못된 정의가 될 수 있다.

최종적으로는 아래처럼 정의했다.

```text
Operational Order Key = purchase_event_key
order_id = purchase_event_key와 동일
session_id = 주문이 발생한 세션 연결 키
transaction_id = GA4에서 관측된 거래 ID, backend 검증 불가
```

또한 `core_f_orders`는 `base_f_order_items`가 아니라 `base_f_event_wide`의 purchase 이벤트에서 생성하도록 수정했다.

이유는 item row가 없는 purchase 이벤트가 존재했기 때문이다.

```text
base purchase events = 5,692
core_f_orders = 5,692
orders without items = 2
```

Order fact는 purchase 이벤트를 모두 보존하고, item 관련 지표는 `base_f_order_items`를 LEFT JOIN해 보강하는 구조가 더 안전하다.

## 8. Dimension과 Performance Mart는 구분해야 한다

처음에는 `core_d_items`에 상품 속성과 누적 성과 지표를 함께 넣었다.

하지만 dimension이라면 기본적으로 속성 중심이어야 한다.

최종 `core_d_items`는 아래 컬럼만 남겼다.

```text
item_id
item_name
item_brand
item_variant
item_category
first_seen_day
last_seen_day
```

아래 같은 성과 지표는 dimension이 아니라 analysis mart에서 다루는 것이 더 자연스럽다.

```text
order_count
buyer_count
total_quantity
total_item_revenue
avg_price
min_price
max_price
```

필요하다면 이후 분석 단계에서 `analysis_m_item_daily` 또는 `analysis_m_category_daily`처럼 목적형 mart로 만들 수 있다.

## 9. Funnel은 Reach와 Sequence를 구분해야 한다

`core_f_sessions`의 `has_add_to_cart` 같은 컬럼은 세션 안에 해당 행동이 있었는지를 나타낸다.

하지만 이것은 순서형 funnel 통과를 의미하지 않는다.

```text
has_add_to_cart = TRUE
```

는 장바구니 행동이 있었다는 뜻이지,

```text
view_item -> add_to_cart
```

순서가 보장됐다는 뜻은 아니다.

따라서 funnel은 아래처럼 구분해야 한다.

| 유형 | 의미 | 사용 데이터 |
|---|---|---|
| Session Reach Metric | 세션 안에 특정 행동이 있었는가 | core_f_sessions |
| Sequential Funnel Metric | event_seq 기준으로 행동이 순서대로 발생했는가 | base_f_event_wide |

정확한 funnel 분석은 `event_seq`를 사용해 별도 쿼리나 analysis mart에서 계산해야 한다.

## 10. 이 데이터에서 SHAP은 메인 분석으로 적합하지 않다

이번 데이터의 `event_name` 종류는 17개다.

이벤트 종류가 많지 않고, ecommerce funnel 구조가 이미 명확하다.

따라서 purchase 여부를 예측하는 ML 모델을 만들면 아래처럼 당연한 결과가 나올 가능성이 높다.

```text
add_to_cart_count가 중요하다
begin_checkout_count가 중요하다
view_item_count가 중요하다
```

이런 결과는 틀리지는 않지만, 분석 인사이트로는 약하다.

이번 프로젝트에는 아래 흐름이 더 적합하다.

```text
Revenue Decomposition
-> Funnel
-> Segment
-> 개선 가설
-> Simulated A/B Test
```

중요한 것은 ML을 쓰느냐가 아니라, 문제와 데이터 구조에 맞는 분석 방법을 선택하는 것이다.

## 11. 최종 회고

이번 mart 설계 과정에서 가장 크게 배운 점은 아래와 같다.

```text
1. Raw log를 바로 분석하는 것과 분석 가능한 mart를 설계하는 것은 다르다.
2. Mart 설계의 출발점은 항상 grain이다.
3. Key 정의를 잘못하면 지표 전체가 틀어질 수 있다.
4. Fact와 dimension의 역할을 구분해야 한다.
5. Analysis mart는 필요성이 생겼을 때만 만든다.
6. 로그에 없는 행동은 분석으로 복원할 수 없다.
7. 데이터 구조에 따라 적합한 분석 방법이 달라진다.
```

이 단계까지의 결과는 단순히 테이블을 만든 것이 아니라, GA4 행동 로그를 event/session/order/item 단위로 나누고 분석 가능한 구조로 모델링한 것이다.
