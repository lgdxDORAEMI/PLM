# PLM — ThinQ Pregnancy Life Mode

PLM은 임신 주수, 당일 컨디션, 예정 활동과 생활 기록을 바탕으로 임산부의 식사·가사·건강·수면 루틴을 개인화하고 가족의 돌봄 참여를 돕는 생활관리 서비스입니다.

현재 저장소는 Profile Setup, 배우자 초대·수락 안내, Home·Today Care·예정 활동·Daily Routine, Smart Meal Guide, 식사 재조정 AI Chat, 가사·건강·Sleep Care, 날짜별 Record/Calendar, Movement Mock, 파트너 리포트·알림·가사 요청 Flow가 UI로 구현된 Flutter Web Frontend와, 프로필 일부 및 모션 인식 데모를 제공하는 FastAPI Backend로 구성됩니다. 외부 연동 전인 Routine·Chat·초대·Partner Flow와 생활 데이터는 Mock/local 상태를 사용합니다.

## 핵심 사용자 흐름

```text
임산부
Entry 시작 → 프로필 등록 → Home → 오늘의 컨디션·예정 활동 입력
→ 개인화 루틴 확인 → 식사·가사·건강·수면 가이드 실행
→ 완료 기록과 Daily 리포트 확인

배우자
초대 수락 → 오전 컨디션 리포트 확인
→ 가사 요청 확인·완료 → 캘린더에서 기록 확인
```

MVP는 실제 가전 자동 실행과 홈카메라 기반 실시간 위험 행동 로그를 제외하고, 컨디션 입력부터 루틴 실행·가족 분담·기록까지의 핵심 루프를 검증하는 데 초점을 둡니다. 가사·수면 가이드의 가전 실행은 기기 제어 없는 시연 기능입니다. 정확한 범위는 [MVP 정의](docs/requirements/01_MVP.md)를 따릅니다.

## 현재 상태

| 영역 | 구현 상태 | 비고 |
| --- | --- | --- |
| Frontend 기반 | 구현 | Flutter Web 초기화, 환경설정, DESIGN.md 기반 Theme·반응형 Layout·공통 상태/Badge/Task Component |
| Frontend 제품 UI | 부분 구현 | 실제 responsive Entry, Profile 6단계와 LMP+280일·주수 계산, 초대 Mock, Home·Today Care·예정 활동, Daily Routine, Meal·Chat, 가사·건강·Sleep, Record/Calendar·Movement Mock, Partner Report·Inbox·Request 구현. 신규 사용자는 Entry→Profile→Home, 완료 사용자는 Home으로 바로 진입. 설정·Partner Profile은 요구사항 확정 대기 |
| 모션 인식 Web 데모 | 구현 | 브라우저 카메라 프레임 전송, 캘리브레이션, 자세 오버레이와 상태 표시 |
| Backend 기본 API | 구현 | `/`, `/health`, 개발용 CORS와 Account·Care·Family Contract First Skeleton |
| 임산부 프로필 | 부분 구현 | Backend의 단계별 1~6단계 API와 `pregnancy_profiles` DB 저장은 구현됐으나 `birth_date` 계약·컬럼은 아직 없음. Frontend도 아직 `ProfileStore`와 브라우저 localStorage를 사용하므로 서버 계정과 동기화되지 않음 |
| 모션 분석 API | 데모 구현 | 단일 세션 WebSocket 분석, 이벤트 및 일일 집계 조회 |
| Supabase | 부분 구현 | Auth 토큰 검증 경계와 `pregnancy_profiles` migration 2건(생성, 출산예정일 제약 완화) |
| AI 루틴·LLM | 미구현 | 인터페이스만 존재하며 공급자 및 실제 호출 없음 |
| 배우자 UI | 부분 구현 | 초대 수락 상태 안내(Mock, 실제 수락·계정 연동 없음), 공통 Calendar, 오전 리포트, 알림함, 가사 요청 확인·완료 구현. Partner Profile은 상세 요구사항 확정 대기 |
| ThinQ 가전 연동 | 미구현 | MVP에서는 추천까지만 제공하고 실제 제어는 제외 |
| Android / iOS | 미지원 | 저장소에는 Web 플랫폼만 준비되어 있음 |

