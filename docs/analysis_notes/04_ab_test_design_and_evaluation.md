# 04. A/B Test Design and Evaluation

## 분석 목적

`03_home_discovery_why_hypothesis.md`에서 Home landing의 상품 discovery 노출이 실제 선택 행동으로 이어지는 비율이 낮다는 WHY 후보를 도출했다.

본 문서는 앞선 GA4 분석에서 도출한 baseline과 제품 가설을 기반으로 구성한 synthetic experiment dataset을 사용한다. 목적은 실험 설계, 지표 정의, 통계 검정, 의사결정 기준, modeled business impact를 보여주는 것이다.

## 분석 집단과 실험 집단의 분리

```text
분석 단계:
Home Landing
-> No-exploration / Qualified 분리
-> Qualified Home Landing에서 route/WHY 진단

실험 단계:
NAU Home Landing first session 전체
-> anonymous_id 단위 randomization
-> ITT 기준으로 모든 eligible Home Landing first session 분석
```

Qualified Home Landing은 사용자가 Home에 들어온 뒤의 행동을 보고 사후적으로 정의한 분석 세그먼트다. 따라서 실험 eligibility를 Qualified Home으로 정의하면 treatment 이후 행동으로 모집단을 고르는 post-treatment selection 문제가 생길 수 있다.

실험에서는 treatment 이전에 판단 가능한 `NAU first session with Home Landing`을 eligibility로 두고, 모든 eligible session을 ITT 기준으로 분석한다.

## 제품 가설

```text
Home landing의 상품 카테고리/브랜드/추천 상품 진입점의 명확성/매력도를 높이면,
NAU Home Landing 사용자의 Home -> Item List Rate가 증가하고,
결과적으로 Home -> View Item Rate가 상승할 것이다.
```

## 실험 설계

| 항목 | 정의 |
|---|---|
| Experiment | Home discovery entry point improvement |
| 대상 | NAU first session with Home Landing |
| Control | 기존 Home discovery 진입점 |
| Treatment | Home 초기 영역의 카테고리/브랜드/추천 상품 진입점 강화 |
| Eligibility Unit | NAU first session with Home Landing |
| Randomization Unit | anonymous_id |
| Analysis Unit | eligible Home Landing first session |
| Primary Metric | Home -> Item List Rate |
| Key Secondary Metric | Home -> View Item Rate |
| Guardrail Metric | Item List -> View Item Rate |
| Downstream Metric | Purchase Rate, Revenue per Session |

Randomization unit:

```text
실험 배정은 anonymous_id 기준으로 고정한다.

분석 대상은 NAU의 first Home Landing session이므로
각 eligible NAU는 하나의 first session만 분석에 기여한다.

이렇게 하면 동일 사용자가 실험 기간 중 여러 번 방문하더라도
Control과 Treatment 경험이 섞이는 것을 방지할 수 있다.
```

## Baseline

앞선 Home discovery 분석에서 확인한 전체 Home Landing baseline은 아래와 같다.

| Metric | Baseline |
|---|---:|
| Home Landing NAU First Sessions | 46,923 |
| Home -> Item List Rate | 36.04% |
| Home -> View Item Rate | 20.70% |
| Item List -> View Item Rate | 55.01% |
| View Item -> Add to Cart Rate | 36.21% |

## Sample Size Plan

Primary metric 기준 사전 검정 설계:

| 항목 | 값 |
|---|---:|
| Primary Metric | Home -> Item List Rate |
| Baseline | 36.04% |
| MDE | +3.50%p |
| Alpha | 0.05 |
| Power | 80% |
| Test | one-sided two-proportion z-test |
| Required Sample | 2,372 per variant |

예상 duration:

| 항목 | 값 |
|---|---:|
| Observed Home Landing | 46,923 / 4 weeks |
| Expected Eligible Sessions | 11,731 / week |
| Expected Sessions per Variant | 5,865 / week |
| Minimum Duration | 0.40 weeks |
| Simulated Sample | 24,000 per variant |
| Simulated Traffic Scale | 약 4.09 weeks |

해석:

```text
MDE +3.50%p를 탐지하기 위한 최소 샘플은 variant당 약 2,372이다.

다만 본 simulation은 주요 분석 기간의 4주 Home Landing traffic 규모를 재현하기 위해
variant당 24,000 eligible first session을 사용했다.
따라서 24,000은 sample size requirement가 아니라,
관측된 eligible traffic scale에 맞춘 simulation size다.
```

## Success Criteria

