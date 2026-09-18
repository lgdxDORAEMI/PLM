# PLM Product Design System

> 최신 요구사항과 화면 계약을 구현 가능한 UI 규칙으로 변환한 문서다. 화면설계서와 PNG의 기능 구조는 유지하되, 시각적 결과물은 이 문서를 기준으로 재설계한다.

## 1. Purpose

PLM은 임신 중인 아내와 파트너가 일상 상태, 루틴, 기록, 리포트, 요청을 함께 관리하는 WebApp이다. 디자인 시스템은 다음 목표를 가진다.

- 아내에게는 자기 상태와 오늘의 행동을 빠르게 이해하고 기록할 수 있는 안정적인 경험을 제공한다.
- 파트너에게는 일정, 리포트, 알림, 요청을 명확히 구분해 행동으로 연결하는 경험을 제공한다.
- AI 추천은 과장된 자동화가 아니라 근거와 상태를 설명하는 보조 수단으로 표현한다.
- Mobile, Tablet, Desktop에서 각 화면의 정보량과 행동 위치를 다시 구성한다.
- Flutter 구현에서 동일한 토큰과 컴포넌트 계약을 재사용할 수 있게 한다.

이 문서는 특정 기업의 브랜드 디자인 시스템을 복제하지 않는다. PLM만의 독립적인 제품 디자인 시스템을 정의한다.

## 2. Source of Truth

기능과 화면을 판단할 때 아래 순서를 따른다.

1. `docs/requirements/04_1_기능요구사항명세서.md`
2. `docs/requirements/03_유스케이스명세서.md`
3. `docs/requirements/01_MVP.md`
4. `docs/requirements/01_PRD.md`
5. `docs/requirements/04_2_비기능요구사항명세서.md`
6. `docs/requirements/화면설계서0916.pdf`
7. `docs/screens/**`
8. `docs/development/ROUTE_MAP.md`
9. `docs/SCREEN_IMPLEMENTATION_MAP.md`
10. 이 문서의 시각 및 상호작용 규칙

충돌 시 다음 원칙을 적용한다.

- 기능, 상태, Actor 권한은 requirements가 우선이다.
- Route와 화면 전환은 `ROUTE_MAP.md`가 우선이다.
- Screen ID와 구현 추적은 `SCREEN_IMPLEMENTATION_MAP.md`가 우선이다.
- 화면설계서와 PNG는 콘텐츠, 정보 구조, 상태의 참고 자료다.
- 색상, 타이포그래피, 여백, 그리드, 컴포넌트 외형, 반응형 배치는 `DESIGN.md`가 최종 기준이다.
- PNG를 픽셀 단위로 복제하지 않는다.
- Screen ID의 `-1`, `-2` 등 접미 상태는 Route Map에서 명시하지 않는 한 별도 Route가 아니다.

## 3. Design Principles

### 3.1 Calm clarity

한 화면의 핵심 질문과 Primary CTA를 하나로 제한한다. 중요한 상태는 색상만으로 구분하지 않고 제목, 아이콘, 보조 문구를 함께 사용한다.

### 3.2 Warm, not decorative

따뜻함은 크림 계열의 중립 표면, 자연스러운 여백, 낮은 채도의 포인트로 표현한다. 임산부 서비스라는 이유로 전체를 pink 또는 pastel UI로 만들지 않는다.

### 3.3 Information before ornament

추천 결과, 상태, 일정, 요청의 의미가 장식보다 먼저 읽혀야 한다. 카드는 정보 경계가 필요할 때만 사용하며 모든 요소를 카드로 감싸지 않는다.

### 3.4 One decision at a time

입력 화면은 한 단계의 판단에 집중한다. 복수 행동이 필요하면 Primary, Secondary, Tertiary 순서를 시각적으로 명확히 한다.

### 3.5 Explainable AI

AI 결과에는 추천 내용, 추천 이유, 대안 또는 수정 경로, 생성 상태를 함께 제공한다. AI가 사용자의 결정을 대신하는 표현을 피한다.

### 3.6 Actor-aware experience

Wife와 Partner는 같은 서비스 안에 있지만 목적과 권한이 다르다. 동일한 내비게이션을 강제로 공유하지 않으며, Actor 전환을 일반 탭처럼 제공하지 않는다.

### 3.7 Responsive by composition

화면 폭을 늘리는 것만으로 반응형을 만들지 않는다. 넓은 화면에서는 관련 패널을 병렬 배치하고, 선택 항목의 상세 정보를 같은 맥락 안에서 보여준다.

## 4. ThinQ Compatibility

ThinQ와의 일관성은 브랜드 색상 복제가 아닌 다음 특성으로 만든다.

- 명확한 상단 제목과 현재 상태
- 핵심 콘텐츠가 먼저 보이는 계층 구조
- 낮은 정보 밀도와 충분한 여백
- 한눈에 이해되는 카드와 리스트 구분
- 예측 가능한 뒤로가기, 저장, 완료 동작
- Mobile의 하단 중심 행동과 주요 목적지 내비게이션
- 밝고 중립적인 surface와 절제된 elevation
- 기기 상태처럼 읽기 쉬운 상태 라벨과 즉각적인 피드백

다음 항목은 사용하지 않는다.

- LG Active Red
- LG Heritage Red
- LG 공식 Gradient
- LG 공식 Color Token 또는 이를 이름만 바꾼 파생 토큰

공식 로고 색상이나 브랜드 자산에서 색을 추출해 제품 팔레트로 확장하지 않는다. PLM 컴포넌트에는 제품 소유의 semantic token만 사용한다.

