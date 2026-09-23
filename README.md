# PLM — Pregnancy Life Mode

PLM은 임산부의 오늘 컨디션과 예정 활동을 바탕으로 식사·가사·건강·수면 루틴을 만들고, 실행 기록을 가족과 함께 확인하는 Flutter Web 앱입니다. FastAPI가 인증, 루틴, 가이드, 대화, 리포트와 가족 공유 API를 제공하며 Supabase가 계정과 생활 기록을 저장합니다.

## 주요 흐름

1. 아내 계정으로 진입해 프로필과 출산 예정일을 등록합니다.
2. 오늘 컨디션과 할 일을 입력하고 가족 초대 화면을 거쳐 AI 루틴을 생성합니다.
3. 홈의 네 가지 가이드에서 같은 날짜의 루틴 항목을 확인하고 실행 상태를 기록합니다.
4. Daily 리포트와 캘린더에서 결과를 확인합니다. 연결된 남편은 공유 리포트, 알림, 가사 요청을 조회합니다.

챗봇은 백엔드 LLM과 대화 이력을 사용합니다. 식사 가이드의 다른 메뉴 보기는 대체 카드 1개를 요청하고, 선택 시 루틴 항목을 갱신합니다. ThinQ 연동은 보유 기기를 읽어 가사 가이드와 매칭합니다. 화면의 가전 실행 기록은 실제 기기 제어가 아닙니다.

모션 감지 API와 별도 카메라 데모가 있으며, 일반 앱의 실시간 화면은 저장된 오늘 감지 기록을 조회합니다.

## 구성

| 경로 | 역할 |
| --- | --- |
| [frontend](frontend/README.md) | Flutter Web 앱 |
| [backend](backend/README.md) | FastAPI, AI, ThinQ 조회, 모션 분석 |
| [supabase](supabase/README.md) | DB 마이그레이션과 접근 정책 |
| [docs](docs/README.md) | API, 요구사항, 흐름도, 연동 현황 |
| [tools](tools/rag_ingest/README.md) | 지식 데이터 적재 및 모션 개발 도구 |

실행 방법, 환경변수, DB 적용 순서와 문제 해결은 [guide.md](guide.md)에 있습니다. 현재 서버의 엔드포인트는 [API 문서](docs/api.md)와 실행 중인 `/docs`에서 확인할 수 있습니다. 화면별 연동 상태는 [FE–BE 연결 기록](docs/FE_BE_CONNECTION_STATUS.md)을 참고하세요.

## 현재 범위

- 실제 데이터 경로는 Supabase Auth와 FastAPI API를 사용합니다. 명시적 화면 미리보기는 로컬 예시를 사용합니다.
- 루틴 생성은 AI 응답을 우선하고 실패 시 백엔드 폴백 루틴을 저장할 수 있습니다.
- 사전 등록된 아내·남편 계정의 자동 로그인과 계정 전환은 로컬 실행 환경에 한정됩니다.
- ThinQ 보유 기기 조회와 가사 매칭은 읽기 전용입니다. 가전 제어 기능은 포함되지 않습니다.
- 모션 카메라 분석은 별도 진입점에서 실행합니다. 일반 앱의 실시간 화면은 기록 조회 중심입니다.

## 배포 구성

운영 환경은 `frontend/`의 Flutter Web을 GitHub Pages에, `backend/`의 FastAPI를 Render Web Service에 배포합니다. Pages 빌드는 Repository Variable `API_BASE_URL`로 Render 주소를 받아 사용하며, 서버 비밀값은 Backend의 Render Environment에만 저장합니다. 실제 생성 순서와 환경변수 목록은 [배포 안내](guide.md#render와-github-pages-배포)를 참고하세요.
