# PLM — Pregnancy Life Mode

PLM은 임산부의 프로필, 오늘 컨디션과 예정 활동을 바탕으로 식사·가사·건강·수면 루틴을 생성하고 가족과 실행 결과를 공유하는 Flutter Web 서비스입니다. FastAPI가 인증된 API와 AI 기능을 제공하고 Supabase Auth/PostgreSQL이 계정과 생활 기록을 저장합니다.

## 운영 서비스

| 구분 | 주소 |
| --- | --- |
| Web 앱 | <https://lgdxdoraemi.github.io/PLM/> |
| Backend API | <https://plm-backend-production-cc76.up.railway.app> |
| Swagger UI | <https://plm-backend-production-cc76.up.railway.app/docs> |
| 상태 확인 | <https://plm-backend-production-cc76.up.railway.app/health> |

Web 앱은 GitHub Pages, Backend는 Railway에서 운영합니다. 브라우저가 이전 번들을 유지하면 `Ctrl+Shift+R`로 새로고침합니다.

## 주요 기능

- 프로필 및 출산예정일 기반 임신 주차 계산
- 오늘 컨디션·예정 활동 저장과 AI 맞춤 루틴 생성·영향 범위별 부분 재생성
- 루틴 생성 전에도 표시되는 홈 주차별 안내와 변경 없는 홈 재진입 시 기존 루틴 즉시 복원
- 식사·가사·건강·수면 가이드, 통증 집중 부위 운동과 `오늘 안하기`를 반영하는 루틴 진행도 및 실행·피드백 기록
- 오늘 대화만 복원하는 챗봇, 식사 대체 추천, 사용자 확인 후 컨디션 저장과 루틴 수정
- 배우자 초대·연결, 오전 리포트, 알림, 가사 요청 확인·완료
- Daily 리포트와 월별 기록 날짜를 먼저 표시하고 선택 날짜 상세를 독립적으로 불러오는 캘린더
- 모션 이벤트 조회와 별도 카메라/WebSocket 분석 화면
- ThinQ 보유 기기 조회·가사 항목 매칭과 수면 가이드 공기청정기 전원·바람세기 제어

홈은 첫 진입에 필요한 응답만 조회하고 네 가이드를 함께 불러옵니다. 가사 요청 목록과 캘린더 날짜 상세도 필요한 날짜만 조회합니다.

ThinQ 가사 가이드는 보유 기기 조회와 항목 매칭까지만 수행하며 세탁기 등 가사를 직접 실행하지 않습니다. 실제 제어는 수면 가이드에서 연결된 공기청정기의 전원과 바람세기에만 제한됩니다. 일반 앱의 실시간 화면은 저장된 모션 이벤트를 조회하고, 카메라 분석은 별도 진입점으로 실행합니다.

## 사용자 흐름

1. 등록된 아내 계정으로 진입해 프로필을 작성합니다.
2. 오늘 컨디션과 예정 활동을 입력하고 루틴을 생성합니다.
3. 홈과 네 가지 가이드에서 추천 내용을 확인하고 실행 상태를 기록합니다.
4. 챗봇에서 상담하거나 식사 대체 메뉴와 컨디션 수정을 요청합니다.
5. 리포트·캘린더에서 기록을 확인하고 연결된 남편과 가사 요청·알림을 공유합니다.

## 주요 동작 기준

- 오늘 루틴 생성은 명시적인 생성 요청에서만 수행합니다. 이미 생성된 루틴이 있고 입력 변경이 없으면 홈 재진입만으로 다시 생성하지 않습니다.
- 홈은 오늘 루틴을 메모리에 보관해 다른 화면에서 돌아올 때 기존 결과를 즉시 표시합니다. 컨디션 변경이나 계정 전환 시에는 캐시를 무효화합니다.
- 캘린더는 월별 기록 날짜를 먼저 표시하고 선택 날짜의 컨디션·루틴·가족·가전 상세는 별도로 조회합니다. 상세 실패가 월 달력을 가리지 않습니다.
- 캘린더 상세는 입덧·허리·골반·다리·손목·피로·기분에 저장된 1~5점 전체를 표시합니다.
- 건강 가이드는 3점 이상인 모든 통증 부위를 오늘의 집중 항목으로 추천하고, 모두 3점 미만이면 전신 운동 영상이 연결된 `health:whole` 항목을 루틴에 포함합니다. 다른 부위 영상은 별도로 조회할 수 있지만 진행도에는 집중 항목의 `활동 완료` 또는 `오늘 안하기`만 반영됩니다.

## 저장소 구성

