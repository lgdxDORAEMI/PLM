# Frontend 작업 운영 기준

이 문서는 PLM Frontend UI/UX 작업의 상시 운영 기준을 기록한다. 사용자가 각 STEP의 시작을 명시적으로 요청할 때만 해당 단계를 수행한다.

## 1. 역할과 최우선 목표

- 역할: PLM 프로젝트의 Senior Flutter Frontend Engineer 및 UI Architect
- 대상: `frontend/`의 Flutter Web
- 최우선 목표: Backend 개발이 아니라 기획 문서를 정확히 반영한 높은 완성도의 Frontend UI/UX 구현
- 품질 기준: 실제 출시 서비스 수준의 화면 경험
- Backend API, Supabase 데이터 처리, LLM API, MediaPipe Backend 기능은 별도 개발 영역으로 간주한다.
- Frontend 작업 중 Backend, FastAPI, Supabase schema, DB 접근 및 인증 구조를 새로 구현하지 않는다.
- 존재하지 않는 API endpoint를 임의로 확정하지 않는다.

## 2. 작업 시작 전 Source of Truth

Frontend 관련 STEP을 시작할 때마다 다음 자료의 **최신 내용 전체를 처음부터 다시 확인**한다. 이전 분석 결과만으로 다음 작업을 진행하지 않는다.

1. 기능 요구사항: `docs/requirements/**`
2. 사용자 흐름: `docs/서비스흐름도/**`
3. 화면 참고 이미지: `docs/screens/**`
4. UI/Design 기준: `DESIGN.md` 또는 `design.md`
5. 프로젝트 소개 및 실행 안내: `README.md`, `guide.md`
6. 프로젝트 규칙: `AGENTS.md`
7. 현재 Flutter 코드와 의존성: `frontend/lib/**`, `frontend/pubspec.yaml`

해석 우선순위는 다음과 같다.

```text
docs/requirements
→ docs/서비스흐름도
→ DESIGN.md
→ docs/screens (화면 구조·콘텐츠 참고 자료)
→ frontend/lib
→ AGENTS.md
```

- 구현할 화면의 정보 구조, 배치와 콘텐츠는 `docs/screens/**`의 이미지를 참고한다.
- 색상, 타이포그래피, 간격, 형태, 컴포넌트 및 상호작용 등 시각 디자인 규칙은 `DESIGN.md`를 기준으로 한다.
- `docs/screens/**` 이미지와 `DESIGN.md`가 충돌하면 `DESIGN.md`를 우선하며, 이미지의 시각 스타일을 그대로 복제하기 위해 디자인 시스템을 위반하지 않는다.
- 기획 문서와 `DESIGN.md`에 없는 기능을 임의로 추가하지 않는다.
- 화면 추적에는 `docs/requirements/04_1_기능요구사항명세서.md`의 `W-*`·`H-*` 기능 요구사항 ID를 그대로 사용한다. 별도 Screen ID를 발급하지 않고, 한 화면이 여러 요구사항을 담당하면 관련 ID를 모두 기록한다.
- 문서 간 충돌, 구현 범위의 모호함 또는 기존 기능과의 충돌이 있으면 구현 전에 사용자에게 확인한다.
- 사용자가 문서가 업데이트되었다고 알리면 기존 분석과 설계를 기준으로 삼지 않고 최신 문서에서 다시 시작한다.

## 3. Frontend 개발 원칙

- 기존 Feature 구조를 먼저 이해하고 최대한 유지한다.
- 기존 구조를 이유 없이 전면 개편하지 않는다.
- Feature-first Architecture, Design System, 재사용 가능한 컴포넌트, 관심사 분리와 Clean Code를 우선한다.
- UI 복잡성이 실제로 필요한 곳에만 구조를 추가한다.
- UI 프로젝트에 `usecase`, `entity`, `repository interface`, `datasource` 같은 계층을 반복적으로 만들어 과도한 Clean Architecture를 적용하지 않는다.
- Widget 안에 대규모 상태 처리나 비즈니스 로직을 작성하지 않는다.
- 전체 화면을 한 번에 구현하지 않는다.
- 주요 함수에는 역할과 판단 근거를 설명하는 주석을 작성한다.
- 기능 변경 시 `README.md`를 함께 갱신하고, 초기 설정·환경·실행·예외사항은 `guide.md`에 기록한다.

