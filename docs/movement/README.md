# 모션 인식

PLM의 모션 기능은 카메라 프레임을 분석하는 별도 기술 데모와, 저장된 오늘의 감지 기록을 보여주는 앱 화면으로 나뉩니다.

## 현재 구성

| 위치 | 역할 |
| --- | --- |
| [백엔드 모션 서비스](../../backend/app/services/movement) | 자세 추출, 캘리브레이션, 이벤트 감지·저장, 일일 집계 |
| [모션 API](../../backend/app/api/v1/movement.py) | WebSocket 프레임 수신, 활성 세션·오늘 이벤트·일일 집계 조회 |
| [프론트 모션 화면](../../frontend/lib/features/movement/README.md) | 일반 앱의 기록 조회와 별도 카메라 데모 |
| [DB 마이그레이션](../../supabase/migrations/20260916000000_create_movement_tables.sql) | 캘리브레이션 기준선과 이벤트 저장 |
| [설계 계획](구현계획서_v3.md) | 판정 기준과 데모 제약 |
| [PC 웹캠 도구](../../tools/motion_demo/README.md) | 앱과 분리된 로컬 분석 도구 |

일반 앱은 `GET /api/v1/movement/events`와 `GET /api/v1/movement/report/daily`로 오늘의 기록을 읽습니다. 카메라 분석은 `frontend/lib/main_movement_debug.dart`에서 WebSocket으로 JPEG 프레임을 전송합니다. 동의·수집 설정은 가족 API에서 관리합니다. DB에는 구간형 감지 이벤트가 저장되며 카메라 영상은 저장하지 않습니다.

오늘 기록 초기화는 KST 오늘 `posture_events`만 지웁니다. 캘리브레이션 기준선과 동의 설정은 보존합니다. API 세부 계약은 [api.md](../api.md), 실행과 환경 구성은 [guide.md](../../guide.md)를 참고하세요.
