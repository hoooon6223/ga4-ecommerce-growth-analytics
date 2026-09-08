# 03. Home Discovery WHY Hypothesis

## 분석 목적

`02_home_discovery_funnel.md`에서 Qualified Home Landing 사용자의 가장 큰 미전환 풀은
`home/other exploration -> no view_item` 세그먼트로 확인되었다.

본 문서는 해당 세그먼트가 왜 상품 발견 경로로 이어지지 않았는지 데이터로 좁히고,
실험으로 검증 가능한 제품 가설로 연결하기 위한 diagnostic analysis다.

```text
WHAT:
Home landing NAU에서 View Item 도달률이 낮다.

WHERE:
Qualified Home Landing 중 home/other exploration -> no view_item 세그먼트가 가장 크다.

WHY:
홈에서 탐색은 했지만 상품 discovery 요소를 선택하거나 item_list/view_item으로 이동하지 못했을 가능성이 있다.

HOW:
상품 discovery 진입점의 명확성/매력도를 높여 선택 행동과 item_list 진입을 유도한다.
```

## 큰 가설

```text
Home landing에서 상품 발견 경로로 충분히 진입하지 못해
View Item 도달률이 낮다.
```

이 가설을 바로 UI 수정안으로 연결하지 않고, 작은 WHY 가설로 나눠 확인한다.

## 작은 WHY 가설과 확인 지표

| WHY 가설 | 맞다면 보여야 할 지표 패턴 | 확인 지표 |
|---|---|---|
| 특정 source 유입 문제 | 특정 source에서만 no view_item 비중이 높음 | source별 sessions, p50 sec, page views, scroll |
| 특정 device UX 문제 | mobile 또는 tablet에서만 no view_item 비중이 높음 | device별 sessions, p50 sec, page views, scroll |
| 단순 상단 이탈 | scroll이 낮고 체류가 매우 짧음 | scroll rate, p50 max scroll, p50 sec |
| 상품 외 목적 유입 | signin, basket, policy 등 비상품 페이지 이동이 큼 | first other page |
| 홈 discovery 선택 약함 | promotion 노출은 있으나 select_promotion이 낮음 | view_promotion, select_promotion, item_list rate, view_item rate |

## WHY 1. Source 또는 Device 문제인가?

`home/other exploration -> no view_item` 세그먼트의 source/device별 패턴은 큰 차이를 보이지 않았다.

| Segment | Sessions | p50 sec | Avg Page Views | p50 Scroll |
|---|---:|---:|---:|---:|
| desktop | 10,343 | 17 | 1.58 | 90 |
| mobile | 6,963 | 17 | 1.61 | 90 |
| google / organic | 6,184 | 17 | 1.55 | 90 |
| direct / none | 4,150 | 17 | 1.61 | 90 |

해석:

```text
특정 source나 device에서만 발생하는 문제로 보기는 어렵다.
현재 데이터에서는 홈 경험 전반에서 상품 discovery 노출이 실제 선택 행동으로 전환되지 못하는 문제일 가능성이 더 크다.
```

## WHY 2. 단순 상단 이탈인가?

`home/other exploration -> no view_item` 세그먼트는 p50 scroll이 90으로 나타났다.

| Detail Bucket | Sessions | Share | p50 sec | Avg Page Views | p50 Scroll |
|---|---:|---:|---:|---:|---:|
| scroll_only_on_home | 11,324 | 63.94% | 10 | 1.00 | 90 |
| home_reloaded_or_store_home_only | 4,370 | 24.67% | 63 | 2.42 | 90 |
| moved_to_other_non_item_page | 2,016 | 11.38% | 22 | 3.13 | 90 |

해석:

```text
이 그룹은 아무것도 보지 않고 즉시 나간 세션만으로 보기 어렵다.
상당수는 홈에서 스크롤하거나 홈 계열 페이지를 다시 봤지만,
item_list/search/view_item으로 이어지지 않았다.
```