## 5. Color

### 5.1 Product palette

팔레트 방향은 `neutral`, `warm`, `muted`, `calm`, `premium`, `soft-tech`다. 기본 강조색은 낮은 채도의 mineral teal이며, warm clay는 제한된 보조 역할만 한다.

| Token | Value | Usage |
|---|---:|---|
| `canvas` | `#F6F4EF` | Pregnancy 콘텐츠 구획, 루틴·생활관리의 제한적 보조 면 |
| `surface` | `#FFFEFB` | 앱 공통 shell, 기본 카드, dialog, sheet |
| `surface-subtle` | `#F0EEE8` | 구획 배경, 비활성 영역 |
| `surface-raised` | `#FFFFFF` | 부유 패널, 선택 상세 |
| `text-primary` | `#202624` | 제목, 핵심 수치 |
| `text-secondary` | `#58615D` | 본문, 설명 |
| `text-tertiary` | `#68716C` | 메타 정보, placeholder. 밝은 canvas에서 일반 텍스트 4.5:1 이상 확보 |
| `border-subtle` | `#DEDCD4` | 카드와 구획 경계 |
| `border-strong` | `#C7C9C1` | 입력, 선택 경계 |
| `primary` | `#3D7165` | Primary CTA, 선택, 현재 위치 |
| `primary-hover` | `#315C53` | hover |
| `primary-pressed` | `#284A43` | pressed |
| `primary-soft` | `#E4F0EC` | 선택 배경, AI 보조 면 |
| `accent-warm` | `#8A684F` | 제한적 강조, household 맥락 |
| `accent-warm-soft` | `#F4EEE8` | warm 보조 면 |
| `focus-ring` | `#5E9185` | 키보드 focus outline |
| `scrim` | `#20262499` | modal/sheet 배경 |

### 5.2 Semantic colors

| State | Foreground | Background | Rule |
|---|---:|---:|---|
| Success | `#39715C` | `#EAF4EF` | 저장·완료·연동 성공 |
| Warning | `#8B6728` | `#F7F1E4` | 확인 필요·지연 |
| Error | `#A54742` | `#F8ECEA` | 실패·파괴적 행동 |
| Info | `#496F8A` | `#EAF1F5` | 안내·새 알림 |
| Disabled | `#8A908D` | `#ECECE8` | 비활성 상태 |

Error 색상은 오류 의미에만 사용한다. Primary CTA나 선택 상태에 대체 사용하지 않는다.

### 5.3 Category accents

카테고리 색상은 작은 아이콘 배경, tag, 그래프 범례에만 사용한다. 전체 화면이나 큰 카드 배경을 카테고리 색으로 채우지 않는다.

| Category | Accent | Soft surface |
|---|---:|---:|
| Meal | `#657A50` | `#F0F3EA` |
| Household | `#8A684F` | `#F4EEE8` |
| Health | `#526F88` | `#ECF1F5` |
| Sleep | `#696787` | `#EFEEF5` |
| AI | `#3D7165` | `#E4F0EC` |
| Partner | `#596D76` | `#EDF1F2` |

### 5.4 Color rules

- 텍스트와 배경은 WCAG 2.2 AA 명암비를 충족한다.
- 앱 공통 shell은 `surface` 또는 `surface-raised`를 사용하고 `canvas`로 화면 전체를 채우지 않는다.
- `primary-soft`와 category soft surface는 선택·추천·아이콘·작은 상태 영역에 한정한다.
- 상태를 색상 하나로 전달하지 않는다.
- 같은 의미에는 같은 semantic token을 사용한다.
- gradient는 기본 표현 수단으로 사용하지 않는다.
- 임의 hex 값을 widget에 직접 입력하지 않는다.
- dark mode는 현재 MVP 범위가 아니며 토큰 구조만 확장 가능하게 유지한다.

## 6. Typography

한국어 가독성과 WebApp 호환성을 우선한다.

```text
Font family: Pretendard Variable, "Noto Sans KR", system-ui, sans-serif
Number fallback: Inter, system-ui, sans-serif
```

| Style | Size / Line height | Weight | Usage |
|---|---|---:|---|
| Display | 36 / 46 | 700 | Desktop 핵심 결과, 큰 수치 |
| Heading 1 | 28 / 38 | 700 | 화면 제목 |
| Heading 2 | 22 / 31 | 700 | 주요 section |
| Heading 3 | 18 / 27 | 600 | 카드·패널 제목 |
| Body Large | 17 / 27 | 500 | 핵심 설명, 추천 이유 |
| Body | 15 / 24 | 400 | 기본 본문 |
| Label | 14 / 20 | 600 | 입력 label, button |
| Caption | 12 / 18 | 500 | 날짜, 상태 보조 정보 |

규칙:

- 본문은 Mobile에서도 14px 미만으로 내리지 않는다.
- 수치와 단위는 하나의 의미 단위로 묶고 숫자를 우선 읽히게 한다.
- 버튼은 짧은 동사형 문구를 사용한다.
- 긴 설명은 본문 폭을 70자 안팎으로 제한한다.
- 줄임표는 목록의 부가 설명에만 사용하고 핵심 상태·요청 문구를 자르지 않는다.

## 7. Spacing

4px 기반의 토큰을 사용한다.

