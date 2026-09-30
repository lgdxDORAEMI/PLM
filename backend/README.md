# PLM Backend

PLM Backend는 인증된 생활 기록, AI 루틴·챗봇, 네 가지 가이드, 가족 공유, 모션 분석과 ThinQ 연동을 제공하는 FastAPI 서버입니다.

운영 주소:

- API: <https://plm-api.dx6project.site>
- Swagger UI: <https://plm-api.dx6project.site/docs>
- Healthcheck: <https://plm-api.dx6project.site/health>

## 제공 기능

- Supabase Auth Bearer token 검증
- 등록된 아내·남편 계정 세션 발급과 전환
- 임산부 프로필, 오늘 컨디션과 예정 활동 저장
- 프로필 주차 기반 홈 안내와 AI 루틴 생성·영향 범위별 부분 재생성
- 식사·가사·건강·수면 가이드 조회와 실행·피드백 기록, 3점 이상인 모든 통증 부위(없으면 영상이 연결된 `health:whole` 전신 운동)를 집중 항목으로 보장
- LLM 챗봇, 오늘 대화 복원, 식사 대체 추천, 사용자 확인형 컨디션 수정 작업
- Daily 리포트 미리보기·확정, 월별 캘린더와 선택 날짜 통합 상세, 가족 알림과 가사 요청
- 모션 WebSocket 분석, 이벤트 저장과 일일 집계
- ThinQ 보유 기기 읽기, 가사 항목 매칭과 수면가이드 공기청정기 전원·바람세기 제어

AI 루틴 생성이 실패하면 서버 폴백 루틴을 저장할 수 있습니다. ThinQ의 기기 목록 조회 자체는 읽기 전용이며,
실제 제어 명령은 데모 범위로 확정된 수면가이드의 공기청정기 전원·바람세기에만 보냅니다
(가사가이드의 "가전이 대신합니다"는 실제 보유 기기 목록과 매칭하지만, 세탁기 등 다른 가전의 실행 버튼은 로컬 실행 기록만 남깁니다).

가사 가이드의 ThinQ 조회는 일시적인 `timeout` 또는 통신 오류에 한 번 재시도합니다. 정상 기기 목록은 5분간 즉시 재사용하고, 갱신 실패 시 마지막 정상 목록을 최대 30분간 유지해 빨래 항목이 갑자기 가족 분담으로 이동하지 않게 합니다. 인증 오류나 계정 불일치에는 이전 목록을 사용하지 않습니다.

## 루틴과 가이드 동작

- `GET /api/v1/routine/today`는 저장된 오늘 루틴을 조회하며 새 루틴을 만들지 않습니다.
- `POST /api/v1/routine/today`가 명시적인 생성·재생성 진입점입니다. 입력이 바뀌지 않은 미확정 루틴은 LLM 호출과 새 저장 없이 그대로 반환합니다.
- 컨디션이나 예정 활동이 바뀌면 영향도를 계산해 필요한 가이드만 조정하거나 다시 생성하고, 실패한 카테고리는 직전 결과 또는 서버 템플릿으로 보존합니다.
- 허리·골반·다리·손목 통증이 모두 3점 미만이면 AI 응답과 관계없이 `health:whole` 전신 저강도 스트레칭을 포함합니다.
- 가이드 조회는 저장된 `routine_items`를 읽으며 화면 진입만으로 AI를 다시 호출하지 않습니다.

## 코드 구조

| 경로 | 역할 |
| --- | --- |
| `app/api/v1/` | HTTP·WebSocket 라우터, 인증·오류 경계 |
| `app/domains/` | account, care, chat, family, guide 서비스와 저장소 |
| `app/services/routine/` | 루틴 입력, RAG 검색, LLM 생성과 저장 |
| `app/services/movement/` | 자세 추출, 캘리브레이션, 이벤트와 집계 |
| `app/services/thinq/` | ThinQ 기기 조회, 가사 항목 매칭과 공기청정기 제어 API |
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