## WHY 3. 상품 외 목적 유입인가?

비상품 페이지로 이동한 세션 2,016개 중 대부분은 signin 페이지로 이동했다.

| First Other Page | Sessions | Share |
|---|---:|---:|
| /signin.html | 1,476 | 73.21% |
| /basket.html | 239 | 11.86% |
| /store-policies/frequently-asked-questions/ | 89 | 4.41% |

해석:

```text
상품 외 목적 유입도 일부 존재한다.
다만 전체 home/other exploration -> no view_item 세그먼트 17,711개 중
비상품 페이지 이동은 2,016개이므로 전체를 설명하는 주된 이유로 보기는 어렵다.
```

## WHY 4. 홈 Discovery 노출이 선택 행동으로 이어지는가?

이벤트 패턴을 보면 `scroll`, `user_engagement`, `view_promotion`은 관측되지만
promotion 선택 행동인 `select_promotion`은 매우 낮았다.

| Event Name | Sessions | Session Share |
|---|---:|---:|
| page_view | 17,677 | 99.81% |
| scroll | 15,547 | 87.78% |
| user_engagement | 14,999 | 84.69% |
| view_promotion | 7,637 | 43.12% |
| select_promotion | 17 | 0.10% |

공통 이벤트 흐름도 대부분 홈 조회 이후 스크롤, engagement, promotion 노출에서 멈췄다.

| First Event Pattern | Sessions | Share |
|---|---:|---:|
| other_event -> home_pageview -> other_event -> scroll -> user_engagement | 7,145 | 40.34% |
| other_event -> home_pageview -> other_event -> scroll -> user_engagement -> home_pageview | 2,501 | 14.12% |
| other_event -> home_pageview -> other_event -> view_promotion -> scroll -> user_engagement | 1,815 | 10.25% |
| other_event -> home_pageview -> other_event -> view_promotion -> user_engagement -> other_pageview | 1,437 | 8.11% |

해석:

```text
홈에서 콘텐츠를 보거나 프로모션에 노출되는 행동은 있지만,
promotion 선택 행동은 매우 약하게 관측된다.

`click` 이벤트도 낮게 관측되었지만, GA4의 일반 click 이벤트가 홈 상품 discovery CTA를 직접 의미한다고 단정하기 어렵다.
따라서 핵심 근거는 `view_promotion -> select_promotion` 전환에 둔다.
```

## Promotion Selection과 Discovery Outcome

Home landing 전체에서 promotion behavior별 item_list, view_item, purchase 도달률을 비교했다.

| Promotion Behavior | Sessions | Share of Home Landing | Item List Rate | View Item Rate | Purchase Rate |
|---|---:|---:|---:|---:|---:|
| promotion view, no select | 30,115 | 64.18% | 48.26% | 27.71% | 2.00% |
| no promotion view | 14,621 | 31.16% | 2.13% | 2.08% | 0.01% |
| promotion selected | 2,187 | 4.66% | 94.47% | 48.56% | 3.11% |

source/device별로도 유사한 패턴이 반복되었다.

| Segment | Promotion Selected Share | Selected Item List Rate | Selected View Item Rate |
|---|---:|---:|---:|
| desktop | 5.04% | 94.61% | 49.37% |
| mobile | 5.21% | 94.10% | 46.99% |
| google / organic | 5.28% | 94.49% | 48.97% |
| direct / none | 4.92% | 93.21% | 49.90% |

해석:

```text
promotion을 선택한 세션에서는 item_list와 view_item 도달률이 높게 관측되었다.
반면 promotion을 보았지만 선택하지 않은 세션은 훨씬 많고,
promotion 선택률 자체는 낮다.

따라서 현재 관측 데이터에서는
홈의 상품 discovery 요소가 노출되더라도 실제 선택 행동으로 이어지는 비율이 낮다는 WHY 가설이 가장 설득력 있다.
```

주의:

