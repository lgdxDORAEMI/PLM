# DESIGN.md

> LG ThinQ 내부에 포함되는 임산부 케어 서비스 UI를 위한 개발 디자인 기준서
>
> 기준 화면: 업로드된 모바일 화면설계서 PNG 24종 전체 검토
> 적용 대상: Flutter Web / Mobile responsive UI
> 문서 목적: 디자이너·프론트엔드 개발자·AI 코딩 도구가 동일한 시각 언어와 컴포넌트 규칙을 사용하도록 기준을 고정한다.

---

## 1. Design Direction

### 1.1 핵심 방향

이 서비스는 독립적인 육아/임신 앱처럼 보이면 안 된다. **LG ThinQ 안에서 자연스럽게 확장된 케어 기능**처럼 보여야 한다.

따라서 디자인의 우선순위는 다음과 같다.

1. **ThinQ와 이어지는 생활 관리 서비스 느낌**
2. **임산부가 오래 봐도 피로하지 않은 차분한 화면**
3. **건강 정보를 다루지만 병원 앱처럼 차갑지 않은 표현**
4. **AI가 만든 템플릿 같은 과도한 카드·그라데이션·둥근 요소를 지양**
5. **정보의 중요도에 따라 밀도와 강조 방식이 달라지는 실제 제품형 UI**
6. **한 손 조작, 명확한 상태 인지, 충분한 터치 영역**

### 1.2 시각적 키워드

`Calm / Caring / Home / Reliable / Soft-tech / ThinQ-compatible`

피해야 할 키워드:

`Baby app / Cute / Candy / Excessive pastel / AI-dashboard / Glassmorphism / Neumorphism`

---

## 2. Existing Screen Audit

업로드된 24개 화면을 다음 UI 그룹으로 분류한다.

### A. Profile setup

- `01_1_step_due_date`
- `01_2_step_body`
- `01_3_step_parity`
- `01_4_step_multiple`
- `01_5_step_allergy`
- `01_6_step_diagnosis`
- `01_7_profile_summary`
- `01_8_invite_partner`

현재 장점:

- 단계형 onboarding 구조가 명확하다.
- 질문 → 입력 → 다음 버튼 패턴이 안정적이다.
- 진행률이 항상 동일한 위치에 있어 학습 비용이 낮다.

개선 방향:

- 모든 선택지를 큰 pill 버튼으로 만들지 않는다.
- radio/select 성격의 항목은 `SelectionCard` 또는 `SegmentedOption`으로 구분한다.
- 진행률 bar는 높이를 줄이고 ThinQ shell에서 사용하는 절제된 indicator 느낌으로 조정한다.
- 입력란과 카드의 border contrast를 조금 높여 웹에서도 상태가 분명하게 보이도록 한다.

### B. Home & daily condition

- `02_0_home_before_check`
- `02_today_care`
- `04_0_home_merged`

현재 장점:

- 임신 주차가 첫 시선에 들어온다.
- 하루 루틴 진입점이 카드 구조로 명확하다.
- 상태 체크 후 결과가 홈으로 연결되는 흐름이 자연스럽다.

개선 방향:

- 원형 주차 표시를 서비스의 signature element로 유지한다.
- 대신 주변 장식 leaf/dot는 최소화하여 장난감 앱 같은 인상을 줄인다.
- 상단 hero와 하단 루틴 카드를 동일한 중요도로 보이지 않도록 높이와 여백을 차등 적용한다.

### C. Guides

- `05_0_meal_select`
- `05_meal_guide`
- `07_home_guide_B_smart_routine`
- `07_1_home_guide_share_done`
- `07_2_home_guide_partner_status`
- `08_body_care_guide`
- `09_sleep_care`

현재 장점:

- 식사/가사/건강/수면이 색으로 구분된다.
- 사용자의 오늘 상황에 대한 설명과 행동 제안이 연결된다.

개선 방향:

