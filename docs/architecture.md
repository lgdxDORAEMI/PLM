# Architecture

Flutter Web은 UI와 공개 환경 설정을 담당합니다. FastAPI는 API 및 서버 전용 외부 서비스 연동을 담당합니다.
Supabase는 Auth, PostgreSQL Database, Storage를 담당할 예정입니다.
MediaPipe 분석 모듈은 `backend/app/services/movement/`에 배치되어 있습니다.
PC 웹캠 검증은 `tools/motion_demo/`의 독립 도구를 사용하며 제품 API와 Flutter 화면에는 아직 연결하지 않았습니다.
외부 LLM 호출은 backend services에 구현할 예정입니다.
원본 파일 이동 및 테스트 방법은 [모션 통합 문서](movement/README.md)에 있습니다.

Frontend는 `BACKEND_URL`을 통해 FastAPI에 접근합니다. 현재 HTTP 요청 기능은 구현하지 않았습니다.
Supabase 공개 설정이 모두 입력된 경우 앱 시작 시 Flutter client를 초기화합니다.
서버 client는 `get_supabase_service()`를 통해 가져오고, 실제 접근 시 지연 생성됩니다.
라우터와 다른 서비스에서는 Supabase client를 직접 생성하지 않습니다.
서버 service role client는 RLS를 우회하므로 기능 라우터에 사용하기 전에 인증과 권한 검증을 구현해야 합니다.

Backend의 설정은 `get_settings()`로 가져오는 `Settings` 객체에 모읍니다.
환경 파일 위치는 프로젝트 파일 기준으로 계산하며 특정 PC의 절대경로에 의존하지 않습니다.
LLM 공급업체 구현은 `LLMService`를 상속하고 `generate()`를 구현합니다.
현재 공급업체 SDK, DB schema, 상태관리 라이브러리는 선택하지 않았습니다.

CORS는 `http://localhost`와 `http://127.0.0.1`의 개발 포트만 허용합니다.
운영 배포 시 허용 origin과 인증 정책을 별도로 구성해야 합니다.