Frontend 제품 UI 작업은 Backend 구현과 분리합니다. Backend가 준비되지 않은 화면은 Mock Data와 Mock Service를 사용하고, 향후 Service 구현 교체만으로 실제 API에 연결할 수 있도록 설계합니다.

식사·가사·건강·수면 가이드에서 하단 또는 측면 내비게이션의 `홈`을 누르면 홈 첫 화면으로 이동하며, 가이드 화면의 이동 기록은 제거됩니다.

웹 UI의 카드·선택 항목은 공통 클리핑 경계 안에서 호버 피드백을 표시하며, 휠·트랙패드·터치 스크롤은 유지하되 화면 스크롤바는 노출하지 않습니다. Tablet·Desktop 상단바의 우측 알림·프로필 액션은 콘텐츠 grid 여백에 맞춰 화면 가장자리와 충분한 간격을 둡니다.

Home의 AI Routine 영역은 `RoutineService` 경계를 통해 데이터를 받고, 현재는 `MockRoutineService`를 사용합니다. 따라서 실제 AI API 없이도 컨디션 입력 → 예정 활동 선택 → 생성 상태 → 4종 가이드 또는 기본 폴백의 UI Flow를 확인할 수 있으며, API 연결 시 화면을 수정하지 않고 Service 구현을 교체할 수 있습니다. 오늘 예정 활동 화면에는 선택 개수나 MVP·Mock 구현 상태를 안내하는 개발용 배너를 노출하지 않습니다.

4종 상세 가이드는 하나의 Dashboard Template을 복제하지 않습니다. Meal은 끼니별 추천·근거·수락/다른 메뉴 순환을 제공하며, 다른 메뉴를 선택해도 상단의 추천 근거는 유지하고 메뉴 카드만 교체합니다. Household는 직접 할 일을 간단한 목록으로 표시하고, 가족과 나누기만 체크박스 카드로 선택합니다. 공유한 일은 직접 할 일 목록에서 제외되며 Partner Request 상태로 이어집니다. Health는 부담 부위 우선순위와 활동 완료, Sleep은 취침 맥락·환경 항목별 설정·수면 팁에 각각 최적화되어 있습니다. 수면 환경 전체 실행 버튼은 ‘AI가 맞춘 오늘의 수면 환경’ 제목 옆에 강조색 원형 재생 버튼으로 표시합니다. 컨디션의 기분 항목은 입덧·피로·통증과 동일한 단계별 선택 색상 규칙을 사용합니다. 가사 가전 항목의 `실행`과 수면 환경 전체 실행은 요청할 때마다 오늘 날짜의 가전 실행 이력 1회로 기록하고 확인 팝업을 표시합니다. Daily 리포트와 캘린더는 두 가이드의 이력을 합산해 건수와 항목을 표시합니다. 현재 가전 동작은 로컬 기록이며 실제 기기 제어와 연결되지 않습니다. 사용자 화면에는 개발 단계 안내 문구를 표시하지 않습니다.

Chat은 임신 주차·주의 진단·당일 컨디션을 유지하는 식사 재조정 대화에 집중합니다. 하단 챗봇 탭으로 직접 진입하면 루트 화면이므로 뒤로가기를 표시하지 않고, `source=meal|household|health|sleep`의 검증된 가이드 문맥으로 진입한 경우에만 원래 가이드로 돌아가는 버튼을 표시합니다. 제품 Route는 플랫폼 기본 전환 대신 짧은 fade+수평 slide 애니메이션을 사용하며, 운영체제의 애니메이션 줄이기 설정을 따릅니다. Report는 핵심 결과 → 실행 루틴 → 하루 인사이트와 가족 참여 순으로 결과 위계를 제공합니다. Calendar는 날짜 선택 → 선택일 기록 → 아내 `/wife/report/:date` 또는 남편 `/husband/report/daily/:date` 상세 흐름으로 연결되며, 선택일의 컨디션·루틴·가전·가족 분담·주의사항을 하나의 좌측 정렬 요약 카드로 표시합니다. 남편 Daily 리포트 상세는 현재 임시 화면입니다. Mobile에서는 세로 흐름을 유지하고 Desktop에서는 Calendar와 선택일 상세를 2-column으로 동시에 표시합니다. 아내·남편 Desktop 캘린더는 날짜 셀과 패널 비율, 패널 사이 여백을 확대해 넓은 화면을 충분히 사용합니다.