| 지표 | 성공 기준 |
|---|---|
| Primary | `H0: p_T <= p_C`, `H1: p_T > p_C`, alpha = 0.05 |
| Key Secondary | Home -> View Item Rate의 effect size와 95% CI 확인 |
| Guardrail | Item List -> View Item Rate가 Control 대비 -2.00%p 이상 악화되지 않을 것 |
| Downstream | Purchase Rate와 Revenue per Session은 방향성/CI만 확인 |

의사결정 기준:

```text
1. Primary metric의 one-sided p-value < 0.05
2. Home -> View Item Rate의 lift가 양수이고 95% CI가 0을 넘는지 확인
3. Item List -> View Item Rate의 95% CI lower bound가 -2.00%p보다 큰지 확인
4. Purchase Rate와 Revenue per Session은 decision-critical metric으로 사용하지 않음
```

## Simulated Result

실험 데이터는 아래 스크립트로 생성한다.

```text
scripts/generate_home_discovery_ab_test.py
```

출력 데이터:

```text
outputs/ab_tests/home_discovery_ab_test_synthetic.csv
outputs/ab_tests/home_discovery_ab_test_summary.csv
outputs/ab_tests/home_discovery_ab_test_power_plan.csv
```

실험 샘플:

```text
Control: 24,000 eligible first sessions
Treatment: 24,000 eligible first sessions
```

주요 결과:

| Metric | Control | Treatment | Absolute Lift | 95% CI | p-value |
|---|---:|---:|---:|---:|---:|
| Home -> Item List Rate | 35.73% | 39.73% | +3.99%p | [+3.13%p, +4.86%p] | < 0.001 |
| Home -> View Item Rate | 20.14% | 22.68% | +2.54%p | [+1.81%p, +3.28%p] | < 0.001 |
| Item List -> View Item Rate | 56.37% | 57.10% | +0.73%p | [-0.71%p, +2.18%p] | - |
| View Item -> Add to Cart Rate | 36.08% | 36.63% | +0.55%p | - | - |
| Purchase Rate | 1.03% | 1.15% | +0.12%p | - | - |
| Revenue per Session | 0.77 | 0.87 | +0.10 | - | - |

해석:

```text
Treatment는 Primary metric인 Home -> Item List Rate를 유의하게 개선했다.
Key Secondary metric인 Home -> View Item Rate도 함께 증가했고,
95% CI 기준으로도 0보다 큰 lift가 관측되었다.

Guardrail인 Item List -> View Item Rate의 95% CI lower bound는 -0.71%p로,
사전에 정의한 허용 하락폭 -2.00%p보다 크다.
따라서 낮은 의도 클릭만 늘어난 결과로 보기는 어렵다.

Purchase Rate와 Revenue per Session도 악화되지 않았지만,
본 실험의 직접 목표는 초기 discovery 개선이므로 downstream metric은 방향성 중심으로 해석한다.
```

Decision:

```text
Primary와 Key Secondary가 모두 개선되고,
Item List -> View Item guardrail의 non-inferiority 기준도 통과했으므로
discovery entry point 강화가 초기 상품 발견 행동을 개선한다는 제품 가설을 지지한다.

다만 본 실험으로 purchase/revenue 개선 효과가 직접 확인되었다고 판단하지는 않는다.
매출 성장이라는 Business Goal 아래에서,
초기 discovery 행동 레버의 causal validation에 성공한 것으로 해석한다.
```

## Modeled Business Impact

본 실험의 revenue impact는 A/B test에서 직접 검정한 매출 uplift가 아니라, 관측된 `Home -> View Item Rate` uplift가 기존 downstream baseline으로 이어진다는 가정하의 Fermi estimate다.

```text
Average Weekly Revenue = $49,477.5
Weekly eligible Home Landing sessions = 46,923 / 4 = 11,731
Home -> View Item absolute lift = +2.54%p

Additional View Item sessions per week
= 11,731 x 2.54%p
= 약 298
```

보수적 downstream 가정:

```text
View Item -> Purchase Rate = 약 5.1%
Revenue per Purchase = 약 $75

Modeled incremental revenue
= 298 x 5.1% x $75
= 약 $1,140 / week
```

전체 주 매출 대비:

```text
$1,140 / $49,477.5
= 약 +2.3%
```

해석:

```text
단일 Home discovery 실험으로 전체 주 매출 +2%대의 modeled revenue opportunity가 추정된다.

다만 이는 실제 매출 uplift 검정 결과가 아니라,
초기 discovery 행동 개선이 기존 downstream 전환율로 이어진다는 가정하의 추정치다.
```

## 다음 단계

```text
1. experiment effect를 주차별/디바이스별로 안정적으로 재확인한다.
2. purchase/revenue downstream metric을 더 긴 window에서 확인한다.
3. 실제 운영 실험에서는 SRM, bot/internal traffic, tracking QA를 함께 점검한다.
```