| Token | Value | Usage |
|---|---:|---|
| `space-1` | 4 | icon 내부, 작은 간격 |
| `space-2` | 8 | label과 값, compact item |
| `space-3` | 12 | control 내부 |
| `space-4` | 16 | Mobile 기본 간격 |
| `space-5` | 20 | 카드 내부 |
| `space-6` | 24 | section 내부 |
| `space-8` | 32 | section 사이 |
| `space-10` | 40 | 큰 구획 |
| `space-12` | 48 | Desktop column 간격 |
| `space-16` | 64 | Desktop section 간격 |

- touch target 사이에는 최소 8px를 둔다.
- 같은 그룹 내부 간격은 그룹 사이 간격보다 작아야 한다.
- 카드 중첩 시 외부 카드 24px, 내부 그룹 16px을 기본값으로 한다.
- 화면 하단 고정 CTA가 있으면 콘텐츠에 CTA 높이와 safe area를 합한 여백을 확보한다.

## 8. Grid

| Viewport | Columns | Gutter | Outer margin | Content rule |
|---|---:|---:|---:|---|
| Mobile `<600` | 4 | 16 | 16–20 | single column |
| Tablet `600–1023` | 8 | 24 | 32 | partial 2-column |
| Desktop `1024–1439` | 12 | 24 | 48 | purpose-driven split view |
| Wide `≥1440` | 12 | 32 | 64 | max content width 1440 |

- 앱 shell은 viewport를 사용하고 주요 콘텐츠만 `max-width: 1440px`로 제한한다.
- Desktop에서 콘텐츠 전체를 400px 너비로 가운데 띄우지 않는다.
- 입력 form의 읽기 폭이 좁아야 할 때도 주변 공간을 진행 정보, 설명, 요약, preview 패널로 활용한다.
- 표와 calendar는 가용 폭을 우선 사용하며 임의로 Mobile 폭에 고정하지 않는다.
- 2-column의 주 패널과 보조 패널 비율은 기본 `8:4`, 상세 중심 화면은 `7:5`, 대칭 비교는 `6:6`을 사용한다.

## 9. Responsive

### 9.1 Composition rules

Mobile은 single column과 하단 중심 interaction을 사용한다. Tablet은 정보 관계가 분명한 화면만 부분적으로 2-column으로 전환한다. Desktop은 탐색과 상세, 추천과 근거, 콘텐츠와 action을 동시에 제공한다.

| Screen type | Mobile | Tablet | Desktop / Wide |
|---|---|---|---|
| Entry | 서비스 설명 → Primary CTA 세로 흐름 | visual과 entry card 병렬 가능 | `[Product context 7][Entry panel 5]` |
| Profile | 한 단계씩 single column, 하단 CTA | `[Step context 3][Form 5]` | `[Progress/context 4][Form 5][Live summary 3]` |
| Profile Summary | 전체 폭 요약 뒤 CTA | 요약 group 2-column | `[Profile summary 8][Next action 4]` |
| Invite | 초대 상태와 action을 세로 배치 | 초대 설명/링크 카드 분리 | `[Relationship context 7][Invite action 5]` |
| Home | routine 우선, condition 요약 후속 | routine + condition 부분 2-column | `[Routine / Primary Content 8][Condition Summary 4]` |
| Condition | 질문과 입력을 단계별 배치 | 입력 group 2-column 허용 | `[Input workspace 7][Today summary/help 5]` |
| Activity | 오늘 할 일 single list | category별 2-column | `[Routine list 8][Progress/quick action 4]` |
| Meal | 추천 → 이유 → 대안 순 | 추천과 근거 병렬 | `[Recommendation 7][Reason / Alternative 5]` |
| Household | 요청/진행/결과를 세로 전환 | 콘텐츠와 상태 패널 병렬 | `[Recommendation/request 7][Status/history 5]` |
| Health | 추천과 안전 안내 순 | 상세와 근거 2-column | `[Health action 7][Reason/caution 5]` |
| Sleep | 환경 tile 목록 + CTA | tile grid + 설정 preview | `[Environment overview 8][Selected setting 4]` |
| Chat | message list + composer 고정 | 대화와 context panel | `[Conversation 8][Routine context 4]` |
| Report | 요약 → category → 상세 | chart와 요약 병렬 | `[Report content 8][Summary/share 4]` |
| Calendar | 날짜 선택 후 상세가 아래 | calendar와 detail 5:3 | `[Calendar 7][Selected Date Detail 5]` |
| Notification | grouped list | list + preview 선택적 | `[Notification list 7][Selected item 5]` |
| Partner Request | 상세 후 하단 action | 상세와 action 병렬 | `[Request Detail 7][Action Panel 5]` |
| Motion | 카메라/센서 영역 우선 | guide와 session 병렬 | `[Motion session 8][Guide/status 4]` |

### 9.2 Responsive behavior

- Mobile의 Primary CTA는 흐름상 마지막이거나 하단 고정 영역에 위치한다.
- Tablet landscape부터 보조 패널을 표시하되, 단순 장식 패널을 만들지 않는다.
- Desktop에서는 선택과 상세를 같은 화면에 유지해 불필요한 Route 이동을 줄인다.
- Desktop dialog는 최대 560px, 복합 form dialog는 최대 720px로 제한한다.
- Mobile의 dialog 성격 UI는 bottom sheet로 전환할 수 있다.
- viewport 높이가 낮으면 고정 CTA가 콘텐츠나 keyboard를 가리지 않아야 한다.

## 10. Shape

| Element | Radius |
|---|---:|
| Small tag, compact control | 8 |
| Input, button | 12 |
| Card, list group | 16 |
| Highlight panel | 20 |
| Bottom sheet top | 24 |
| Pill status | 999 |