- 카테고리 전체 배경을 파스텔로 채우기보다 **아이콘·좌측 indicator·작은 tint 영역**으로 구분한다.
- 주요 행동 버튼은 카테고리색이 아니라 공통 CTA 규칙을 따른다.
- 카드 높이는 콘텐츠에 따라 달라져야 하며, 모든 카드가 동일한 템플릿처럼 보이지 않게 한다.

### D. Record / realtime / assistant

- `10_routine_record`
- `10_1_report_share_done`
- `11_realtime`
- `12_chat`
- `12_1_chat_meal_rechoose`
- `13_condition_calendar`

현재 장점:

- 완료 기록과 실시간 알림이 분리되어 있다.
- 챗봇이 단순 채팅이 아니라 현재 상태를 전제로 응답하는 구조다.
- 캘린더에서 상태의 흐름을 확인할 수 있다.

개선 방향:

- 실시간 알림은 색만으로 위험도를 표현하지 않는다.
- 챗봇 메시지 bubble의 핑크 면적을 줄이고 ThinQ 계열의 neutral surface를 기본으로 사용한다.
- 공유 성공 modal은 purple CTA 대신 product-wide primary CTA로 통일한다.

---

## 3. LG ThinQ Alignment

LG의 공식 디자인 시스템은 제품에서 가져온 **둥근 사각형, 원, stadium 등 친근한 기하 형태**를 핵심 조형으로 사용하며, LG 브랜드 컬러는 Active Red, Heritage Red와 Warm Grey/White/Black의 neutral 조합을 중심으로 한다.

이 서비스에서는 LG 브랜드를 그대로 복제하기보다 다음 방식으로 연결한다.

### 3.1 Use

- 둥근 사각형 + 원형 indicator 조합
- 넓은 white/neutral surface
- 작은 면적의 red/rose accent
- 단순한 line icon
- 정돈된 정보 계층
- 생활 환경과 연결되는 카드 구조
- 필요할 때만 사용하는 soft tint background

### 3.2 Avoid

- 모든 화면에 LG Active Red를 대면적으로 사용
- LG 로고 형태를 장식 요소로 반복 사용
- ThinQ 기존 제품 제어 UI를 그대로 복제
- 브랜드 red와 maternity pink를 동시에 경쟁시키는 구성

### 3.3 Recommended relationship

```text
ThinQ App Shell
└─ Maternity Care module
   ├─ ThinQ neutral layout grammar
   ├─ LG-compatible geometry
   ├─ Maternity-specific rose accent
   └─ Health/context semantic colors
```

즉, **구조는 ThinQ에 가깝게, 정서적 accent는 임산부 케어에 맞게** 설계한다.

---

## 4. Color System

### 4.1 Brand reference

LG official reference colors:

| Token | Hex | Usage |
|---|---:|---|
| LG Active Red | `#FD312E` | 브랜드 핵심 색상. 본 서비스의 일반 CTA에는 직접 사용하지 않음 |
| LG Heritage Red | `#A50034` | 강한 브랜드/중요 강조에 제한적으로 사용 |
| LG Warm Grey | `#F0ECE4` | warm neutral reference |
| White | `#FFFFFF` | base surface |
| Black | `#000000` | brand reference only; 실제 body text는 softer black 사용 |

### 4.2 Product palette

개발에서는 아래 product token을 기본값으로 사용한다.