남편 영역은 `/husband/calendar`를 기본 홈으로 사용합니다. 알림은 오전 Report 또는 request ID의 가사 Request로 이동하며, 남편 화면에는 Bottom Navigation을 두지 않습니다. 남편 주요 화면의 메뉴 아이콘은 글자 크기 조정만 제공하는 전용 메뉴로 연결됩니다. 알림 목록은 컨디션 리포트·가사 요청·루틴 변경을 유형 배지, 아이콘, 배경색으로 구분합니다. 가사 요청 화면은 부가 안내와 참고 정보 없이 집안일 목록에 집중하며, 카드별로 확인·완료합니다. 확인 카드는 파란색, 완료 카드는 초록색 상태 면으로 구분합니다. 캘린더 날짜 원은 44px로 제한해 넓은 화면에서도 월 전체를 한눈에 볼 수 있습니다.

남편 가사 요청 화면에서는 내부 요청 ID를 표시하지 않습니다. 요청 상세 이동과 확인·완료 처리는 이 ID를 내부적으로 계속 사용합니다.

아내 메뉴의 프로필 이미지·사용자명·임신 주차 요약은 일반 탭으로 이동하지 않으며, 별도의 `프로필 수정` 항목만 프로필 수정 Route로 연결됩니다. 아내·남편 메뉴의 프로필 이미지를 1초 이내 간격으로 5회 연속 선택하면 Local Mock 시연 사용자가 반대 역할로 전환되고 기존 Route stack은 대상 역할 Home으로 교체됩니다. 아내 설정과 남편 메뉴에서는 앱 글자 크기를 `작게·기본·크게` 3단계로 조정할 수 있습니다. 선택값은 브라우저에 저장되고, 기기의 접근성 글자 확대 배율을 유지한 상태에서 앱 전체에 추가 적용됩니다.

실시간 경로는 아내 `/wife/live`, 남편 `/husband/live`입니다. 아내는 하단 실시간 탭으로, 남편은 캘린더에서 오늘 날짜를 선택했을 때 표시되는 버튼으로 진입합니다. 두 화면 모두 홈카메라 ON/OFF 스위치를 제공하지 않습니다. 오늘 이벤트는 처음 3건만 표시하고 `더보기`로 전체 기록을 불러옵니다. 현재 화면 데이터는 Local Mock이고 실제 카메라·MediaPipe·실시간 센서를 실행하지 않습니다. 브라우저 카메라/WebSocket 코드는 `main_movement_debug.dart`의 독립 기술 데모에 남아 있습니다.

라우팅은 [ROUTE_MAP_V2](docs/development/ROUTE_MAP_V2.md)를 따릅니다. `/entry`에서 인증·연결 상태를 확인하고, 아내는 프로필 첫 단계 또는 `/wife/home`으로, 연결된 남편은 `/husband/calendar`로 이동합니다. 미연결 남편에게는 초대 필요 안내를 표시합니다. `auth`와 `activeRole`을 별도 상태로 유지하며, 역할 전환은 권한 확인 후 이전 이동 기록을 지우고 대상 역할 홈으로 이동합니다. 계정별 `activeRole`은 Web 저장소에서 복원하지만 실제 ThinQ 세션·권한 연동은 아직 제공되지 않습니다. 다른 역할의 URL로 최초 접근하면 현재 역할 Home과 브라우저 주소를 함께 보정하며, `/wife/meal/:mealKey`는 새로고침해도 해당 끼니 상세를 복원합니다.

