# PLM Backend

PLM Backend는 인증된 생활 기록, AI 루틴·챗봇, 네 가지 가이드, 가족 공유, 모션 분석과 ThinQ 조회를 제공하는 FastAPI 서버입니다.

운영 주소:

- API: <https://plm-backend-production-cc76.up.railway.app>
- Swagger UI: <https://plm-backend-production-cc76.up.railway.app/docs>
- Healthcheck: <https://plm-backend-production-cc76.up.railway.app/health>

## 제공 기능

- Supabase Auth Bearer token 검증
- 등록된 아내·남편 계정 세션 발급과 전환
- 임산부 프로필, 오늘 컨디션과 예정 활동 저장
- 프로필 주차 기반 홈 안내와 AI 루틴 생성·부분 재생성
- 식사·가사·건강·수면 가이드 조회와 실행·피드백 기록
- LLM 챗봇, 최근 200건 대화 복원, 식사 대체 추천, 컨디션 수정 작업
- Daily 리포트, 캘린더, 가족 알림과 가사 요청
- 모션 WebSocket 분석, 이벤트 저장과 일일 집계
- ThinQ 보유 기기 읽기와 가사 항목 매칭

AI 루틴 생성이 실패하면 서버 폴백 루틴을 저장할 수 있습니다. ThinQ는 읽기 전용이며 실제 기기 제어 명령은 보내지 않습니다.

## 코드 구조

| 경로 | 역할 |
| --- | --- |
| `app/api/v1/` | HTTP·WebSocket 라우터, 인증·오류 경계 |
| `app/domains/` | account, care, chat, family, guide 서비스와 저장소 |
| `app/services/routine/` | 루틴 입력, RAG 검색, LLM 생성과 저장 |
| `app/services/movement/` | 자세 추출, 캘리브레이션, 이벤트와 집계 |
| `app/services/thinq/` | ThinQ 기기 조회와 가사 항목 매칭 |
| `tests/` | API·서비스·저장소 회귀 테스트 |
| `models/` | MediaPipe 런타임 모델 |

## 로컬 설치와 실행