```yaml
color:
  bg:
    canvas: "#F8F7F5"
    surface: "#FFFFFF"
    surface_subtle: "#F5F3F1"
    elevated: "#FFFFFF"

  text:
    primary: "#1F1F1F"
    secondary: "#65615F"
    tertiary: "#8A8582"
    inverse: "#FFFFFF"
    disabled: "#AAA6A3"

  border:
    subtle: "#E9E5E2"
    default: "#DDD8D5"
    strong: "#C9C3BF"

  primary:
    50: "#FFF2F5"
    100: "#FCE4EA"
    200: "#F6C6D2"
    300: "#EFA2B5"
    400: "#E47A98"
    500: "#D95B7F"
    600: "#C6426A"
    700: "#A93257"
    800: "#842642"
    900: "#621C31"

  semantic:
    success: "#357861"
    success_bg: "#EDF6F1"
    warning: "#9A6A17"
    warning_bg: "#FBF5E8"
    danger: "#B64048"
    danger_bg: "#FBEEEE"
    info: "#416C8A"
    info_bg: "#EEF4F8"

  category:
    meal: "#5F846A"
    meal_bg: "#EEF5EF"
    home: "#A85B70"
    home_bg: "#FAF0F3"
    body: "#5C7191"
    body_bg: "#EEF2F8"
    sleep: "#7560A3"
    sleep_bg: "#F2EFF8"
```

### 4.3 Color rules

- 한 화면에서 강한 accent는 최대 1개 계열만 사용한다.
- `primary`는 CTA, 선택 상태, 핵심 데이터에만 사용한다.
- 카테고리 색은 버튼보다 **label / icon / indicator / background tint**에 사용한다.
- 긴 텍스트를 pastel 배경 위에 직접 배치하지 않는다.
- 위험/경고 상태는 반드시 icon + text label을 함께 사용한다.
- 임산부 대상이라는 이유만으로 전체 화면을 분홍색으로 만들지 않는다.

---

## 5. Typography

### 5.1 Font

우선순위:

```text
Pretendard Variable
→ Noto Sans KR
→ system sans-serif
```

LG ThinQ host app과 동일한 사내 font가 제공되는 경우 해당 font를 최우선 적용한다.

### 5.2 Type scale

```yaml
typography:
  display:
    size: 28
    lineHeight: 38
    weight: 700

  title1:
    size: 24
    lineHeight: 34
    weight: 700

  title2:
    size: 20
    lineHeight: 29
    weight: 700

  heading:
    size: 18
    lineHeight: 27
    weight: 700

  body1:
    size: 16
    lineHeight: 25
    weight: 400

  body2:
    size: 14
    lineHeight: 22
    weight: 400

  label:
    size: 13
    lineHeight: 19
    weight: 600

  caption:
    size: 12
    lineHeight: 18
    weight: 400
```

### 5.3 Typography rules

- 임신 주차, 오늘 상태 등 핵심 숫자는 text hierarchy로 강조하고 장식으로 과도하게 강조하지 않는다.
- 본문 최소 14px, 핵심 정보 최소 16px.
- 회색 설명 문구는 `text.tertiary` 이하 명암을 사용하지 않는다.
- bold는 제목, 상태, 숫자에만 사용한다.
- 한 카드 안에서 bold weight는 최대 2단계까지만 사용한다.

---

## 6. Spacing & Layout

### 6.1 Base grid

4pt grid 사용.

```yaml
space:
  1: 4
  2: 8
  3: 12
  4: 16
  5: 20
  6: 24
  8: 32
  10: 40
  12: 48
```

### 6.2 Page margins

- Mobile `< 600`: 20px
- Tablet `600–1023`: 28px
- Web `>= 1024`: content max-width 480–720px depending on page type
- health/detail form page: max-width 560px
- dashboard/home page: max-width 720px

### 6.3 Vertical rhythm

```text
AppBar → Page title: 24–28
Page title → intro/supporting copy: 8
Section → Section: 28–36
Heading → content: 12–16
Card → Card: 10–12
Card internal padding: 16–20
Bottom nav above content safe area: >= 24
```

모든 영역에 16px을 반복하는 방식은 피한다. 중요도에 따라 8/12/16/24/32를 명확히 구분한다.

---

## 7. Shape Language

### 7.1 Radius

```yaml
radius:
  xs: 6
  sm: 10
  md: 14
  lg: 18
  xl: 24
  pill: 999
```

사용 원칙:

- input: `12`
- standard card: `14–16`
- large hero card: `18–20`
- modal: `20–24`
- tag/chip: pill
- primary button: `14–16`; 모든 버튼을 pill로 만들지 않는다.