- 동일 계층에서 radius 종류를 과도하게 섞지 않는다.
- nested surface는 바깥 radius보다 같거나 작아야 한다.
- 버튼을 모두 pill 형태로 만들지 않는다. pill은 filter, status, compact selection에 사용한다.

## 11. Elevation

경계는 먼저 surface와 border로 표현하고 shadow는 떠 있는 계층에만 사용한다.

| Level | Usage | Shadow |
|---|---|---|
| 0 | page, inline section | none |
| 1 | card, selected detail | `0 1px 3px rgba(32,38,36,.08)` |
| 2 | sticky action, dropdown | `0 8px 24px rgba(32,38,36,.10)` |
| 3 | dialog, modal, sheet | `0 18px 48px rgba(32,38,36,.16)` |

- 모든 카드를 shadow로 구분하지 않는다.
- sticky header와 bottom action은 scroll 경계가 생길 때만 elevation을 노출한다.
- inner shadow와 강한 glow는 사용하지 않는다.

## 12. Icon

- 한 종류의 outline icon family를 사용한다.
- 기본 20px, navigation 24px, 큰 상태 아이콘 32px을 사용한다.
- stroke 두께와 optical size를 화면 전체에서 통일한다.
- 아이콘 단독 버튼에는 접근성 label과 tooltip을 제공한다.
- 저장, 전송, 초대, 알림, 요청 상태는 의미가 모호한 장식 아이콘으로 대체하지 않는다.
- category icon은 category accent를 사용할 수 있지만 본문 아이콘은 `text-secondary`를 기본으로 한다.
- emoji를 제품 아이콘 대용으로 사용하지 않는다.

## 13. Components

### 13.1 App shell

- `AppHeader`: 화면 제목, optional back, context action을 제공한다.
- `WifeNavigation`: Mobile bottom navigation, Desktop navigation rail로 같은 목적지를 표현한다.
- `PartnerHeader`: 뒤로가기, 제목, 알림 action을 제공하며 bottom navigation을 만들지 않는다.
- `ContentFrame`: breakpoint별 grid와 outer margin을 책임진다.
- `StickyActionArea`: Mobile의 bottom-oriented CTA와 safe area를 책임진다.

### 13.2 Buttons

| Type | Usage |
|---|---|
| Primary | 화면의 대표 완료·다음·실행 행동 1개 |
| Secondary | 대안, 수정, 다시 보기 |
| Tertiary | 낮은 우선순위 inline action |
| Destructive | 취소·삭제 등 복구가 어려운 행동 |
| Icon button | 명확한 단일 action |

- 기본 높이는 48px, compact control은 40px까지 허용한다.
- Mobile의 핵심 CTA는 full-width를 기본으로 한다.
- loading 중 label 폭을 유지하고 중복 제출을 막는다.
- disabled 상태만으로 오류 이유를 숨기지 않는다.

### 13.3 Input

- label은 항상 입력 위에 표시한다.
- 단위가 있는 값은 field 안 또는 바로 옆에 고정 표시한다.
- helper와 error는 동일 위치에 배치해 layout jump를 줄인다.
- 날짜와 시간은 locale 형식으로 보여주되 Route parameter는 `YYYY-MM-DD`를 사용한다.
- 선택형 입력은 현재 값과 선택 가능성을 동시에 보여준다.
- Profile 2단계는 키와 임신 전 체중만 입력하며 나이 필드를 추가하지 않는다.

### 13.4 Cards and panels

- `SummaryCard`: 제목, 핵심 값, 보조 설명, optional action.
- `RoutineCard`: category, 추천 내용, 상태, 진입 action.
- `ConditionCard`: 현재 상태 요약과 수정 action.
- `RequestCard`: 요청자, 요청 내용, 시각, 상태, 상세 진입.
- `InsightPanel`: AI 추천 이유와 근거.
- `ActionPanel`: Desktop 상세 화면의 선택/완료 action.
- 카드 전체가 클릭 가능하면 내부에 중복되는 동일 목적 버튼을 두지 않는다.

### 13.5 Lists

- notification, request, activity는 list item의 정보 순서를 일관되게 유지한다.
- 목록 그룹은 날짜 또는 상태 heading으로 나눈다.
- unread, pending 등 상태는 dot만 쓰지 않고 label을 병행한다.
- 선택된 Desktop list item은 `primary-soft` 배경과 border로 표시한다.
- swipe gesture에만 핵심 행동을 숨기지 않는다.

### 13.6 State feedback

- `InlineStatus`: 입력과 action 가까이에 표시한다.
- `Toast`: 저장 완료처럼 추가 결정이 필요 없는 짧은 피드백.
- `CompletionOverlay`: 동일 Route 안에서 완료를 강조한 뒤 다음 상태로 복귀.
- `BottomSheet`: 선택, 설정, 짧은 form.
- `Dialog`: 파괴적 행동 확인, Desktop의 중요한 modal.
- 이 요소들은 별도 Route로 만들지 않는다.

## 14. Navigation

### 14.1 Bootstrap and guard

`/entry`에서 세션, Actor, Profile 완료 여부, Partner 연동 여부를 판정한다. UI는 판정 중 앱 shell을 먼저 노출하지 않고 branded skeleton 또는 최소 loading state를 사용한다.

- 인증되지 않음: `/entry`
- Wife + Profile 미완료: `/onboarding/profile`
- Wife + Profile 완료: `/wife/home`
- Partner + 유효 invitation token: `/partner/join?token=...`
- Partner + 연동 완료: `/partner/calendar`
- 권한이 다른 Route 접근: Actor의 canonical root로 이동하고 이유를 안내한다.