Python 3.13 환경을 기준으로 합니다.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
Copy-Item .env.example .env
python -m app.server
```

기본 포트는 `8000`이며 `PORT`가 있으면 해당 값을 검증해 사용합니다.

```text
http://localhost:8000/health
http://localhost:8000/docs
```

## 환경변수

| 변수 | 용도 | 공개 가능 여부 |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase Project URL | Frontend에도 사용 가능 |
| `SUPABASE_ANON_KEY` | Auth 공개 클라이언트 키 | Frontend에도 사용 가능 |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버 DB 접근 | 비공개 |
| `SUPABASE_DB_URL` | 직접 마이그레이션 연결 | 비공개, 필요할 때만 |
| `PLM_WIFE_EMAIL`, `PLM_WIFE_PASSWORD` | 등록 아내 계정 | 비공개 |
| `PLM_HUSBAND_EMAIL`, `PLM_HUSBAND_PASSWORD` | 등록 남편 계정 | 비공개 |
| `LLM_API_KEY`, `LLM_API_BASE_URL` | OpenAI 호환 LLM | API Key 비공개 |
| `THINQ_PAT`, `THINQ_COUNTRY_CODE`, `THINQ_CLIENT_ID` | ThinQ 조회 | PAT 비공개 |
| `FRONTEND_ORIGIN` | 자동 계정 진입을 허용할 운영 Web Origin | 공개 가능 |

운영값 예시:

```dotenv
FRONTEND_ORIGIN=https://lgdxdoraemi.github.io
```

`FRONTEND_ORIGIN`에는 `/PLM/` 경로가 아니라 Origin만 입력합니다. `.env`를 커밋하지 않고 Railway Variables에서 비밀값을 관리합니다.

## Supabase와 마이그레이션

Backend는 Auth와 PostgreSQL 스키마가 모두 준비되어 있어야 합니다. 마이그레이션은 저장소의 `supabase/migrations/` 순서로 적용합니다. API에서 특정 컬럼이 없다는 503이 발생하면 애플리케이션 재배포만 반복하지 말고 운영 DB의 최신 마이그레이션 적용 여부를 확인합니다.

주요 데이터는 다음 영역에 저장됩니다.

- `profiles`, `pregnancy_profiles`
- `daily_conditions`, `daily_routines`, `routine_items`
- `chat_messages`, `recommendation_feedback`
- `daily_reports`, `notifications`
- `partner_links`, `partner_invitations`
- `household_requests`, `household_request_items`
- 모션 동의·세션·이벤트 테이블

DB 적용 절차는 [Supabase README](../supabase/README.md)를 참고합니다.

## API와 인증

- 일반 REST prefix: `/api/v1`
- OpenAPI/Swagger: `/docs`
- Healthcheck: `/health`
- 인증 API: Supabase access token을 Bearer token으로 전달
- 자동 등록 계정 세션 API: localhost 또는 `FRONTEND_ORIGIN` 요청만 허용
- 날짜 기준: 생활 기록은 KST 날짜 사용

`GET /api/v1/chat/messages`는 날짜를 생략하면 최근 200건을 날짜 경계 없이 반환합니다. `GET /api/v1/routine/home`은 오늘 컨디션이나 루틴 생성 여부와 무관하게 프로필 주차 안내를 반환합니다.

전체 계약은 [API 문서](../docs/api.md)에서 확인합니다.

## 테스트

```powershell
python -m unittest discover -s tests
```

변경 범위가 작으면 관련 모듈을 우선 실행합니다.

```powershell
python -m unittest tests.test_chat tests.test_routine_home tests.test_app
```

## Railway 배포

Railway의 GitHub 연결 서비스는 다음 설정을 사용합니다.

```text
Root Directory: backend
Dockerfile Path: /backend/Dockerfile
Start Command: python -m app.server
Healthcheck Path: /health
Watch Path: /backend/**
```

`backend/Dockerfile`은 Python 3.13 slim 이미지에 requirements와 MediaPipe/OpenCV가 요구하는 Linux 라이브러리를 설치합니다. `models/pose_landmarker_full.task`는 모션 API 런타임 파일이므로 배포에서 제외하면 안 됩니다.

배포 순서:

1. Railway 서비스 Variables를 `backend/.env.example` 기준으로 입력합니다.
2. `FRONTEND_ORIGIN=https://lgdxdoraemi.github.io`를 설정합니다.
3. Public Networking 도메인을 생성합니다.
4. 배포 후 `/health`와 `/docs`를 확인합니다.
5. GitHub의 `API_BASE_URL`을 Railway 공개 주소로 설정합니다.
6. Pages 앱에서 등록 계정 진입과 인증 API를 확인합니다.

Railway의 `PORT`는 자동 주입됩니다. Start Command에서 `$PORT`를 직접 확장하지 않고 `python -m app.server`를 유지합니다.

## 운영 문제 확인

| 증상 | 확인 항목 |
| --- | --- |
| 401 | Supabase 세션과 access token |
| 403 | 역할 권한, 요청 Origin, `FRONTEND_ORIGIN` |
| 404 | 해당 날짜의 컨디션·루틴·리포트 존재 여부 |
| 409/422 | 선행 입력, 상태 충돌, 요청 본문 |
| 503 DB 오류 | Supabase 연결, 서비스 키, 운영 마이그레이션 |
| 503 Chat/AI 오류 | `LLM_API_KEY`, Base URL, 공급자 응답 |
| 시작 실패 | Railway Root Directory, Dockerfile, `PORT`, 런타임 라이브러리 |

더 자세한 초기 설정과 장애 대응은 [guide.md](../guide.md)를 참고합니다.
