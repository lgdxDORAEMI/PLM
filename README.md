# PLM — ThinQ Pregnancy Life Mode

PLM은 임신 주수, 당일 컨디션, 예정 활동과 생활 기록을 바탕으로 임산부의 식사·가사·건강·수면 루틴을 개인화하고 가족의 돌봄 참여를 돕는 생활관리 서비스입니다.

현재 저장소는 Profile Setup, 배우자 초대·수락, Home·Today Care·예정 활동·Daily Routine, Smart Meal Guide, 식사 재조정 AI Chat, 가사·건강·Sleep Care, 날짜별 Record/Calendar, 실시간 Movement, 파트너 리포트·알림·가사 요청 Flow가 실제 UI로 구현된 Flutter Web Frontend와, 프로필 일부 및 모션 인식 데모를 제공하는 FastAPI Backend로 구성됩니다. 외부 연동 전인 Routine·Chat·초대·Partner Flow와 생활 데이터는 Mock/local 상태를 사용합니다.

## 핵심 사용자 흐름

```text
임산부
프로필 등록 → 배우자 초대 → 오늘의 컨디션·예정 활동 입력
→ 개인화 루틴 확인 → 식사·가사·건강·수면 가이드 실행
→ 완료 기록과 Daily 리포트 확인

배우자
초대 수락 → 오전 컨디션 리포트 확인
→ 가사 요청 확인·완료 → 캘린더에서 기록 확인
```

MVP는 가전 자동 실행과 홈카메라 기반 실시간 위험 행동 로그를 제외하고, 컨디션 입력부터 루틴 실행·가족 분담·기록까지의 핵심 루프를 검증하는 데 초점을 둡니다. 정확한 범위는 [MVP 정의](docs/requirements/01_MVP.md)를 따릅니다.

## 현재 상태

| 영역 | 구현 상태 | 비고 |
| --- | --- | --- |
| Frontend 기반 | 구현 | Flutter Web 초기화, 환경설정, DESIGN.md 기반 Theme·반응형 Layout·공통 상태/Badge/Task Component |
| Frontend 제품 UI | 부분 구현 | Profile 6단계, 초대, Home·Today Care·예정 활동, Daily Routine, Meal·Chat, 가사·건강·Sleep, Record/Calendar·Realtime, Partner Report·Inbox·Request 구현. 설정·Partner Profile은 요구사항 확정 대기 |
| 모션 인식 Web 데모 | 구현 | 브라우저 카메라 프레임 전송, 캘리브레이션, 자세 오버레이와 상태 표시 |
| Backend 기본 API | 구현 | `/`, `/health`, 개발용 CORS |
| 임산부 프로필 | 부분 구현 | 프로필 1/6 출산예정일(W-PROFILE-001), 2/6 신장·임신 전 체중(W-PROFILE-002) 조회·저장. 3~6단계(초산/경산·단태/쌍태·알레르기·주의 진단)와 확인·저장 단계는 미구현 |
| 모션 분석 API | 데모 구현 | 단일 세션 WebSocket 분석, 이벤트 및 일일 집계 조회 |
| Supabase | 부분 구현 | Auth 토큰 검증 경계와 `pregnancy_profiles` migration 2건(생성, 출산예정일 제약 완화) |
| AI 루틴·LLM | 미구현 | 인터페이스만 존재하며 공급자 및 실제 호출 없음 |
| 배우자 UI | 부분 구현 | 초대 수락, 공통 Calendar, 오전 리포트, 알림함, 가사 요청 확인·완료 구현. Partner Profile은 상세 요구사항 확정 대기 |
| ThinQ 가전 연동 | 미구현 | MVP에서는 추천까지만 제공하고 실제 제어는 제외 |
| Android / iOS | 미지원 | 저장소에는 Web 플랫폼만 준비되어 있음 |

Frontend 제품 UI 작업은 Backend 구현과 분리합니다. Backend가 준비되지 않은 화면은 Mock Data와 Mock Service를 사용하고, 향후 Service 구현 교체만으로 실제 API에 연결할 수 있도록 설계합니다.

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
│   ├── FRONTEND_PROGRESS.md  # Skeleton 현황과 공용 파일 경계
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