### 14.2 Wife navigation

Wife의 주요 목적지는 다음 네 개다.

1. Home — `/wife/home`
2. Realtime — `/wife/movement` (`PHASE_2`)
3. Chat — `/wife/chat`
4. Calendar — `/wife/calendar`

- Mobile: bottom navigation을 사용한다.
- Tablet: 화면 방향과 폭에 따라 bottom navigation 또는 compact rail을 사용한다.
- Desktop: 왼쪽 navigation rail을 사용하고 label을 항상 표시한다.
- Phase 2 목적지는 출시 정책에 따라 숨김 또는 명시적 준비 중 상태로 제공하며 dead-end Route로 연결하지 않는다.
- Profile/Menu는 전역 header action에서 `/wife/menu`로 진입한다.

### 14.3 Partner navigation

- Partner의 root는 `/partner/calendar`다.
- Partner Bottom Navigation은 사용하지 않는다.
- Partner Profile 화면과 Profile tab을 만들지 않는다.
- 알림은 header action을 통해 `/partner/notifications`로 진입한다.
- 날짜를 선택하면 `/partner/report/:date`로 이동하거나 Desktop의 selected-date detail에서 동일 정보를 preview한다.
- 요청 알림은 실제 `requestId`를 사용해 `/partner/requests/:requestId`로 연결한다.
- Motion은 Calendar의 명시적 CTA에서 진입하며 MVP에서는 비활성 또는 준비 중 상태로 표현한다.

### 14.4 Route interaction rules

- Report에서 Calendar로 돌아갈 때 선택 날짜와 scroll context를 보존한다.
- Condition create/edit는 동일 Route와 명시적 mode state를 사용한다.
- AI Callback은 현재 Route 안의 상태이며 자동으로 다른 Route로 이동하지 않는다.
- notification을 읽은 뒤 원래 목록 위치를 유지한다.
- deep link가 유효하지 않으면 Actor root로 fallback하고 복구 가능한 안내를 보여준다.
- `today`, `demo-request` 같은 placeholder parameter를 제품 Route에 사용하지 않는다.

## 15. Screen Patterns

### 15.1 Onboarding pattern

진행률, 현재 질문, 입력, 다음 행동 순으로 구성한다. Mobile에서는 이전 버튼을 header에, 다음 버튼을 하단에 둔다. Desktop에서는 진행 맥락과 live summary를 활용해 빈 공간을 줄인다.

### 15.2 Dashboard pattern

Home의 첫 viewport에는 오늘의 핵심 routine과 condition 상태가 보여야 한다. 정보성 카드보다 실행 가능한 콘텐츠가 먼저다. Desktop은 routine과 condition summary를 병렬 배치한다.

### 15.3 Recommendation pattern

추천 제목 → 실제 행동 → 이유 → 대안/수정 순서를 유지한다. Meal, Health, Household, Sleep에서 같은 계층을 재사용하되 category accent만 다르게 사용한다.

### 15.4 Record pattern

기록할 항목, 현재 값, 저장 CTA를 가까이 둔다. 저장 후 toast 또는 completion state를 사용하고 별도 완료 Route로 이동하지 않는다.

### 15.5 Calendar-detail pattern

Mobile은 날짜 선택 후 상세를 아래에 표시하거나 report로 이동한다. Desktop은 calendar와 selected-date detail을 동시에 보여준다. 날짜가 바뀔 때 전체 page reload를 사용하지 않는다.

### 15.6 Master-detail pattern

Partner Notification과 Request는 Tablet/Desktop에서 list와 selected detail을 병렬로 표현할 수 있다. Mobile에서는 목록과 상세를 Route로 구분한다.

### 15.7 Settings pattern

설정은 대상별 tile에서 진입한다. Sleep 환경 설정처럼 항목별 bottom sheet를 사용하며, 모든 설정을 여는 포괄적인 버튼을 추가하지 않는다.

## 16. Screen ID Based Rules

아래 ID는 실제 `docs/screens` 파일명과 Route 계약을 기준으로 한다.