| 경로 | 역할 |
| --- | --- |
| [frontend](frontend/README.md) | Flutter Web 앱, 화면·상태·API 클라이언트 |
| [backend](backend/README.md) | FastAPI, AI 루틴·챗봇, 가족 공유, 모션·ThinQ |
| [supabase](supabase/README.md) | PostgreSQL 마이그레이션과 접근 정책 |
| [docs](docs/README.md) | API 계약, 요구사항, 화면 흐름과 연동 현황 |
| [tools](tools/rag_ingest/README.md) | 지식 데이터 적재 및 모션 개발 도구 |

주요 데이터 흐름은 `Flutter Screen → Controller/Service → FastAPI → Supabase`입니다. Frontend 기능 코드는 Supabase 테이블을 직접 조작하지 않으며 인증 세션만 Supabase Auth SDK로 관리합니다.

## 빠른 시작

자세한 초기 설정과 예외 처리는 [guide.md](guide.md)를 참고합니다.

```powershell
# Backend
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python -m app.server
```

```powershell
# Frontend — 별도 터미널
cd frontend
flutter pub get
Copy-Item .env.example .env
flutter run -d chrome
```

Backend는 기본 `http://localhost:8000`, Swagger는 `http://localhost:8000/docs`에서 실행됩니다. Frontend `.env`에는 `SUPABASE_URL`, 공개 `SUPABASE_ANON_KEY`, `BACKEND_URL`을 입력합니다. 서버 비밀키와 등록 계정 비밀번호는 반드시 `backend/.env`에만 둡니다.

## 배포 구조

```text
GitHub main
├─ frontend/** 변경 → GitHub Actions → Flutter Web → GitHub Pages
└─ backend/** 변경  → Railway GitHub 연동 → Dockerfile → Railway Service

GitHub Pages ── HTTPS/Bearer token ──> Railway FastAPI ──> Supabase
                                           ├─ OpenAI 호환 LLM
                                           └─ ThinQ API (기기 조회·공기청정기 제어)
```

### GitHub Pages

`.github/workflows/deploy-pages.yml`은 `main`의 `frontend/**` 또는 Workflow 변경 시 실행됩니다. Repository Variables는 다음 세 값을 사용합니다.

```text
API_BASE_URL=https://plm-backend-production-cc76.up.railway.app
SUPABASE_URL=<Supabase Project URL>
SUPABASE_ANON_KEY=<Supabase public anon key>
```

Workflow가 `frontend/.env`를 생성하고 다음과 같은 릴리스 빌드를 수행합니다.

```bash
flutter build web --release \
  --base-href "/PLM/" \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

GitHub Pages의 Source는 `GitHub Actions`로 설정합니다. Backend나 문서만 변경한 커밋은 Frontend 배포를 만들지 않습니다.

### Railway Backend

Railway 서비스는 GitHub 저장소의 `backend`를 Root Directory로 사용하고 `backend/Dockerfile`로 빌드합니다.

```text
Root Directory: backend
Dockerfile Path: /backend/Dockerfile
Start Command: python -m app.server
Healthcheck Path: /health
Watch Path: /backend/**
```

Railway Variables에는 Supabase 서버 설정, 등록 계정, LLM, ThinQ 설정과 아래 Origin을 입력합니다.

```text
FRONTEND_ORIGIN=https://lgdxdoraemi.github.io
```

`SUPABASE_SERVICE_ROLE_KEY`, `PLM_*_PASSWORD`, `LLM_API_KEY`, `THINQ_PAT`은 Railway에만 저장하며 GitHub Variables나 Flutter 빌드에 포함하지 않습니다. 전체 변수와 배포 순서는 [guide.md의 배포 안내](guide.md#railway와-github-pages-배포)를 참고합니다.

## 배포 후 확인

1. `/health`가 `{"status":"ok"}`를 반환하는지 확인합니다.
2. `/docs`에서 Swagger UI와 최신 API 경로를 확인합니다.
3. Web 앱의 개발자 도구 Network에서 요청 대상이 Railway 도메인인지 확인합니다.
4. 등록 계정 진입이 403이면 Railway의 `FRONTEND_ORIGIN`이 Pages Origin과 정확히 일치하는지 확인합니다.
5. 503이면 Railway 로그와 Supabase 테이블·마이그레이션, LLM 설정을 확인합니다.

API 목록은 [docs/api.md](docs/api.md), 화면별 연결 현황은 [docs/FE_BE_CONNECTION_STATUS.md](docs/FE_BE_CONNECTION_STATUS.md)에 있습니다.

## 검증

```powershell
cd backend
python -m unittest discover -s tests

cd ..\frontend
flutter analyze
flutter test
flutter build web --release --base-href /PLM/
```

기능 범위에 맞는 테스트를 우선 실행하고, 배포 전에는 정적 분석과 Web 릴리스 빌드를 확인합니다.
