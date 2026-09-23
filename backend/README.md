# PLM Backend

FastAPI 서버는 PLM의 인증된 생활 기록, AI 루틴, 네 가지 가이드, 챗봇, 가족 공유, 모션 분석과 ThinQ 보유 기기 조회를 제공합니다. Supabase Auth 토큰으로 사용자를 확인하고 PostgreSQL에 날짜별 기록을 저장합니다.

## 주요 동작

- **계정·프로필:** 사용자 진입 분기, 단계별 임산부 프로필 저장, 배우자 연결과 초대. 로컬 및 `FRONTEND_ORIGIN`으로 허용된 운영 Web 앱에 사전 등록 계정 세션 발급과 전환을 제공합니다.
- **오늘 생활 기록:** 컨디션과 예정 활동 저장, 루틴 항목 실행·피드백, Daily 리포트 미리보기·확정, 월별 캘린더 조회.
- **웬즈데이 루틴:** 프로필·오늘 컨디션을 입력으로 식사·가사·건강·수면 항목을 생성하고 날짜별 revision으로 보관합니다. AI 생성 실패 시 서버의 폴백 루틴을 저장할 수 있습니다.
- **건강 운동 영상:** 건강 가이드 조회 시 `health_exercise_videos`의 허리·손목·골반·다리 YouTube 영상을 루틴 부위와 매칭해 반환합니다.
- **가이드·대화:** 저장된 `routine_items`를 카테고리별로 조회합니다. 챗봇은 LLM 응답과 대화 이력을 제공하며, 식사 대체 메뉴는 선택 전까지 루틴을 변경하지 않습니다.
- **가족 공유:** 남편의 오전 리포트·캘린더 조회, 가사 요청의 항목별 확인·완료, 알림과 모션 수집 동의 상태를 처리합니다.
- **모션:** 별도 WebSocket으로 JPEG 프레임을 분석하고 `posture_events`를 기록합니다. 오늘 이벤트와 날짜별 집계 API를 제공합니다.
- **ThinQ:** 서버의 PAT로 보유 가전 목록을 읽고 저장된 가사 루틴 항목과 매칭합니다. PAT는 클라이언트에 전달하지 않으며 실제 기기 제어 API는 호출하지 않습니다.

`POST /api/v1/care/today/reset`은 인증된 아내의 KST 오늘 컨디션, 모든 루틴 revision·항목, 실행·피드백, 가사 요청 항목과 남편 알림, 리포트 및 오늘 모션 감지 기록을 DB 함수 한 번으로 초기화합니다. 프로필, 배우자 연결, 모션 동의와 캘리브레이션 기준선은 유지합니다. 적용 조건과 실행 주의사항은 [guide.md](../guide.md)에 있습니다.

## 코드 구성

| 경로 | 역할 |
| --- | --- |
| `app/api/v1/` | HTTP·WebSocket 라우터와 인증 경계 |
| `app/domains/` | 계정, care, chat, family, guide 계약·서비스·저장소 |
| `app/services/routine/` | AI 루틴 입력, 검색, 생성, 저장 |
| `app/services/movement/` | 자세 추출, 캘리브레이션, 이벤트, 집계 |
| `app/services/thinq/` | ThinQ 기기 조회와 가사 항목 매칭 |
| `app/schemas/` | 모션 요청·응답 스키마 |

요청과 응답 계약은 [docs/api.md](../docs/api.md), 개발 환경과 실행·예외 처리는 [guide.md](../guide.md), DB 변경은 [supabase/README.md](../supabase/README.md)를 참고하세요. 실행 중인 서버의 OpenAPI 문서는 `/docs`에서 확인할 수 있습니다.