### 7.2 Natural variation

AI 생성 느낌을 줄이기 위해 컴포넌트 계층에 따른 radius 차이를 유지한다.

잘못된 예:

```text
모든 카드 radius 24
모든 버튼 pill
모든 섹션 pastel box
```

권장:

```text
hero 20
standard card 16
input 12
inline action 10
chip pill
```

---

## 8. Elevation & Border

대부분 border 기반으로 구성하고 shadow 사용을 최소화한다.

```yaml
elevation:
  0: none
  1: "0 1px 2px rgba(25, 20, 18, 0.05)"
  2: "0 6px 20px rgba(25, 20, 18, 0.08)"
  modal: "0 14px 40px rgba(25, 20, 18, 0.16)"
```

- 일반 카드: border + no shadow
- floating menu / modal: shadow 사용
- hover 가능한 web card: elevation 0 → 1
- shadow를 카드 구분의 기본 수단으로 사용하지 않는다.

---

## 9. Iconography

### Style

- 20 / 24px line icon 기준
- stroke 1.7–2.0
- rounded cap / rounded join
- filled icon은 bottom navigation selected와 핵심 status에만 사용
- emoji를 기능 icon으로 사용하지 않는다.

### Category mapping

- 식사: bowl / utensils / leaf
- 가사: home / laundry / cart
- 건강: heart-pulse / body / stretch
- 수면: moon / bed
- 기록: calendar-check / clipboard
- 실시간: activity / sensor / notification
- 챗봇: message / sparkle는 보조적으로만 사용

AI 기능임을 `sparkle`만으로 표시하지 않는다. 가능하면 `AI 추천`, `상태 기반 추천` 등 text label과 같이 제공한다.

---

## 10. Core Components

## 10.1 AppShell

- ThinQ host navigation이 존재하면 host shell을 우선 사용한다.
- 독립 실행 모드에서만 자체 bottom navigation을 사용한다.
- bottom nav 높이: 64–72px + safe area
- nav item: icon 24 + label 11–12
- selected color: primary 600
- inactive: text tertiary

## 10.2 TopAppBar

```text
height: 56
left: back or empty
center: title
right: optional action
border-bottom: subtle only when scroll context requires it
```

중앙 title을 항상 굵게 하지 않는다. detail 화면은 16/600 정도로 충분하다.

## 10.3 PrimaryButton

```yaml
height: 52
radius: 14
paddingX: 20
font: 15/600
background: primary.600
text: white
```

states:

- default: primary 600
- hover(web): primary 700
- pressed: primary 800
- disabled: `#E4E0DE` / text disabled
- focus: 2px focus ring

페이지 하단 CTA는 mobile에서 full width 사용 가능하지만 모든 화면에 sticky CTA를 강제하지 않는다.

## 10.4 SecondaryButton

- white surface
- 1px border default
- primary text 또는 text primary
- action hierarchy가 낮을 때 사용

## 10.5 SelectionCard

기존 큰 pill 선택지를 대체하는 표준 컴포넌트.

```text
min-height: 52
radius: 14
padding: 14 16
border: default
selected:
  background primary.50
  border primary.400
  optional trailing check
```

2개 옵션은 가로 배치 가능, 3개 이상은 wrap/grid 사용.

## 10.6 InputField

```text
height: 52
radius: 12
background: white
border: default
label: 12–13 / secondary
value: 15–16 / primary
```

focus:

- border primary 500
- ring primary 100

error:

- danger border
- error text 아래 12px

placeholder만으로 field 의미를 전달하지 않는다.

## 10.7 InfoCard

기본 구조:

```text
[optional icon] title          [optional status]
description
[optional content / action]
```

- radius 16
- background white
- border subtle
- padding 16
- section 간 10–12px

카테고리를 표현할 때 card 전체를 진한 pastel로 채우기보다 top strip / icon container / small tinted region 사용.

## 10.8 HeroStatusCard

Home 핵심 component.

