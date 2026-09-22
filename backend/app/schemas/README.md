# 백엔드 스키마

이 폴더의 `movement.py`는 모션 WebSocket 메시지와 REST 응답에 쓰는 Pydantic 모델을 정의합니다. 계정·컨디션·챗·가족·가이드 스키마는 각 도메인의 `app/domains/*/schemas.py`에 있습니다.

## 모션 모델

- `PostureFrameState`: 프레임별 자세·부담 상태와 화면 오버레이용 좌표. 프레임은 DB에 저장하지 않습니다.
- `LiveAccumulatedState`: 활성 세션 누적 상태 조회 응답.
- `PostureEvent`: 감지 구간과 발생 원인을 담는 DB 저장 단위. `posture_events`와 연결됩니다.
- `CalibrationProfileSchema`: 사용자별 자세 기준선.
- `DailyReportSummary`, `PostureAggregate`: 날짜별 이벤트 집계 응답.

실제 라우터는 [movement.py](../api/v1/movement.py), 분석과 저장 구현은 [movement 서비스](../services/movement), 공개 API 계약은 [docs/api.md](../../../docs/api.md)에 있습니다. 모델 설계 배경은 [모션 구현계획서](../../../docs/movement/구현계획서_v3.md)를 참고하세요.
