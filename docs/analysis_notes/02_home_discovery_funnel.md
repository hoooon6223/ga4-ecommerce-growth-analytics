# 02. Home Landing Discovery Funnel

## 분석 목적

`01_revenue_growth_flow.md`에서 NAU Buyer CVR 개선을 우선 분석 대상으로 설정했다.

본 문서는 NAU 중 가장 큰 초기 접점인 `home landing` 사용자가 첫 세션에서 상품 상세 조회까지 도달하는 흐름을 분석한다.

분석 목적은 퍼널 후반 결제 최적화가 아니라, 신규 사용자가 첫 방문에서 상품 발견을 시작하고 `view_item`까지 도달하도록 만드는 초기 discovery 개선 기회를 찾는 것이다.

## 분석 대상

주요 분석 기간:

```text
2020-11-23 to 2020-12-20
```

분석 단위:

```text
1 row = NAU user-week first session
```

Home landing 정의:

```text
landing_path IN ('/', '/store.html')
OR landing_page_title IN ('Home', 'Google Online Store')
```

분석 기준:

```text
전체 baseline:
Home landing NAU first session 전체

개선 가능성 분석:
Home landing 중 Home No-exploration Session 제외
```

## 메인 퍼널 정의

Home landing deep dive의 메인 퍼널은 아래와 같이 둔다.

```text
Home Landing
-> View Item
-> Add to Cart
-> Begin Checkout
-> Purchase
```

`item_list`와 `search`는 메인 퍼널 단계로 강제하지 않는다.

이유:

```text
1. View Item은 사용자가 실제 상품을 평가하기 시작하는 지점이다.
2. Home에서 View Item으로 가는 경로는 item_list, search, other page, direct 등 여러 갈래다.
3. item_list를 메인 단계로 강제하면 search/direct 경로가 누락된다.
4. 따라서 item_list/search는 Home -> View Item 사이의 route segment로 분해해 해석한다.
```

## Home Landing Baseline

Home landing NAU first session 전체 기준:

| Metric | Sessions | Rate |
|---|---:|---:|
| Home Landing Total | 46,923 | 100.00% |
| Reached Item List | 16,909 | 36.04% |
| Used Search | 2,593 | 5.53% |
| Reached View Item | 9,711 | 20.70% |
| Reached Cart after View Item | 3,516 | 36.21% of View Item |

관찰:

```text
1. Home landing 사용자의 View Item 도달률은 20.70%다.
2. View Item 도달 경로의 대부분은 item_list를 거친다.
3. search는 사용 세션이 5.53%로 작고, Home에서 바로 View Item으로 가는 주요 경로로 보기는 어렵다.
```

## Search Route 확인

Home landing에서 search를 사용한 세션은 2,593개다.

| Search Route | Sessions | Share of Search Sessions |
|---|---:|---:|
| item_list -> search -> view_item | 1,283 | 49.48% |
| search -> no view_item | 1,002 | 38.64% |
| search -> view_item, no item_list before view | 178 | 6.86% |
| search -> item_list -> view_item | 130 | 5.01% |

해석:

```text
검색 사용자의 절반은 이미 item_list를 거친 뒤 검색하고 View Item으로 이동한다.
따라서 현재 데이터에서 search는 Home에서 바로 상품 상세로 가는 주 경로라기보다,
item_list 탐색 중 보조 탐색 수단에 가깝다.
```

## Qualified Home Landing

초기 discovery 개선 가능성을 보기 위해 아무 탐색 행동이 없는 세션은 별도로 제외한다.

```text
Home No-exploration Session
= Home landing first session
AND View Item 미도달
AND item_list 미도달
AND search 미사용
AND other page 미이동
AND 추가 page_view 없음
AND scroll 없음
```

규모:

| Population | Sessions |
|---|---:|
| Home Landing Total | 46,923 |
| Home No-exploration Session | 11,562 |
| Qualified Home Landing | 35,361 |

주의:

```text
Home No-exploration 제외는 전체 성과를 좋게 보이기 위한 보정이 아니다.
상품 탐색 의도가 거의 관측되지 않은 세션과 개선 가능한 탐색 세션을 분리하기 위한 분석 모집단 정의다.
전체 funnel baseline에서는 no_exploration을 포함한다.

01_revenue_growth_flow.md의 Strict Homepage Bounce-like Session 8,425는 landing_path = '/'만 대상으로 한 좁은 정의다.
본 문서의 Home No-exploration Session 11,562는 '/', '/store.html', Home title까지 포함한 home landing 기준이다.
```

## Home to View Item Route Segment

Qualified Home Landing을 View Item 이전 행동 경로 기준으로 MECE하게 분해했다.