요구사항 재감사 후 프로필 2단계에 생년월일·임신 전 신장·체중 입력을 반영하고, 예정 활동 수정 진입과 남편 가사 요청의 항목별 확인·완료 상태 반영을 추가했습니다. 프로필은 예정일/LMP 기반 임신 주수를 계산하고 필수 선택 단계에서는 다음 버튼을 비활성화합니다. 알레르기가 없으면 아무 항목도 선택하지 않고 넘어갈 수 있습니다. 병원 주의사항의 `없어요`는 다른 진단과 상호 배타적이며, 선택 시 `그 외 들은 말` 입력을 지우고 비활성화합니다. Demo Profile은 브라우저 localStorage에 보존되지만 서버 계정과 동기화되지 않으며, 리포트도 영구 저장되지 않습니다. 실제 가전·모션 연동이 없는 MVP Mock 리포트에서 가전 시연 전 실행 횟수와 모션 감지 횟수는 0으로 표시합니다.

## 기술 구성

- Frontend: Flutter Web, Dart, Material 3, `flutter_dotenv`, Supabase Flutter
- Backend: Python 3.11+, FastAPI, Pydantic, Supabase Python, MediaPipe, OpenCV
- Data/Auth: Supabase Auth 및 PostgreSQL
- Documentation: 요구사항, Mermaid 서비스 흐름도, 화면 참고 이미지, Design System 및 단계별 Frontend 설계

## 저장소 구조

```text
PLM/
├── frontend/                 # Flutter Web 앱과 Frontend 테스트
├── backend/                  # FastAPI 앱, 프로필·모션 기능과 테스트
├── supabase/                 # migration 및 DB 설계 메모
├── tools/motion_demo/        # PC 웹캠 기반 독립 모션 검증 도구
├── docs/
│   ├── requirements/         # 제품 및 기능 요구사항
│   ├── 서비스흐름도/          # 사용자 흐름 Mermaid 문서
│   ├── screens/              # 화면 정보 구조 참고 이미지
│   ├── development/          # Frontend STEP 1~5 분석·설계 결과
│   ├── FRONTEND_PROGRESS.md  # 화면 QA 결과와 남은 작업
│   ├── movement/             # 모션 통합 설계와 검증 문서
│   ├── architecture.md
│   └── api.md
├── DESIGN.md                 # UI 시각 규칙의 최우선 기준
├── AGENTS.md                 # 프로젝트 작업 규칙
└── guide.md                  # 개발 환경 및 실행 문제 해결
```

## 빠른 시작

### Frontend

Flutter stable과 Chrome이 필요합니다.

```powershell
cd frontend
flutter pub get
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
flutter run -d chrome
```

자세한 실행 방법과 SDK 설정은 [Frontend README](frontend/README.md)와 [개발 환경 안내](guide.md)를 확인하세요.

### Backend