| Screen ID | UI rule | Route/state rule |
|---|---|---|
| `B-ENTRY-001` | 제품 맥락과 명확한 시작 CTA | `/entry` Route |
| `B-ENTRY-001-1` | bootstrap 또는 진입 변형 상태 | 별도 Route 아님 |
| `W-PROFILE-001` | 출산 예정일 입력, 단계 진행 표시 | `/onboarding/profile` 내부 step |
| `W-PROFILE-002` | 생년월일·키·임신 전 체중 입력 | 생년월일로 나이 자동 계산, 내부 step |
| `W-PROFILE-003` | 알레르기 선택/입력 | 내부 step |
| `W-PROFILE-004` | 질환 선택/입력 | 내부 step |
| `W-PROFILE-005` | 음식 선호 선택 | 내부 step |
| `W-PROFILE-006` | 생활 패턴 입력 | 내부 step |
| `W-PROFILE-007` | 6단계 결과 요약과 수정 진입 | summary state, 별도 Route 아님 |
| `W-INVITE-001` | partner 초대 링크 생성·공유·상태 | `/onboarding/invite` Route |
| `W-MENU-001` | Profile, 연동, 설정 진입 | `/wife/menu` Route |
| `W-MENU-001-1` | partner 연동 여부에 따른 변형 | 별도 Route 아님 |
| `W-HOME-001` | 오늘 condition 요청과 routine 중심 | `/wife/home` Route |
| `W-HOME-001-1` | condition 입력 전/후 상태 | 별도 Route 아님 |
| `W-COND-001` | condition 생성·수정 form | `/wife/condition`, mode state |
| `W-TASK-001` | 오늘 activity 목록과 진행 상태 | `/wife/activity` Route |
| `W-CALLBACK-001` | AI 생성 중·성공·실패·fallback | 현재 Route의 overlay/state |
| `W-MEAL-001` | 식사 추천과 근거 | `/wife/meal` Route |
| `W-MEAL-002` | 식사 대안/상세 상태 | 별도 Route 아님 |
| `W-MEAL-003` | 식사 기록/완료 상태 | 별도 Route 아님 |
| `W-HOUSE-001` | household 추천 또는 요청 작성 | `/wife/household` Route |
| `W-HOUSE-001-1` | 요청 전송/진행 상태 | 별도 Route 아님 |
| `W-HOUSE-001-2` | 결과/완료 상태 | 별도 Route 아님 |
| `W-HEALTH-001` | 건강 활동 추천과 안전 안내 | `/wife/health` Route |
| `W-SLEEP-001` | 수면 환경 tile과 상태 | `/wife/sleep` Route |
| `W-SLEEP-001-1` | 개별 환경 설정 sheet | 별도 Route 아님 |
| `W-SLEEP-001-2` | 개별 환경 설정 sheet | 별도 Route 아님 |
| `W-SLEEP-001-3` | 개별 환경 설정 sheet | 별도 Route 아님 |
| `W-SLEEP-001-4` | 개별 환경 설정 sheet | 별도 Route 아님 |
| `W-SLEEP-001-5` | 개별 환경 설정 sheet | 별도 Route 아님 |
| `W-CHAT-001` | routine 맥락을 포함한 대화 | `/wife/chat` Route |
| `W-REPORT-001` | 날짜별 아내 리포트 | `/wife/report/:date` Route |
| `W-REPORT-001-1` | 공유 modal/state | 별도 Route 아님 |
| `B-CAL-001` | Actor별 calendar shell | `/wife/calendar` 또는 `/partner/calendar` |
| `H-REPORT-001` | partner용 날짜별 요약 | `/partner/report/:date` Route |
| `H-NOTI-001` | 알림 grouping과 unread 상태 | `/partner/notifications` Route |
| `H-REQUEST-001` | 요청 상세와 수락/거절 action | `/partner/requests/:requestId` Route |
| `H-REQUEST-001-1` | 요청 처리 중 상태 | 별도 Route 아님 |
| `H-REQUEST-001-2` | 요청 처리 완료 상태 | 별도 Route 아님 |
| `H-REQUEST-002` | 요청 관련 후속 상태 | Route Map 계약에 따라 동일 request 상세 상태 |
| `B-MOTION-001` | Actor 공통 motion session | Wife/Partner Route, `PHASE_2` |

## 17. Wife UI

Wife UI는 현재 상태 파악과 작은 행동의 실행을 우선한다.

- Home의 첫 영역은 오늘의 핵심 routine 또는 condition 입력 요청이다.
- condition은 평가나 경고처럼 보이지 않게 중립적인 질문 형태로 제시한다.
- 추천 카드에는 이유와 수정 또는 대안 action을 제공한다.
- Profile은 6단계와 Summary를 하나의 onboarding 흐름으로 유지한다.
- Profile Summary에서 특정 항목을 수정한 뒤 Summary로 돌아온다.
- Menu는 Profile, partner 연동, 허용된 설정의 진입점이다.
- Chat은 별도 bottom navigation 목적지이며 단순 floating button으로만 숨기지 않는다.
- Motion은 Realtime 목적지이지만 Phase 2 정책을 UI에 반영한다.
- Calendar는 기록과 Report 진입의 기준 화면이다.

톤은 지시형보다 지원형을 사용한다. 예: “반드시 쉬세요”보다 “지금은 10분 정도 쉬어보는 것을 권해요”처럼 근거와 선택권을 함께 제공한다.

## 18. Partner UI

Partner UI는 관찰이 아니라 협력 행동을 중심으로 한다.

- Calendar가 root이며 날짜별 정보 접근의 중심이다.
- Header notification은 unread 상태를 badge와 접근성 label로 함께 표시한다.
- Notification은 정보 알림과 행동이 필요한 request를 구분한다.
- Request 상세에서는 요청 내용과 action panel을 명확히 분리한다.
- 수락/거절 결과는 즉시 상태에 반영하며 중복 처리를 막는다.
- Partner에게 Wife의 민감 정보 전체를 기본 노출하지 않는다. 요구사항에 정의된 공유 범위만 표현한다.
- Partner Bottom Navigation과 Partner Profile UI를 만들지 않는다.
- Motion은 Calendar의 명시적 CTA에서만 접근하며 MVP에서는 실행 가능한 것처럼 오인시키지 않는다.

Partner 화면은 Wife 화면보다 차갑게 만들 필요는 없다. 동일한 neutral surface를 공유하되 action과 상태 정보의 밀도를 조금 높인다.

## 19. AI UI

### 19.1 Required anatomy

AI 생성 콘텐츠는 가능한 경우 다음 요소를 포함한다.

1. `AI 추천` 또는 이에 준하는 출처 label
2. 추천 결과
3. 추천 이유
4. 수정 또는 대안 action
5. 생성 시각 또는 최신 상태가 중요한 경우의 freshness 정보

### 19.2 Trust rules