```text
Greeting / context
Pregnancy week circular indicator
1–2 line key message
optional primary action
```

원형 indicator는 LG design system의 circle geometry와도 잘 연결되므로 유지한다.

단, decorative leaf/dot는 최대 2–3개로 제한한다.

## 10.9 ProgressMetric

몸 상태 체크의 통증/피로도 등에 사용.

- label + severity text + segmented meter
- 최소 5단계
- color alone 금지
- `좋아요 / 보통이에요 / 심해요` 같은 text state 병기

## 10.10 GuideTaskCard

가사/건강 루틴의 action card.

```text
icon | task title                     status/action
     | short metadata
```

- category tint는 icon background에만 사용 가능
- action은 text button / compact outline button
- 완료는 checkbox + 완료 text

## 10.11 ChatBubble

User:

- primary 500~600 background
- white text
- radius 16, one corner 6
- max-width 78%

Assistant:

- surface/subtle background
- dark text
- optional `AI` label은 작은 badge
- max-width 84%

제안 버튼은 bubble 내부가 아니라 bubble 아래 action row로 분리할 수 있다.

## 10.12 Modal

- dim: rgba(0,0,0,0.42)
- radius: 22
- padding: 24
- icon: 40–48
- title + short confirmation copy
- 1개의 primary action을 우선

현재 보라색 확인 버튼은 제거하고 product primary color로 통일한다.

---

## 11. Screen-specific Rules

### 11.1 Profile setup

구조:

```text
AppBar
Progress
Question title
Supporting text
Input / choices
Flexible space
Primary CTA
Optional helper text
```

- `다음` 버튼은 화면 최하단에 고정하기보다 viewport가 짧을 때만 sticky 처리한다.
- 긴 화면에서는 content 흐름 뒤에 둔다.
- 1/6 indicator와 progress bar 중 하나만 강하게 보이게 한다.

### 11.2 Profile summary

현재 모든 항목이 유사한 회색 row로 반복되므로 아래처럼 개선한다.

```text
Verification notice
Core pregnancy info card
Health info section
Partner section
CTA
```

모든 row에 chevron을 넣지 않는다. 실제 수정 가능한 항목에만 chevron 또는 edit action 사용.

### 11.3 Home

home hierarchy:

1. 현재 임신 주차
2. 오늘 주의/상태
3. 오늘의 케어
4. 카테고리별 routine
5. secondary information

현재의 4개 pastel routine card는 유지 가능하지만 saturation과 배경 면적을 줄인다.

### 11.4 Today condition

- severity는 meter + label을 사용한다.
- 모든 항목을 pink로 표시하지 않는다.
- 정상 상태는 neutral, 주의 필요 상태만 semantic color를 사용한다.

### 11.5 Meal guide

- 식사 이미지는 사진/실사 스타일 또는 단순 product illustration 중 하나로 통일한다.
- AI 생성형 음식 일러스트를 여러 스타일로 혼용하지 않는다.
- 추천 이유를 `왜 추천했나요` 형태의 작은 evidence row로 제공한다.

### 11.6 Housework guide

- task grouping은 `오늘은 이것만`, `가전이 대신`, `가족과 나누기` 같이 인간적인 구획을 사용할 수 있다.
- 기계적인 1/2/3 numbered dashboard 구성은 최소화한다.
- ThinQ 기기 제어 연동 action은 LG device iconography와 연결한다.

### 11.7 Body care

- 통증 부위 bar는 clinical red 대신 blue-grey / rose accent 사용.
- 영상 썸네일은 실제 콘텐츠 썸네일이 있으면 이미지 사용.
- `허리에 무리 가지 않기`처럼 행동 중심의 문구를 우선한다.

### 11.8 Sleep guide

현재 purple category를 유지하되 saturation을 낮춘다.

- 환경 설정 card는 2열 grid 가능
- 선택 완료 상태는 checkbox + small tint
- `수면 루틴 시작하기`는 primary CTA

### 11.9 Realtime

우선순위:

```text
Sensor status
Latest important alert
Recent events
```

- connected/on 상태를 최상단 compact panel로 표시
- 경고 목록은 timestamp, type, action을 분리
- 위험도별 icon shape도 달리한다.

### 11.10 Chat

- 의료 진단처럼 단정적으로 보이는 문구 금지
- 추천/가이드임을 UI에서도 구분한다.
- 선택형 quick replies는 2–3개 이하
- long answer는 section card로 구조화

### 11.11 Calendar

- 날짜 원형 fill을 너무 많이 사용하지 않는다.
- condition level은 small dot / ring / tint로 구분
- selected date만 strong circle
- legend는 항상 노출

---

## 12. Pregnancy-user UX Considerations

임산부 사용자를 이유로 ‘여성적인’ 시각 요소를 과도하게 추가하지 않는다. 대신 사용 피로와 정보 인지 관점에서 설계한다.

### 12.1 Touch

- 최소 touch target: 44x44px
- 권장 주요 action: 48–52px 높이
- close/back icon도 hit area는 44px 확보

### 12.2 Readability

- body text 최소 14px
- 주요 상태 16px 이상
- line-height 1.45 이상
- 연한 pink 위 연한 grey text 사용 금지

### 12.3 Cognitive load

한 화면에서 사용자에게 동시에 요구하는 결정은 최대 1개의 primary task로 제한한다.

예:

```text
오늘 상태 입력 + 식사 선택 + 운동 선택 + 공유 여부
```

를 한 화면에서 동시에 묻지 않는다.

### 12.4 Health communication

- `위험`, `정상`을 색 하나로만 표시하지 않는다.
- 불필요하게 불안감을 만드는 문구를 사용하지 않는다.
- 응급/전문가 상담이 필요한 정보는 일반 추천 카드와 명확히 구분한다.
- 의료적 판단이 아닌 경우 `추천`, `참고`, `도움이 될 수 있어요` 등 정확한 표현을 사용한다.

### 12.5 Motion

- 기본 transition: 160–220ms
- large layout transition: 240–300ms
- 반복 pulse / floating animation 금지
- reduced motion preference 대응

---

## 13. Accessibility

최소 WCAG 2.1 AA 수준을 목표로 한다.

- 일반 text contrast: 4.5:1 이상
- large text: 3:1 이상
- focus state는 web에서 항상 시각적으로 노출
- keyboard navigation 가능
- form field label 연결
- screen reader semantics 제공
- icon-only button은 semantic label 필수
- status를 color only로 전달하지 않음

Flutter에서는 `Semantics`, `Tooltip`, `Focus`, `Shortcuts/Actions`를 적극 사용한다.

---

## 14. Responsive Rules for Flutter Web

### Breakpoints

```yaml
breakpoint:
  mobile: 0
  tablet: 600
  desktop: 1024
  wide: 1440
```

### Mobile

- single column
- bottom navigation
- full-width CTA 허용

### Tablet

- content width 560–680
- 2-column metric/task card 가능
- bottom nav 또는 host shell 유지

### Desktop Web

모바일 화면을 화면 중앙에 좁게 그대로 띄우지 않는다.

권장:

```text
max-width 720
2-column only for secondary content
main task remains single dominant column
```

form/onboarding은 520–560px 중심형 layout이 더 적합하다.

---

## 15. Design Tokens for Flutter

권장 구조:

```text
lib/
  design_system/
    tokens/
      app_colors.dart
      app_spacing.dart
      app_radius.dart
      app_typography.dart
      app_elevation.dart
    theme/
      app_theme.dart
      app_component_theme.dart
    components/
      app_button.dart
      app_card.dart
      selection_card.dart
      status_card.dart
      info_banner.dart
      app_input.dart
      progress_metric.dart
      category_chip.dart
      bottom_navigation.dart
```

### Example token naming

```dart
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double input = 12;
  static const double card = 16;
  static const double hero = 20;
  static const double modal = 22;
  static const double pill = 999;
}
```