Windows에서 기존 `.venv`가 삭제되거나 이동된 Python 경로를 가리키면 `pyvenv.cfg`만 고쳐 쓰지 말고 가상환경을 재생성합니다. 다음 오류는 기반 Python이 없다는 뜻입니다.

```text
did not find executable at '...Python...\python.exe'
```

정상 Python 설치를 확인한 뒤 기존 `.venv`를 제거하거나 이름을 바꾸고 위 설치 절차를 다시 실행합니다. `.venv/`는 Git에서 제외되므로 다른 개발자의 커밋이나 배포에 포함되지 않습니다.

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
| `THINQ_PAT`, `THINQ_COUNTRY_CODE`, `THINQ_CLIENT_ID` | ThinQ 조회·제어 | PAT 비공개 |
| `FRONTEND_ORIGIN` | 자동 계정 진입을 허용할 운영 Web Origin | 공개 가능 |

운영값 예시:

```dotenv
FRONTEND_ORIGIN=https://lgdxdoraemi.github.io
```

`FRONTEND_ORIGIN`에는 `/PLM/` 경로가 아니라 Origin만 입력합니다. `.env`를 커밋하지 않고 Coolify Environment Variables에서 비밀값을 관리합니다.

설정 확인 기준:

- Frontend와 Backend의 `SUPABASE_URL`은 같은 프로젝트를 가리켜야 합니다.
- 각 `SUPABASE_ANON_KEY`는 서로 다른 활성 Publishable Key일 수 있지만, 둘 다 같은 Supabase 프로젝트에서 유효해야 합니다.
- `SUPABASE_SERVICE_ROLE_KEY`는 REST 접근에서 401이 나지 않는 현재 활성 Secret/Service Role Key여야 합니다.
- `THINQ_CLIENT_ID`는 UUID, `THINQ_COUNTRY_CODE`는 한국 계정 기준 `KR`입니다.
- 환경변수를 변경한 뒤에는 `get_settings()`와 기기 캐시를 초기화하도록 Backend 프로세스를 재시작합니다.

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

배우자 공개 상태는 `partner_links.shared_at`으로 판정합니다. 아내가 프로필 입력을 모두 마쳐도 이 값은 자동으로 채워지지 않으며, 기존 연결을 다시 공개할 때는 초대 화면의 `초대하기`가 호출하는 `POST /api/v1/account/partner-link/share`에서만 갱신합니다. 남편의 `GET /api/v1/account/bootstrap`은 공개 전에는 `husband_invitation_required`, 공개 후에는 `husband_calendar`를 반환합니다. 새 배우자 연결은 초대 수락이 완료된 뒤 공개 상태로 시작합니다.

`GET /api/v1/thinq/devices`는 ThinQ 진단 시 PAT나 모델 정보 없이 `status`, `device_id`, `name`, `device_type`만 반환합니다. 설정된 아내 계정이 아닌 로그인에는 `account_mismatch`와 빈 기기 목록을 반환합니다. 가사 가이드가 빨래를 가족 항목으로 표시하면 먼저 이 API가 `connected`와 `washer`를 반환하는지 확인합니다.

`GET /api/v1/chat/messages`는 날짜를 생략하면 KST 기준 오늘 대화만 반환합니다. `GET /api/v1/routine/home`은 오늘 컨디션이나 루틴 생성 여부와 무관하게 프로필 주차 안내를 반환합니다.

캘린더는 월 조회와 날짜 상세 조회를 분리합니다. `GET /api/v1/care/calendar/{month}`는 기록 날짜와 상태를 반환하고, `GET /api/v1/care/calendar/days/{target_date}`는 해당 날짜의 컨디션과 저장을 만들지 않는 Daily 리포트 미리보기를 한 응답으로 반환합니다. 기록이 없는 날은 404가 아니라 두 값이 `null`인 200이며, 404는 엔드포인트가 없는 경우만 뜻합니다. 연결된 남편은 배우자 범위로 같은 데이터를 조회합니다.