- 의료 진단이나 확정적 판단처럼 표현하지 않는다.
- 건강 관련 위험이 있으면 일반적인 안전 안내와 전문가 상담 문구를 분리한다.
- 사용자가 입력한 상태와 AI가 추론한 내용을 시각적으로 구분한다.
- 생성 실패 시 콘텐츠 영역을 비우지 않고 이전 routine 또는 기본 template을 제공한다.
- skeleton을 실제 데이터로 오인할 수 있는 애니메이션으로 만들지 않는다.
- AI 카드 전체에 특수한 gradient나 glow를 사용하지 않는다.

## 20. Loading, Empty, Error

### 20.1 Loading

- 최초 bootstrap: 앱 shell 이전의 간결한 loading state.
- 화면 데이터: 최종 layout과 크기가 유사한 skeleton.
- 버튼 제출: 버튼 내부 progress + 중복 입력 차단.
- AI 생성: `W-CALLBACK-001`의 단계 문구와 기존 fallback 콘텐츠 유지.
- 1초 이내 작업에는 과도한 progress animation을 노출하지 않는다.

### 20.2 Empty

Empty state는 이유, 사용자가 할 수 있는 행동, 자동 갱신 여부를 설명한다.

- Calendar 기록 없음: 날짜 맥락 유지 + 기록/다른 날짜 선택 안내.
- Notification 없음: 정상 상태임을 알리고 새로고침을 강요하지 않는다.
- Request 없음: 완료된 상태와 미수신 상태를 구분한다.
- Report 미생성: 생성 조건과 가능한 다음 행동을 안내한다.

### 20.3 Error

- 입력 오류는 해당 field 가까이에 표시한다.
- 네트워크 오류는 보존된 입력과 재시도 action을 제공한다.
- 권한 오류는 canonical root로 복구 가능한 안내를 제공한다.
- 유효하지 않은 invitation token은 실패 이유와 재초대 경로를 제공한다.
- 전체 화면 오류는 header와 navigation까지 불필요하게 제거하지 않는다.

## 21. Callback

AI Callback은 Route가 아니라 현재 화면의 생성 상태다.

상태 순서는 다음과 같다.

```text
idle → requesting → generating → success
                         └→ timeout/error → fallback + retry
```

- `requesting/generating`: 현재 작업과 예상 결과를 짧게 설명한다.
- `success`: 같은 Route에서 최신 콘텐츠로 교체하고 완료 피드백을 제공한다.
- `timeout/error`: 이전 routine이 있으면 유지하고, 없으면 기본 template을 표시한다.
- 자동 Route 이동, 전체 화면 강제 전환, 무한 spinner를 사용하지 않는다.
- 사용자가 다른 화면으로 이동해도 callback 완료를 toast 또는 해당 화면의 상태로 안전하게 반영한다.
- 재시도는 멱등성을 고려해 중복 routine 생성을 방지한다.

## 22. Accessibility

- WCAG 2.2 AA를 기준으로 한다.
- 일반 텍스트 명암비는 최소 4.5:1, 큰 텍스트는 최소 3:1이다.
- 모든 interactive target은 최소 44×44px, 권장 48×48px이다.
- keyboard만으로 모든 Route, sheet, dialog, form을 사용할 수 있어야 한다.
- focus 순서는 시각적 읽기 순서와 일치해야 한다.
- focus ring은 배경과 충분한 대비를 갖고 제거하지 않는다.
- dialog와 sheet가 닫히면 focus를 호출 요소로 돌려보낸다.
- screen reader label에는 아이콘 이름이 아니라 행동과 상태를 포함한다.
- live update, callback, 저장 완료는 적절한 semantic announcement를 제공한다.
- chart는 요약 문장과 데이터 table 또는 목록 대안을 제공한다.
- 색각에 관계없이 상태를 구분할 수 있도록 icon, label, pattern을 병행한다.
- text scaling 200%에서도 핵심 action과 내용이 잘리거나 겹치지 않아야 한다.

## 23. Motion

UI animation은 상태 변화의 원인을 설명하는 데만 사용한다.

| Motion | Duration | Easing |
|---|---:|---|
| Press/hover feedback | 100–150ms | ease-out |
| Small state change | 180–220ms | ease-in-out |
| Panel/sheet transition | 240–320ms | emphasized decelerate |
| Completion feedback | ≤400ms | ease-out |

- `prefers-reduced-motion` 또는 플랫폼 reduce motion 설정을 존중한다.
- 무한 pulse, parallax, decorative bounce를 사용하지 않는다.
- loading animation은 작업이 계속되고 있음을 알리는 수준으로 제한한다.
- Route transition은 Actor와 계층을 혼동시키는 방향 전환을 피한다.
- `B-MOTION-001`의 Motion 기능과 UI motion 용어를 구현 코드에서 명확히 분리한다.

## 24. Flutter Implementation Rules

### 24.1 Token ownership

- 색상은 `ColorScheme` 확장 또는 제품 semantic token에 정의한다.
- spacing, radius, elevation, breakpoint를 상수로 중앙 관리한다.
- 화면 widget에 raw hex, 임의 spacing, 임의 radius를 반복 작성하지 않는다.
- category color와 semantic status color를 분리한다.

### 24.2 Responsive implementation

- 단순 `MediaQuery` 분기보다 공통 responsive shell과 layout builder를 사용한다.
- breakpoint는 이 문서의 Mobile/Tablet/Desktop/Wide 계약과 일치시킨다.
- Desktop에서 Mobile widget에 고정 폭만 적용해 재사용하지 않는다.
- 동일 feature의 데이터와 state는 공유하되 layout composition은 viewport에 맞게 분리할 수 있다.
- keyboard, safe area, browser resize, split-screen을 테스트한다.

