# Event Dictionary

## 문서 목적

이 문서는 GA4 public ecommerce dataset에서 관측된 `event_name`과 주요 event parameter를 한국어로 정의한 이벤트 사전이다.

내부 tracking plan이 제공되지 않았기 때문에 이 문서는 "앞으로 이렇게 수집하라"는 수집 명세서가 아니다.

이미 수집된 로그를 분석자가 어떻게 해석하고 사용할지 정리한 observed event dictionary다.

## 문서 사용 방법

이 문서는 분석 중 이벤트나 파라미터의 의미가 헷갈릴 때 참고하는 기준 문서다.

```text
1. 이벤트가 무엇인지 확인한다.
2. 해당 이벤트가 어떤 상황에서 발생한 것으로 해석되는지 확인한다.
3. 분석에 사용할 주요 파라미터를 확인한다.
4. 이벤트 count, session count, order count를 혼동하지 않도록 주의사항을 확인한다.
```

현업의 tracking plan처럼 "수집되어야 하는 이벤트 명세"를 정의한 문서는 아니다.

이 프로젝트에서는 실제 수집된 GA4 로그를 기준으로 이벤트 의미를 정리한 observed event dictionary로 사용한다.

## Documentation Rules

```text
1. 이벤트 이름만 보고 의미를 확정하지 않고, GA4 ecommerce 구조와 실제 관측값을 기준으로 해석한다.
2. 이벤트 발생 수, 세션 수, 사용자 수를 같은 개념으로 취급하지 않는다.
3. purchase event를 실제 backend order와 동일하다고 단정하지 않는다.
4. 하나의 session에서 동일 event가 여러 번 발생할 수 있음을 전제로 한다.
5. item 관련 event는 하나의 event 안에 여러 item이 포함될 수 있다.
6. 이벤트 발생 순서를 곧바로 funnel 통과로 해석하지 않고, 분석 grain과 sequence 기준을 별도로 명시한다.
7. tracking anomaly 또는 public dataset 한계는 임의 보정하지 않고 주의사항에 기록한다.
```

## 이벤트 목록

이 표는 현재 분석 기간에 실제 관측된 이벤트 목록이다.

`event_count`는 이벤트 발생 횟수이며, 사용자 수나 세션 수가 아니다.

| event_name | event_count | 분류 | 한국어 설명 | 발생 시점 해석 |
|---|---:|---|---|---|
| session_start | 354,970 | Session | GA4 기준 세션 시작 이벤트 | 사용자의 새 세션이 시작될 때 기록된 것으로 해석 |
| first_visit | 257,462 | User | 해당 anonymous_id의 첫 방문 이벤트 | GA4가 해당 익명 식별자를 처음 관측했을 때 기록된 것으로 해석 |
| page_view | 1,350,428 | Page | 페이지 조회 이벤트 | 사용자가 웹 페이지를 조회했을 때 기록된 것으로 해석 |
| view_item_list | 71 | Product | 상품 목록 조회 이벤트 | 사용자가 상품 리스트 영역을 조회했을 때 기록된 것으로 해석 |
| select_item | 31,007 | Product | 상품 선택 이벤트 | 사용자가 상품 목록/추천 영역 등에서 특정 상품을 선택했을 때 기록된 것으로 해석 |
| view_item | 386,068 | Product | 상품 조회 이벤트 | 사용자가 상품 상세 또는 상품 항목을 조회했을 때 기록된 것으로 해석 |
| add_to_cart | 58,543 | Cart | 장바구니 담기 이벤트 | 사용자가 상품을 장바구니에 추가했을 때 기록된 것으로 해석 |
| begin_checkout | 38,757 | Checkout | 체크아웃 시작 이벤트 | 사용자가 결제/체크아웃 프로세스를 시작했을 때 기록된 것으로 해석 |
| add_shipping_info | 19,722 | Checkout | 배송 정보 입력 이벤트 | 체크아웃 과정에서 배송 정보 또는 배송 옵션이 입력/선택됐을 때 기록된 것으로 해석 |
| add_payment_info | 13,899 | Checkout | 결제 정보 입력 이벤트 | 체크아웃 과정에서 결제 정보 또는 결제 단계가 기록됐을 때 발생한 것으로 해석 |
| purchase | 5,692 | Purchase | 구매 완료 이벤트 | GA4에서 구매 완료 시점에 기록된 것으로 해석 |
| scroll | 493,072 | Engagement | 스크롤 이벤트 | 사용자가 페이지를 일정 비율 이상 스크롤했을 때 기록된 것으로 해석 |
| click | 1,446 | Engagement | 링크 클릭 이벤트 | GA4 수집 대상 링크 클릭이 발생했을 때 기록된 것으로 해석 |
| view_search_results | 26,172 | Search | 검색 결과 조회 이벤트 | 사용자가 사이트 내 검색 결과를 조회했을 때 기록된 것으로 해석 |
| user_engagement | 1,058,721 | Engagement | 사용자 참여 이벤트 | GA4가 사용자 참여 상태나 참여 시간을 기록하기 위해 수집한 이벤트 |
| view_promotion | 190,104 | Promotion | 프로모션 노출 이벤트 | 사용자가 프로모션 영역 또는 항목을 조회했을 때 기록된 것으로 해석 |
| select_promotion | 9,450 | Promotion | 프로모션 선택 이벤트 | 사용자가 프로모션 영역 또는 항목을 선택했을 때 기록된 것으로 해석 |