값을 개별 screen에 hard-code하지 않는다.

---

## 16. Component Architecture

권장 계층:

```text
Primitive
├─ AppText
├─ AppIcon
├─ AppDivider
└─ AppSurface

Control
├─ AppButton
├─ AppInput
├─ AppChip
├─ SelectionCard
├─ ToggleRow
└─ ProgressMetric

Composite
├─ HeroStatusCard
├─ GuideTaskCard
├─ HealthStatusCard
├─ RecommendationCard
├─ PartnerShareCard
└─ RealtimeAlertCard

Feature
├─ PregnancyProfileForm
├─ TodayConditionForm
├─ DailyCareSection
├─ MealGuideSection
├─ HouseworkGuideSection
├─ SleepGuideSection
├─ ChatConversation
└─ ConditionCalendar
```

Feature widget가 직접 색상/spacing 값을 생성하지 않고 design token 또는 공통 component를 사용한다.

---

## 17. Avoiding the “AI-generated UI” Look

다음 패턴은 금지한다.

### 17.1 Too many cards

화면의 모든 텍스트 블록을 card로 감싸지 않는다.

`section title + plain content`만으로 충분하면 card를 사용하지 않는다.

### 17.2 Excessive pastel

4개의 카드가 있다면 4개 모두 서로 다른 pastel background를 쓰지 않는다.

권장:

- surface는 white
- category icon container만 tint
- 필요한 카드 1개만 soft background

### 17.3 Uniform geometry

모든 요소의 radius, padding, 높이가 동일한 것을 피한다.

계층에 따라 크기를 달리한다.

### 17.4 Decorative gradients

CTA, card, header에 의미 없는 gradient를 사용하지 않는다.

LG 공식 gradient도 brand hero/key visual이 필요한 경우에만 제한적으로 사용한다.

### 17.5 Floating sparkle / blobs

임의의 sparkle, 별, blob, glow를 AI 기능 표현으로 반복 사용하지 않는다.

### 17.6 Placeholder illustration

사람, 임산부, 음식, 집안일 이미지를 AI 일러스트 스타일로 무작위 생성해 섞지 않는다.

이미지 스타일이 필요하면 한 가지 art direction으로 고정한다.

### 17.7 Generic copy

`당신을 위한 맞춤 케어`, `더 나은 하루를 시작해보세요` 같은 추상 문구를 반복하지 않는다.

상태와 행동이 연결된 구체적인 문구를 사용한다.

예:

```text
X 허리 건강을 위한 맞춤 케어예요
O 오늘 허리 통증이 평소보다 높아 5분 스트레칭을 먼저 추천해요
```

---

## 18. Content Tone

### Preferred

- 짧다.
- 현재 상태를 먼저 말한다.
- 다음 행동을 구체적으로 제안한다.
- 불안감을 과장하지 않는다.

예:

```text
오늘은 허리에 부담을 줄이는 게 좋아요.
5분 스트레칭부터 시작해보세요.
```

### Avoid

```text
AI가 분석한 당신만을 위한 완벽한 건강 솔루션입니다.
```

---

## 19. Recommended Visual Changes to Current Mockups

현재 PNG 시안을 개발에 반영할 때 아래 변경을 우선 적용한다.

### Must change

1. 전체 배경 `#FFFFFF` 단일 사용 → `#F8F7F5` canvas + white surface 구조
2. 현재 strong pink CTA → 조금 더 깊고 차분한 rose (`primary.600`)
3. 모든 rounded button → standard radius 14–16, chip만 pill
4. category pastel card → white card + tint icon/header 방식으로 축소
5. purple 공유 CTA → product primary color로 통일
6. card border contrast 소폭 강화
7. 회색 보조 text 명암 강화
8. modal radius/CTA/style 공통화
9. chat assistant bubble을 neutral surface로 변경
10. calendar의 다수 pink circle을 dot/ring 중심으로 단순화

### Keep