### 24.3 Component boundaries

- Screen은 route state와 composition을 담당한다.
- 공통 컴포넌트는 appearance와 interaction contract를 담당한다.
- Feature 컴포넌트는 domain content를 담당한다.
- modal, bottom sheet, toast, completion overlay를 router에 등록하지 않는다.
- Screen ID 접미 상태는 enum 또는 sealed state로 명확히 표현한다.

### 24.4 Navigation and state

- canonical path만 생성한다.
- date와 request ID는 실제 값으로 전달하고 진입 시 검증한다.
- Actor guard, Profile completion, Partner link 상태는 UI widget 안의 임시 boolean이 아니라 앱 상태 계층에서 판정한다.
- browser back/forward와 deep link가 동일한 결과를 만들어야 한다.
- condition create/edit, callback, request 처리 상태는 새 Route가 아닌 명시적 screen state로 관리한다.

### 24.5 Quality

- `const` 생성자를 가능한 범위에서 사용한다.
- loading, empty, error, success를 happy path와 함께 구현한다.
- 큰 screen build method를 의미 있는 section widget으로 나눈다.
- 주요 공통 컴포넌트와 복잡한 상태 전환에는 목적 중심 주석을 작성한다.
- decorative asset보다 Flutter-native layout과 vector icon을 우선한다.

## 25. Anti-patterns

다음 구현은 허용하지 않는다.

- LG 공식 색상, gradient, token의 사용 또는 근사 복제
- 임신을 이유로 화면 전체를 pink/pastel로 구성
- Desktop에서 400px Mobile UI를 중앙에 그대로 표시
- PNG를 픽셀 단위로 복제
- 모든 콘텐츠를 동일한 카드로 감싸 hierarchy를 없애기
- 색상만으로 선택, 오류, 완료, unread 상태 표시
- Partner Bottom Navigation 또는 Partner Profile 추가
- modal, bottom sheet, toast, 완료 overlay를 별도 Route로 생성
- Screen ID 접미 상태를 자동으로 별도 Route로 해석
- AI 결과에 근거, fallback, retry 없이 spinner만 표시
- callback 성공 후 사용자의 맥락과 무관하게 자동 이동
- `today`, `demo-request` 같은 임시 parameter를 production flow에 사용
- Profile 2단계에서 생년월일 대신 계산된 나이를 직접 입력하게 하는 UI 추가
- Sleep 화면에 모든 설정을 여는 포괄적 변경 버튼 추가
- Phase 2 Motion 기능을 완성 기능처럼 노출
- hover에만 의존하는 핵심 interaction
- 직접 입력한 raw color, spacing, radius의 화면별 난립

## 26. QA Checklist

### Source and scope

- [ ] Screen이 최신 Requirement ID와 연결되어 있는가?
- [ ] Screen ID가 실제 `docs/screens` 파일명과 일치하는가?
- [ ] Route와 state 구분이 `ROUTE_MAP.md`와 일치하는가?
- [ ] Wife와 Partner의 권한 및 정보 범위가 분리되어 있는가?
- [ ] MVP와 Phase 2 범위가 UI에서 오해 없이 표현되는가?

### Visual system

- [ ] 제품 palette token만 사용했는가?
- [ ] 금지된 공식 브랜드 색상·gradient·token을 사용하지 않았는가?
- [ ] 화면 전체가 pink/pastel 톤으로 기울지 않았는가?
- [ ] typography, spacing, radius, icon 규칙이 일관적인가?
- [ ] 카드와 shadow를 필요한 계층에만 사용했는가?

### Responsive

- [ ] Mobile은 single column이며 핵심 action이 하단 흐름에 있는가?
- [ ] Tablet은 의미 있는 영역에서 부분 2-column을 사용하는가?
- [ ] Desktop은 가용 공간을 master-detail 또는 보조 패널로 활용하는가?
- [ ] Desktop에서 Mobile 고정 폭 UI를 그대로 띄우지 않았는가?
- [ ] 600px, 1024px, 1440px 경계 전후에서 layout이 안정적인가?
- [ ] keyboard, safe area, browser resize에서 CTA가 가려지지 않는가?

### Interaction and navigation

- [ ] 한 화면의 Primary CTA가 명확한가?
- [ ] Secondary CTA가 Primary CTA와 경쟁하지 않는가?
- [ ] back, browser history, deep link가 예상대로 작동하는가?
- [ ] Wife navigation과 Partner navigation 규칙을 지켰는가?
- [ ] Report와 Calendar 사이에서 선택 날짜가 보존되는가?
- [ ] notification에서 실제 request ID로 Request 상세에 진입하는가?
- [ ] modal/sheet/overlay가 Route로 생성되지 않았는가?

### State and AI

- [ ] loading, empty, error, success 상태가 모두 정의되어 있는가?
- [ ] 입력 실패 시 사용자가 작성한 값이 보존되는가?
- [ ] AI 추천에 이유와 수정/대안 경로가 있는가?
- [ ] callback 실패 시 이전 routine 또는 기본 template이 남는가?
- [ ] 중복 제출과 중복 요청 처리를 방지하는가?

### Accessibility

- [ ] 텍스트와 UI 요소가 AA 명암비를 만족하는가?
- [ ] touch target이 최소 44×44px인가?
- [ ] keyboard focus 순서와 focus 복귀가 올바른가?
- [ ] icon button, badge, live state에 semantic label이 있는가?
- [ ] 200% text scaling과 reduced motion에서 사용할 수 있는가?
- [ ] chart와 색상 상태에 비시각적 대안이 있는가?