## 이벤트별 분석 기준

이 표는 각 이벤트를 분석에서 어떻게 사용할 수 있는지 정리한다.

여기서의 `분석 사용처`는 가능한 활용 방향이며, 인과관계를 의미하지 않는다.

| event_name | 주요 파라미터 | 분석 사용처 | 해석 주의사항 |
|---|---|---|---|
| session_start | ga_session_id, ga_session_number, page_location, page_referrer, page_title | 세션 수 검증, 세션 흐름 시작점 확인 | 세션 분석은 event count가 아니라 distinct session_id 또는 core_f_sessions 기준으로 계산 |
| first_visit | ga_session_id, ga_session_number, page_location, page_referrer, page_title | 신규 방문/신규 사용자 후보 식별 | 실제 회원가입 또는 실제 신규 고객과 동일하지 않음 |
| page_view | page_location, page_title, page_referrer, entrances, engagement_time_msec | 페이지 조회, 랜딩페이지, 경로 분석 | page_view 수는 session 수나 user 수와 다름 |
| view_item_list | items, page_location, item_row_count | 상품 리스트 노출 분석 후보 | 관측량이 매우 적어 분석 사용 전 표본 확인 필요 |
| select_item | items, page_location, item_row_count | 상품 탐색 행동, 상품 선택 신호 | 모든 클릭을 의미하지 않으며 click 이벤트와 구분 필요 |
| view_item | items, page_location, item_row_count | 상품 관심 신호, funnel step | event grain에서는 item 상세가 펼쳐져 있지 않음 |
| add_to_cart | items, page_location, item_row_count | 구매 의도 신호, funnel step | 동일 세션에서 여러 번 발생 가능 |
| begin_checkout | currency, page_location, items | checkout 진입 funnel step | 장바구니 이후 바로 구매 완료를 의미하지 않음 |
| add_shipping_info | currency, shipping_tier, page_location | checkout 세부 단계 분석 | 배송 정보 입력 완료의 업무 DB 검증은 불가 |
| add_payment_info | currency, payment_type, page_location | checkout 세부 단계 분석 | 실제 결제 승인과 동일하지 않을 수 있음 |
| purchase | transaction_id, value, currency, tax, payment_type, shipping_tier, coupon, items | 주문 수, 매출, 구매 전환 분석 | backend order DB와 1:1 검증 불가. order는 purchase_event_key 기준으로 정의 |
| scroll | percent_scrolled, page_location, engagement_time_msec | 페이지 탐색/관심 신호 | engagement 원인으로 단정하지 않음 |
| click | link_url, link_domain, outbound, page_location | outbound/link 클릭 분석 | 모든 UI 클릭을 의미하지 않음 |
| view_search_results | search_term, unique_search_term, page_location | 검색 사용 여부, 검색 후 전환 분석 | 검색어는 obfuscated 값이 존재할 수 있음 |
| user_engagement | engagement_time_msec, session_engaged, engaged_session_event | engagement 보조 지표 | GA4 수집 로직 기반 이벤트이므로 비즈니스 행동으로 직접 해석하지 않음 |
| view_promotion | promotion_name, page_location, items | 프로모션 노출 분석 후보 | 실제 프로모션 캠페인 master와 검증되지 않음 |
| select_promotion | promotion_name, page_location, items | 프로모션 선택/클릭 분석 후보 | 프로모션 노출 대비 선택률 분석 전 표본과 수집 구조 확인 필요 |