`GET /api/v1/family/household-requests`는 `?date=YYYY-MM-DD`로 그 날짜의 요청만 조회합니다(생략하면 전체). 목록 응답은 요청 건수와 무관하게 일정한 수의 질의로 만듭니다.

전체 계약은 [API 문서](../docs/api.md)에서 확인합니다.

## 테스트

```powershell
python -m unittest discover -s tests
```

변경 범위가 작으면 관련 모듈을 우선 실행합니다.

```powershell
python -m unittest tests.test_chat tests.test_routine_home tests.test_app
```

## Coolify 배포

Coolify 애플리케이션은 `main` 브랜치 push 웹훅으로 자동 재배포합니다. 다음 설정을 유지합니다.

```text
Branch: main
Dockerfile: backend/Dockerfile
Start Command: python -m app.server
Healthcheck Path: /health
Domain: https://plm-api.dx6project.site
```

`backend/Dockerfile`은 Python 3.13 slim 이미지에 requirements와 MediaPipe/OpenCV가 요구하는 Linux 라이브러리를 설치합니다. `models/pose_landmarker_full.task`는 모션 API 런타임 파일이므로 배포에서 제외하면 안 됩니다.

배포 순서:

1. Coolify Environment Variables를 `backend/.env.example` 기준으로 입력합니다.
2. `FRONTEND_ORIGIN=https://lgdxdoraemi.github.io`를 설정합니다.
3. `plm-api.dx6project.site` 도메인과 HTTPS를 애플리케이션에 연결합니다.
4. 배포 후 `/health`와 `/docs`를 확인합니다.
5. GitHub의 `API_BASE_URL`을 `https://plm-api.dx6project.site`로 설정합니다.
6. Pages 앱에서 등록 계정 진입과 인증 API를 확인합니다.

Coolify에서 `PORT`를 주입하지 않으면 서버는 기본 `8000` 포트를 사용합니다. Start Command는 `python -m app.server`를 유지합니다.

로컬 `.env`는 Coolify에 자동으로 복사되지 않습니다. 특히 로컬 ThinQ 조회는 정상인데 운영의 `/api/v1/thinq/devices`가 `connected`와 빈 목록을 반환하면 Coolify의 `THINQ_PAT`, `THINQ_COUNTRY_CODE`, `THINQ_CLIENT_ID`, `PLM_WIFE_EMAIL`이 로컬과 같은 계정 조합인지 확인한 뒤 재배포합니다. `main`에 코드가 올라간 것과 운영 비밀값이 갱신되는 것은 별개입니다.

## 운영 문제 확인

| 증상 | 확인 항목 |
| --- | --- |
| 401 | Supabase 세션과 access token |
| 403 | 역할 권한, 요청 Origin, `FRONTEND_ORIGIN` |
| 404 | 해당 날짜의 컨디션·루틴·리포트 존재 여부 |
| 409/422 | 선행 입력, 상태 충돌, 요청 본문 |
| 503 DB 오류 | Supabase 연결, 서비스 키, 운영 마이그레이션 |
| 503 Chat/AI 오류 | `LLM_API_KEY`, Base URL, 공급자 응답 |
| 가사 가이드가 빨래를 가족에게 표시 | `/thinq/devices`의 `status`와 `washer` 존재 여부, Coolify ThinQ 환경변수, Backend 재시작 여부 |
| `connected`인데 기기 0대 | PAT가 기기 없는 다른 ThinQ 계정을 가리키는지 확인 |
| 로컬만 정상·운영만 비정상 | Coolify 환경변수와 실행 커밋 확인. 로컬 `.env`는 운영에 자동 반영되지 않음 |
| 시작 실패 | Coolify 빌드 경로, Dockerfile, `PORT`, 런타임 라이브러리 |

더 자세한 초기 설정과 장애 대응은 [guide.md](../guide.md)를 참고합니다.