1. 임신 주차 원형 indicator
2. 4개 주요 카테고리 구분
3. onboarding 단계 구조
4. 오늘 컨디션 segmented meter
5. partner sharing concept
6. bottom navigation information architecture
7. 짧은 문장 중심의 copy
8. 충분한 white space

---

## 20. UI Quality Checklist

개발 완료 전 각 화면에서 확인한다.

### Visual

- [ ] 한 화면에 강한 accent color가 2개 이상 경쟁하지 않는가?
- [ ] 모든 요소가 card로 감싸져 있지 않은가?
- [ ] pill button을 과도하게 사용하지 않았는가?
- [ ] radius hierarchy가 지켜졌는가?
- [ ] section 간 vertical rhythm이 명확한가?
- [ ] category tint가 과도하지 않은가?

### Interaction

- [ ] touch target이 44px 이상인가?
- [ ] hover/focus/pressed/disabled 상태가 있는가?
- [ ] loading/empty/error 상태가 설계되어 있는가?
- [ ] primary action이 화면에서 하나로 명확한가?

### Accessibility

- [ ] text contrast가 충분한가?
- [ ] color만으로 상태를 전달하지 않는가?
- [ ] keyboard navigation이 가능한가?
- [ ] screen reader label이 있는가?

### Product consistency

- [ ] LG ThinQ host shell과 navigation이 충돌하지 않는가?
- [ ] 서비스 내부 primary color가 화면마다 바뀌지 않는가?
- [ ] 동일 컴포넌트가 화면마다 다른 padding/radius를 갖지 않는가?
- [ ] 건강 정보가 의료 진단처럼 표현되지 않는가?

---

## 21. Implementation Priority

### Phase 1 — Foundation

1. color / typography / spacing / radius token
2. `ThemeData`
3. Button
4. Input
5. Card
6. SelectionCard
7. TopAppBar
8. BottomNavigation

### Phase 2 — Domain components

1. HeroStatusCard
2. ProgressMetric
3. GuideTaskCard
4. RealtimeAlertCard
5. ChatBubble
6. ConditionCalendar
7. PartnerShareCard

### Phase 3 — Screen migration

1. Profile setup
2. Home
3. Today condition
4. Meal
5. Housework
6. Body care
7. Sleep
8. Record
9. Realtime
10. Chat
11. Calendar

모든 screen을 동시에 스타일 수정하지 말고 공통 component를 먼저 완성한 뒤 migration한다.

---

## 22. Source References

LG brand/design 방향을 확인한 공식 자료:

- LG Global Design System: https://www.lg.com/global/our-identity/design-system/
- LG Global Color System: https://www.lg.com/global/our-identity/color/
- LG ThinQ Google Play: https://play.google.com/store/apps/details?id=com.lgeha.nuts

참고 원칙:

- LG의 공식 UI 자산을 무단 복제하는 것이 아니라, 공개된 브랜드 원칙과 ThinQ의 neutral/product-oriented tone을 서비스 디자인에 맞게 재해석한다.
- 실제 개발 단계에서는 프로젝트에 제공되는 LG 사내 디자인 시스템, ThinQ 공통 컴포넌트 또는 브랜드 가이드가 있다면 해당 문서를 이 문서보다 우선한다.

---

## Summary

이 서비스의 최종 디자인은 **“임산부용 핑크 앱”이 아니라 “LG ThinQ가 사용자의 임신 기간까지 생활 환경을 케어해주는 기능”**처럼 보여야 한다.

이를 위해:

- ThinQ와 어울리는 neutral base를 사용한다.
- 임산부 케어의 rose color는 필요한 부분에만 사용한다.
- 둥근 형태는 유지하되 모든 요소를 pill로 만들지 않는다.
- category pastel의 사용량을 줄인다.
- 정보 계층과 여백을 통해 중요도를 표현한다.
- 접근성과 건강 정보 전달의 명확성을 우선한다.
- 공통 token/component 기반으로 구현해 화면별 임의 스타일을 막는다.