## 이벤트 파라미터 정의

`base_f_event_wide`에 포함된 주요 이벤트/사용자/세션/페이지/유입/기기/매출 관련 컬럼의 의미를 정리한다.

| category | 설명 |
|---|---|
| Event | 이벤트 자체를 식별하거나 순서를 재현하는 컬럼 |
| User | 익명 사용자 또는 최초 방문 시점 관련 컬럼 |
| Session | 세션 식별 및 세션 순번 관련 컬럼 |
| Page | URL, title, referrer, landing page 산출 관련 컬럼 |
| Traffic | 유입 source, medium, campaign 관련 컬럼 |
| Device | 기기, OS, 브라우저 관련 컬럼 |
| Geo | 국가, 지역, 도시 관련 컬럼 |
| Engagement | 스크롤, 참여 시간 등 행동 강도 후보 컬럼 |
| Purchase | 구매 이벤트와 거래 정보 관련 컬럼 |
| Promotion | 쿠폰/프로모션 관련 컬럼 |
| Click | 링크 클릭 관련 컬럼 |
| Ecommerce | GA4 ecommerce 구조에서 온 매출/상품 수량 관련 컬럼 |

| parameter_or_column | type | category | description_kr | source | caution |
|---|---:|---|---|---|---|
| event_name | STRING | Event | 이벤트명. 사용자의 행동 종류를 나타냄 | raw event field | 이벤트명만으로 사용자 수/세션 수를 해석하지 않음 |
| event_timestamp | INT64 | Event | GA4 원천의 이벤트 발생 timestamp | raw event field | 동일 timestamp에 여러 이벤트가 존재 가능 |
| event_bundle_sequence_id | INT64 | Event | GA4 원천의 이벤트 bundle sequence 값 | raw event field | 단독으로 세션 내 완전한 순서를 보장하지 않음 |
| event_key | STRING | Event | 이벤트 1개를 식별하기 위해 생성한 분석용 PK | derived | GA4 원천 PK가 아니라 분석용 생성 키 |
| event_seq | INT64 | Event | 동일 세션 안에서 이벤트 순서를 재현하기 위해 생성한 순번 | derived | 동일 timestamp는 tie-breaker로 정렬한 분석용 순서 |
| anonymous_id | STRING | User | GA4 user_pseudo_id. 익명 사용자/기기 식별자 | user_pseudo_id | 실제 회원 ID 아님 |
| user_first_touch_at | TIMESTAMP | User | 익명 사용자가 처음 관측된 시각 | user_first_touch_timestamp | 실제 가입일과 다름 |
| ga_session_id | INT64 | Session | GA4가 부여한 세션 ID 값 | event_params.ga_session_id | 전역 unique로 단정하지 않음 |
| ga_session_number | INT64 | Session | 해당 익명 사용자의 세션 순번 | event_params.ga_session_number | anonymous_id 기준의 순번 |
| session_id | STRING | Session | anonymous_id와 ga_session_id를 결합한 분석용 세션 키 | derived | 서비스 DB의 session key가 아님 |
| page_location | STRING | Page | 이벤트가 발생한 페이지 URL | event_params.page_location | URL 파라미터 정리는 별도 분석 단계에서 판단 |
| page_title | STRING | Page | 이벤트가 발생한 페이지 title | event_params.page_title | title 변경/중복 가능 |
| page_referrer | STRING | Page | 이벤트 직전 referrer URL | event_params.page_referrer | referrer가 항상 존재하지 않을 수 있음 |
| entrances | INT64 | Page | 세션 진입 페이지 여부를 나타내는 값 | event_params.entrances | landing_page 산출에 사용 |
| traffic_source | STRING | Traffic | 사용자 최초 유입 source | traffic_source.source | 이벤트별 유입 파라미터와 혼용 주의 |
| traffic_medium | STRING | Traffic | 사용자 최초 유입 medium | traffic_source.medium | 이벤트별 유입 파라미터와 혼용 주의 |
| traffic_campaign | STRING | Traffic | 사용자 최초 유입 campaign | traffic_source.name | UTM 캠페인과 값이 다를 수 있음 |
| event_param_source | STRING | Traffic | event_params에 기록된 source | event_params.source | traffic_source와 기준이 다름 |
| event_param_medium | STRING | Traffic | event_params에 기록된 medium | event_params.medium | traffic_medium과 기준이 다름 |
| event_param_campaign | STRING | Traffic | event_params에 기록된 campaign | event_params.campaign | traffic_campaign과 기준이 다름 |
| device_category | STRING | Device | 기기 유형. desktop, mobile, tablet 등 | device.category | GA4 추정값 |
| operating_system | STRING | Device | 사용자 기기 운영체제 | device.operating_system | Other 값 존재 가능 |
| operating_system_version | STRING | Device | 사용자 기기 운영체제 버전 | device.operating_system_version | Other 값 존재 가능 |
| language | STRING | Device | 브라우저 또는 기기 언어 설정 | device.language | 실제 사용 언어와 다를 수 있음 |
| browser | STRING | Device | 사용자가 이용한 브라우저 | device.web_info.browser | Other 값 존재 가능 |
| browser_version | STRING | Device | 사용자가 이용한 브라우저 버전 | device.web_info.browser_version | 버전 세분화로 cardinality가 높을 수 있음 |
| country | STRING | Geo | GA4가 추정한 사용자 국가 | geo.country | IP 기반 추정값 |
| region | STRING | Geo | GA4가 추정한 사용자 지역 | geo.region | not set 가능 |
| city | STRING | Geo | GA4가 추정한 사용자 도시 | geo.city | not set 가능 |
| engagement_time_msec | INT64 | Engagement | 이벤트에 기록된 engagement time. 단위 millisecond | event_params.engagement_time_msec | engagement 정의 없이 과도한 해석 주의 |
| engaged_session_event | INT64 | Engagement | GA4 engaged session 관련 표시값 | event_params.engaged_session_event | GA4 수집 로직 의존 |
| session_engaged | STRING | Engagement | GA4의 session engaged 여부 값 | event_params.session_engaged | 현재는 원천값 보존, 해석은 별도 정의 필요 |
| percent_scrolled | INT64 | Engagement | scroll 이벤트의 스크롤 비율 | event_params.percent_scrolled | scroll 이벤트 외에는 NULL 가능 |
| term | STRING | Search/Traffic | 검색어 또는 유입 키워드 관련 값 | event_params.term | obfuscated 가능 |
| search_term | STRING | Search | 사이트 내 검색어 | event_params.search_term | obfuscated 가능 |
| unique_search_term | INT64 | Search | 검색어 고유 여부 또는 검색 관련 보조 값 | event_params.unique_search_term | 값 의미는 추가 검증 필요 |
| event_currency | STRING | Purchase | 이벤트에 기록된 통화 코드 | event_params.currency | purchase 외 이벤트에서는 NULL 가능 |
| event_value | FLOAT64 | Purchase | 이벤트 value 값. 구매 이벤트에서는 거래 금액 후보 | event_params.value | purchase_revenue와 차이 검증 필요 |
| event_tax | FLOAT64 | Purchase | 이벤트에 기록된 tax 값 | event_params.tax | purchase 외 이벤트에서는 NULL 가능 |
| event_param_transaction_id | STRING | Purchase | event_params에 기록된 transaction_id | event_params.transaction_id | ecommerce.transaction_id와 차이 가능 |
| transaction_id | STRING | Purchase | ecommerce 구조에 기록된 transaction_id | ecommerce.transaction_id | 실제 order id와 1:1 검증 불가 |
| payment_type | STRING | Purchase | 결제 방식 | event_params.payment_type | NULL 비율 높을 수 있음 |
| shipping_tier | STRING | Purchase | 배송 옵션 또는 배송 등급 | event_params.shipping_tier | NULL 비율 높을 수 있음 |
| event_coupon | STRING | Promotion | 이벤트에 기록된 쿠폰명 또는 쿠폰 코드 | event_params.coupon | 적용 단위 확인 필요 |
| event_promotion_name | STRING | Promotion | 이벤트에 기록된 프로모션 이름 | event_params.promotion_name | 프로모션 master 없음 |
| link_url | STRING | Click | click 이벤트에서 기록된 링크 URL | event_params.link_url | click 이벤트 외에는 NULL 가능 |
| link_domain | STRING | Click | click 이벤트에서 기록된 링크 domain | event_params.link_domain | click 이벤트 외에는 NULL 가능 |
| outbound | STRING | Click | 외부 이동 여부 | event_params.outbound | 수집 대상 click에 한정 |
| total_item_quantity | INT64 | Ecommerce | purchase 이벤트의 총 상품 수량 | ecommerce.total_item_quantity | event-level 값 |
| purchase_revenue | FLOAT64 | Ecommerce | purchase 이벤트에 기록된 구매 매출 | ecommerce.purchase_revenue | 전체 매출 기준으로 사용 |
| refund_value | FLOAT64 | Ecommerce | 환불 금액 | ecommerce.refund_value | 환불 분석 전 수집 구조 확인 필요 |
| shipping_value | FLOAT64 | Ecommerce | 배송 금액 | ecommerce.shipping_value | purchase 외 NULL 가능 |
| tax_value | FLOAT64 | Ecommerce | 세금 금액 | ecommerce.tax_value | purchase 외 NULL 가능 |
| unique_items | INT64 | Ecommerce | purchase 이벤트의 고유 상품 수 | ecommerce.unique_items | event-level 값 |
| item_row_count | INT64 | Ecommerce | 해당 이벤트의 items 배열 row 수 | ARRAY_LENGTH(items) | item 상세는 base_f_order_items에서 분석 |