```powershell
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

- API: <http://localhost:8000>
- Swagger UI: <http://localhost:8000/docs>
- 상세 설정: [Backend README](backend/README.md)
- 실제 계약: [API 문서](docs/api.md)

환경변수가 비어 있어도 Frontend 초기 화면과 Backend의 `/`, `/health`는 실행할 수 있습니다. 프로필 API에는 Supabase 설정과 migration 적용이 필요합니다.

## 환경변수

| 변수 | Frontend | Backend | 용도 |
| --- | :---: | :---: | --- |
| `BACKEND_URL` | O | - | FastAPI 기본 주소 |
| `SUPABASE_URL` | O | O | Supabase 프로젝트 URL |
| `SUPABASE_ANON_KEY` | O | - | 공개 클라이언트 키. Backend는 `Settings`에 선언만 있고 사용하지 않습니다 |
| `SUPABASE_SERVICE_ROLE_KEY` | - | O | 서버 전용 DB 접근 키 |
| `LLM_API_KEY` | - | O | 향후 외부 AI 공급자 인증 |
| `LLM_API_BASE_URL` | - | O | 향후 외부 AI API 주소 |

실제 `.env`는 Git에 포함하지 않습니다. 브라우저에 노출되는 Frontend 환경에는 service role key나 LLM API key를 넣지 마세요.

## 검증

```powershell
cd frontend
flutter analyze
flutter test
flutter build web
```

```powershell
cd backend
.venv\Scripts\python.exe -m pip check
.venv\Scripts\python.exe -m unittest discover -s tests
```

카메라 권한과 실제 WebSocket 모션 흐름은 자동 테스트만으로 검증할 수 없으므로 Chrome에서 별도 확인해야 합니다.

## 최근 변경

### 2026-09-17 — Backend 병렬 개발 Skeleton

- 세 명의 개발자가 각각 `account`, `care`, `family`를 소유하도록 Router·Schema·Service Protocol·Repository Protocol·메모리 Stub 경계를 추가했습니다.
- Bootstrap, 최종 Profile, 컨디션·예정 활동, 실행 기록, Daily report·Calendar, 가사 요청·알림, Motion 동의·수집 설정 API 계약을 OpenAPI에 연결했습니다.
- AI Routine과 Movement 보호 영역, 기존 migration은 수정하지 않았습니다.
- 개발 경계와 실제 adapter 교체 지점은 [Backend Domain Ownership](backend/DOMAIN_OWNERSHIP.md), endpoint 계약은 [API 문서](docs/api.md)에 정리했습니다.
- Backend 전체 테스트 54개를 통과했습니다.

### 2026-09-17 — Pregnancy Life Mode 공통 UI 정돈

- 공통 Scaffold와 AppBar를 밝은 `surface` 기반으로 통일해 Life Mode 진입 전후의 배경 차이를 줄였습니다.
- Teal은 내비게이션 선택, Primary CTA, 임신 주차와 진행 상태 등 의미가 있는 강조에 집중했습니다.
- Meal·Health·Sleep·Report의 큰 카테고리색 면을 중립 surface와 border 구조로 바꾸고 카테고리색은 아이콘·배지·텍스트에 남겼습니다.
- 공통 Button, AppBar, Mobile Bottom Navigation, Desktop Navigation Rail의 형태와 상태 표현을 같은 디자인 시스템 규칙으로 맞췄습니다.
- Wife 주요 화면의 네 목적지를 `WifeNavigationScaffold`로 통합해 Mobile·Tablet은 Bottom Navigation, Desktop·Wide는 Navigation Rail을 사용합니다.
- Home은 Desktop에서 루틴과 컨디션·주차 맥락을 8:4로, Meal·Health는 본문과 근거·상태를 split view로, Household는 직접·가전·가족 영역을 3열로 재구성합니다.
- Sleep 환경은 넓은 화면에서 3열로 확장하고 Calendar·Report·Movement의 기존 split view와 동일한 최대 폭·여백 규칙을 사용합니다.
- 화면 구조, Route, Interaction, Mock Data와 Service 로직은 유지했습니다.

### 2026-09-16 — Backend 프로필 출산예정일 규칙 완화 (W-PROFILE-001)

기획 개정에서 W-PROFILE-001이 "출산예정일 입력(1/6)"으로 세분화되고, 출산예정일을 모르는 경우 마지막 생리 시작일(LMP)로 산출한다는 내용이 확정되면서 Backend 검증 규칙을 맞췄습니다.

| 항목 | 이전 | 현재 |
| --- | --- | --- |
| 출산예정일 입력 범위 | 오늘 기준 14일 전 ~ 280일 후 | 오늘 기준 14일 전 ~ **365일 후** |
| 마지막 생리 시작일 | 선택이지만 출산예정일과 함께 보내면 `+280일`로 정확히 일치해야 함 | **선택 입력**. 함께 보내도 일치 검사를 하지 않음 |
| 두 값을 함께 보낸 경우 | 불일치 시 422 | 병원에서 진단받은 `due_date`를 그대로 저장하고 LMP는 보낸 값 그대로 보관 |
| 마지막 생리 시작일만 보낸 경우 | `+280일`로 출산예정일 자동 계산 | 동일하게 유지 |
| 미래 날짜의 마지막 생리 시작일 | 범위 검사에 걸릴 때만 거부 | 명시적으로 거부 |

- 임신 주수 계산 기준(`FULL_TERM_DAYS = 280`)은 바뀌지 않았습니다. 입력 상한만 `MAX_DUE_AHEAD_DAYS = 365`로 분리했습니다.
- 두 값이 `+280일` 관계여야 한다는 DB CHECK 제약을 `supabase/migrations/20260916000000_relax_due_date_constraint.sql`로 제거했습니다. **이 migration을 Supabase에 적용해야 변경이 완료됩니다.**
- 변경 파일: `backend/app/schemas/profile.py`, `backend/tests/test_profile.py`, `docs/api.md`, `supabase/migrations/20260916000000_relax_due_date_constraint.sql`
- 검증: `backend`에서 `python -m unittest discover -s tests` 23개 통과

## 주요 문서

- [제품 요구사항](docs/requirements/01_PRD.md)
- [Frontend 작업 운영 기준](docs/development/frontend_workflow.md)
- [Frontend 분석](docs/development/01_frontend_analysis.md)
- [Frontend Architecture](docs/development/02_frontend_architecture.md)
- [Design System 설계](docs/development/03_design_system.md)
- [Component System 설계](docs/development/04_component_system.md)
- [화면 구현 계획](docs/development/05_ui_implementation_plan.md)
- [Screen 구현 Map](docs/SCREEN_IMPLEMENTATION_MAP.md)
- [공통 UI Gap 분석](docs/development/06_common_ui_gap_analysis.md)
- [모션 통합 문서](docs/movement/README.md)

## 협업 규칙

- 커밋 제목과 본문은 한글로 작성합니다.
- Frontend 작업은 [Frontend 작업 운영 기준](docs/development/frontend_workflow.md)의 STEP을 순서대로 진행합니다.
- 화면 구조·콘텐츠는 `docs/screens/**`를 참고하되 시각 규칙이 충돌하면 `DESIGN.md`를 우선합니다.
- 화면과 Route의 추적 ID는 `docs/requirements/04_1_기능요구사항명세서.md`의 `W-*`·`H-*` 기능 요구사항 ID를 사용하며 별도 Screen ID를 만들지 않습니다.
- 기능 변경 시 관련 README를, 환경 설정과 실행 예외가 바뀌면 `guide.md`를 함께 갱신합니다.

## 백엔드 API 연동

Supabase 설정이 있는 실행 환경에서는 기존 계정으로 로그인한 뒤 FastAPI의 계정 상태 조회를 통해 아내·남편 화면으로 이동합니다. 아내 프로필의 단계별 저장, 오늘 컨디션 저장·복원, 예정 활동 저장, 루틴 생성·조회, 식사·가사·수면 가이드 조회, 가사 요청 생성, 초대 링크 생성·수락, 리포트와 캘린더 조회·확정을 API로 처리합니다. 환경 값이 비어 있으면 기존 로컬 화면 흐름을 사용합니다.

백엔드의 프로필 계약에는 생년월일 필드가 없으므로 생년월일은 로그인 계정별 브라우저 저장소에 보관합니다. 가이드 응답의 `item_id`를 사용해 건강 활동 완료와 수면 환경 변경을 서버에 저장합니다. 루틴 생성 결과의 `source`가 `ai`가 아니면 서버가 생성한 기본 루틴으로 표시하며, API 실패 시 Mock 데이터를 대신 표시하지 않습니다. 실제 가전 제어와 Chat 기능은 연결 대상에 포함되지 않습니다. 실행 설정과 점검 방법은 [guide.md](guide.md)를 참고하세요.