```text
promotion selection이 item_list, view_item, purchase를 인과적으로 증가시킨다고 단정하지 않는다.
현재 분석은 관측 데이터에서 함께 나타난 행동 패턴을 기반으로
A/B test로 검증할 WHY/HOW 가설을 좁히는 단계다.
```

## 업데이트된 WHY

```text
Home landing에서 상품 discovery 요소의 노출은 발생하지만,
실제 선택 행동으로 이어지는 비율이 낮다.

또한 promotion을 선택한 세션에서는 item_list 진입률과 view_item 도달률이 높게 관측된다.

따라서 Home -> View Item 병목의 주요 WHY 후보는
상품 discovery 노출 -> 선택 전환 부족으로 좁힌다.
```

## HOW 후보

WHY를 바탕으로 한 HOW는 특정 UI 아이디어를 무작정 나열하기보다,
상품 discovery 노출이 선택 행동으로 이어지도록 만드는 방향으로 제한한다.

여기서부터는 데이터가 직접 말한 관측 결과가 아니라, 제품적으로 검증할 가설이다.

| HOW 후보 | 기대 효과 | 연결 지표 |
|---|---|---|
| 홈 첫 화면 또는 초기 스크롤 구간에 주요 카테고리 진입점 강화 | 상품 탐색 시작점의 명확성/매력도 개선 | promotion select rate, home -> item_list rate |
| 브랜드/카테고리별 상품 탐색 CTA를 더 명확하게 제공 | promotion 노출 후 선택 행동 증가 | select_promotion rate, item_list rate |
| 인기 상품 또는 추천 상품 모듈을 item_list로 연결 | view_item 후보 pool 확대 | home -> view_item rate |

현재 단계에서 가장 보수적인 실험 방향:

```text
Home landing의 상품 카테고리/브랜드/추천 상품 진입점의 명확성/매력도를 높이면,
promotion select rate와 home -> item_list rate가 증가하고,
결과적으로 home -> view_item rate가 상승할 것이다.
```

## 실험 지표 후보

| 역할 | 지표 | 이유 |
|---|---|---|
| Primary | Home -> Item List Rate | 홈에서 상품 discovery path로 진입했는지 직접 확인 |
| Diagnostic | Promotion Select Rate | 노출된 discovery 요소가 실제 선택 행동으로 이어지는지 확인 |
| Key Secondary | Home -> View Item Rate | 상품 상세 진입까지 실제로 이어졌는지 확인 |
| Guardrail | Item List -> View Item Rate | 낮은 의도 클릭만 늘어 route quality가 사전 허용폭 이상 악화되지 않는지 확인 |
| Downstream | Purchase Rate, Revenue per Session | 구매와 매출 방향성을 확인하되 실험 성공 판정의 핵심 지표로 사용하지 않음 |

주의:

```text
Promotion Select Rate는 WHY에서 확인한 discovery 선택 행동과 가장 직접적으로 연결된다.
다만 최종 제품 목표는 단순 promotion 선택 증가가 아니라 상품 탐색 경로 진입이므로,
A/B test의 primary metric은 Home -> Item List Rate로 둔다.

Qualified Home Landing은 WHY를 좁히기 위한 사후 분석 세그먼트로 사용하고,
실험 eligibility는 treatment 이전에 판단 가능한 NAU Home Landing first session 전체로 둔다.

Purchase Rate와 Revenue per Session은 Business Goal과 연결되는 downstream metric이지만,
초기 discovery 개선 실험에서 단기적으로 유의한 매출 효과까지 검증했다고 해석하지 않는다.
```

## 다음 단계

```text
1. HOW 후보 중 실제 A/B test로 가장 명확한 변경안을 1개 선택한다.
2. 실험 대상, randomization unit, analysis unit을 분리해 정의한다.
3. primary metric의 MDE, sample size, duration을 사전에 계산한다.
4. guardrail 허용 하락폭과 downstream 해석 원칙을 정리한다.
```