| Route Segment | Sessions | Share of Qualified Home | Purchase Sessions | Purchase Rate |
|---|---:|---:|---:|---:|
| home/other exploration -> no view_item | 17,711 | 50.09% | 0 | 0.00% |
| item_list only -> view_item | 8,425 | 23.83% | 483 | 5.73% |
| item_list only -> no view_item | 6,937 | 19.62% | 0 | 0.00% |
| item_list -> search -> view_item | 746 | 2.11% | 12 | 1.61% |
| search only -> no view_item | 512 | 1.45% | 0 | 0.00% |
| item_list + search -> no view_item | 490 | 1.39% | 0 | 0.00% |
| direct/unknown -> view_item | 231 | 0.65% | 1 | 0.43% |
| search -> item_list -> view_item | 130 | 0.37% | 2 | 1.54% |
| search only -> view_item | 130 | 0.37% | 4 | 3.08% |
| other page -> view_item | 49 | 0.14% | 3 | 6.12% |

합계:

```text
Qualified Home Landing = 35,361
View Item 도달 route 합계 = 9,711
View Item 미도달 route 합계 = 25,650
```

해석:

```text
1. Home landing에서 구매 세션이 가장 많이 관측된 View Item 도달 경로는 item_list를 거친 경로다.
2. item_list only -> view_item 세그먼트는 구매전환율이 5.73%로 높다.
3. 반면 가장 큰 미전환 풀은 home/other exploration -> no view_item 17,711명이다.
4. 두 번째 미전환 풀은 item_list only -> no view_item 6,937명이다.
```

## Home Exploration No View Item 분해

`home/other exploration -> no view_item` 17,711명을 다시 분해하면 아래와 같다.

| Detail Bucket | Sessions | Share |
|---|---:|---:|
| scroll_only_on_home | 11,324 | 63.94% |
| home_reloaded_or_store_home_only | 4,370 | 24.67% |
| moved_to_other_non_item_page | 2,016 | 11.38% |
| other_event_pattern | 1 | 0.01% |

해석:

```text
이 그룹의 대부분은 item_list/search/view_item으로 가지 않고,
홈에서 스크롤하거나 홈 계열 페이지만 본 사용자다.

따라서 "홈에서 탐색은 했지만 상품 발견 경로로 진입하지 못한 사용자"로 볼 수 있다.
```

## 전략 후보

현재 비교 가능한 전략 후보는 두 가지다.

| 후보 | 대상 세션 | 현재 상태 | 개선 목표 |
|---|---:|---|---|
| A. home/other exploration -> no view_item | 17,711 | 홈에서 탐색했지만 상품 발견 경로 미진입 | item_list 진입 유도 |
| B. item_list only -> no view_item | 6,937 | item_list까지 갔지만 상품 상세 미진입 | view_item 진입 유도 |

현재는 A를 1차 전략 후보로 둔다.

이유:

```text
1. A의 대상 세션이 B보다 약 2.55배 크다.
2. Home은 신규 사용자의 첫 접점이라 초기 discovery 개선 스토리와 잘 맞는다.
3. 관측 데이터에서 home -> item_list -> view_item 경로는 구매 세션이 가장 많이 발생한 View Item 도달 경로다.
```

단, `home -> item_list`가 바로 구매나 View Item을 보장하지는 않는다.

전략적 의미:

```text
home -> item_list 개선은 구매를 직접 증가시키는 최종 레버라기보다,
view_item으로 이어질 수 있는 discovery pool을 확대하는 초기 퍼널 레버다.

성공 여부는 home -> item_list rate뿐 아니라
home -> view_item rate가 함께 상승하는지로 판단한다.
```

## 현재 가설

```text
Home landing에서 상품 카테고리/브랜드/추천 상품 진입점을 강화하면,
NAU Home Landing 사용자의 item_list 진입률이 증가하고,
결과적으로 Home -> View Item 도달률이 상승할 것이다.
```

지표 후보:

| 역할 | 지표 |
|---|---|
| Primary | Home -> Item List Rate |
| Key Secondary | Home -> View Item Rate |
| Downstream | View Item -> Add to Cart Rate, Purchase Rate |
| Guardrail | Item List -> View Item Rate가 사전 허용폭 이상 악화되지 않는지 |

실험 설계로 넘길 때의 기준:

```text
Qualified Home Landing은 route/WHY 진단을 위한 사후 분석 세그먼트다.
A/B test에서는 treatment 이전에 판단 가능한 NAU Home Landing first session 전체를 eligibility로 둔다.

Home -> Item List Rate는 discovery pool 확대를 보는 primary metric이다.
Home -> View Item Rate는 확대된 pool이 실제 상품 상세 진입으로 이어졌는지 보는 key secondary metric이다.
Item List -> View Item Rate는 낮은 의도 클릭만 증가했는지 확인하는 route quality guardrail이다.

따라서 후속 A/B test에서는 Primary, Key Secondary, Guardrail을 사전에 분리해 정의한다.
```

## 다음 분석 질문

```text
Q1. home/other exploration -> no view_item 세그먼트는 왜 상품 발견 경로로 이어지지 않았는가?
Q2. 이 WHY를 데이터로 좁혀 어떤 실험 가설로 연결할 수 있는가?
```

이후 WHY diagnostic analysis는 별도 문서에서 이어간다.

```text
docs/analysis_notes/03_home_discovery_why_hypothesis.md
```