## 상품 파라미터 정의

`base_f_order_items`에 포함된 item 관련 컬럼의 의미를 정리한다.

이 테이블의 item은 실제 상품 master의 product record가 아니라, purchase 이벤트 안의 `items` 배열에서 관측된 상품 row다.

| parameter_or_column | type | category | description_kr | source | caution |
|---|---:|---|---|---|---|
| item_order_id | STRING | Order Item | 구매 이벤트 안의 상품 row 1개를 식별하는 분석용 PK | derived | 원천 PK가 아니라 생성 키 |
| purchase_event_key | STRING | Order Item | 해당 상품 row가 속한 purchase 이벤트 키 | derived | base_f_event_wide.event_key와 연결 |
| order_id | STRING | Order | 현재 분석에서 사용하는 operational order key | derived purchase_event_key | 실제 주문 ID가 아니라 purchase 이벤트 기준 생성 키 |
| item_seq | INT64 | Order Item | purchase 이벤트 안에서 상품 row가 몇 번째인지 나타내는 순번 | items array offset | 비즈니스 순위가 아니라 배열 순번 |
| item_id | STRING | Item | 상품 ID | item.item_id | 실제 product master와 검증되지 않음 |
| item_name | STRING | Item | 상품명 | item.item_name | 동일 item_id에 여러 이름 가능 |
| item_brand | STRING | Item | 상품 브랜드 | item.item_brand | NULL 또는 not set 가능 |
| item_variant | STRING | Item | 상품 옵션 또는 변형 정보 | item.item_variant | 옵션 체계 검증 불가 |
| item_category | STRING | Item | 상품 카테고리 | item.item_category | 실제 category master와 검증되지 않음 |
| price | FLOAT64 | Item | 상품 단가 | item.price | 할인/세금 포함 여부 확인 필요 |
| quantity | INT64 | Item | 구매 수량 | item.quantity | order item grain에서 합산 가능 |
| item_revenue | FLOAT64 | Item | 해당 상품 row의 매출 | item.item_revenue | 상품/카테고리 매출 기준 |
| item_refund | FLOAT64 | Item | 해당 상품 row의 환불 금액 | item.item_refund | 환불 분석 전 수집 구조 확인 필요 |
| item_coupon | STRING | Promotion | 상품 row에 적용된 쿠폰 | item.coupon | 주문 쿠폰과 구분 필요 |
| item_list_name | STRING | Product List | 상품이 노출된 리스트 이름 | item.item_list_name | purchase 이벤트 기준 관측값 |
| promotion_id | STRING | Promotion | 상품 row에 연결된 프로모션 ID | item.promotion_id | 프로모션 master 없음 |
| item_promotion_name | STRING | Promotion | 상품 row에 연결된 프로모션 이름 | item.promotion_name | 프로모션 master 없음 |

## 값 정규화 규칙

| 원천 값 형태 | 변환 결과 | 설명 |
|---|---|---|
| `(data deleted)` | NULL | 비식별/삭제 처리된 값으로 보고 분석값에서 제외 |
| `<data deleted>` | NULL | 비식별/삭제 처리된 값으로 보고 분석값에서 제외 |
| `(organic)` | `organic` | 괄호 제거 |
| `(direct)` | `direct` | 괄호 제거 |
| `(not set)` | `not set` | 괄호 제거. GA4에서 값을 확정하지 못한 상태 |
| `<Other>` | `Other` | 꺾쇠 괄호 제거 |
| `<obfuscated>` | `obfuscated` | 꺾쇠 괄호 제거. public dataset 비식별 처리 값 |