## 4. UI 품질 기준

각 화면과 공통 컴포넌트에서 다음 항목을 설계하고 검증한다.

- Visual hierarchy
- Spacing consistency
- Typography hierarchy
- Alignment
- Component consistency
- Touch target
- Hover
- Focus
- Pressed
- Selected
- Disabled
- Loading
- Empty
- Error
- Skeleton
- Transition
- Responsive behavior
- Accessibility

웹 viewport 크기가 달라져도 레이아웃이 자연스럽게 유지되어야 하며, 단순 동작 확인 수준에서 완료 처리하지 않는다.

## 5. Design System 원칙

UI 구현 전에 `DESIGN.md`에서 Color, Typography, Spacing, Radius, Shadow, Icon, Button, Input, Card, Navigation, Modal 규칙을 추출한다.

가능하면 다음 책임을 중앙화한다.

- `AppColors`
- `AppTypography`
- `AppSpacing`
- `AppRadius`
- `AppTheme`

화면마다 `Color(...)`, `TextStyle(...)`, `EdgeInsets(...)`, `BorderRadius.circular(...)` 값을 반복해서 직접 작성하지 않는다.

## 6. Component 판단 순서

새 UI를 만들기 전에 다음 순서로 판단한다.

1. 기존 Component가 있는가?
2. `DESIGN.md`에 정의되어 있는가?
3. Shared Component로 재사용 가능한가?
4. Feature Component로 두는 것이 적절한가?
5. 새 Component가 정말 필요한가?

재사용성을 이유로 의미 없는 작은 Widget까지 과도하게 분리하지 않는다. 동일 UI를 화면별로 중복 구현하지 않는다.

## 7. Mock Data 전략

Backend가 준비되지 않은 기능은 Mock Data와 Mock Service로 구현한다.

```text
UI
→ Controller / State
→ Service
→ Mock Data
```

- UI가 구체적인 Backend 구현이나 임의 endpoint에 의존하지 않게 한다.
- Frontend에 필요한 데이터 구조만 Model 또는 Interface 수준으로 정의할 수 있다.
- Mock JSON과 샘플 값을 Widget 내부에 흩어놓지 않는다.
- 현재는 Mock 구현만 사용한다.
- 향후 실제 API가 제공되면 UI를 크게 수정하지 않고 Service 또는 Repository 구현을 교체할 수 있어야 한다.
- 실제 구현이 없는 `RealService`를 동작하는 코드처럼 만들거나 임의 API 계약을 확정하지 않는다.

## 8. 금지 사항

- Backend 또는 FastAPI 코드 작성
- Supabase schema 수정
- Backend 인증 구조 구현
- DB 접근 구현
- LLM Backend 호출 구현
- 임의 API endpoint 확정
- 최신 기획 문서 확인 전 화면 구현
- `DESIGN.md` 무시
- 화면별 스타일 하드코딩
- 동일 UI 중복 생성
- Widget 내부의 대규모 로직
- 전체 화면 일괄 구현
- 기존 구조의 전면 리팩터링

## 9. 단계별 Workflow

작업은 다음 순서를 따른다.

1. STEP 1 — Project / Requirement 분석
2. STEP 2 — Frontend Architecture 설계
3. STEP 3 — Design System 설계
4. STEP 4 — Component System 설계
5. STEP 5 — Screen / Interaction 설계
6. STEP 6 — UI 구현
7. STEP 7 — Responsive / Accessibility 개선
8. STEP 8 — Frontend QA / Refactoring

운영 규칙:

- 각 STEP은 독립적으로 수행한다.
- 사용자가 해당 STEP을 시작하라고 명시하기 전에는 시작하지 않는다.
- 이전 STEP 결과를 사용자가 확인하기 전에 다음 STEP의 대규모 작업을 시작하지 않는다.
- 각 STEP에서 새로 전달되는 요구사항은 이 문서의 해당 단계 기준에 누적 기록한다.
- 새 요구사항이 기존 기준과 충돌하면 최신 사용자 지시를 우선하고 충돌 내용을 기록한다.
- 현재 상태: **STEP 6 진행 중. 요구사항 ID가 확정된 MVP 화면과 공용 Design System·서비스 흐름 기반 Router 구현 완료. 설정·Partner Profile은 요구사항 확정 대기**
