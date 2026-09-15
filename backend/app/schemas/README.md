# Schemas

요청/응답 및 DB 계약용 Pydantic 스키마를 모아두는 폴더입니다.

## movement.py (2026-09-14 추가)

모션 인식 기능(임산부 부담 자세 감지·알림)의 API/DB 계약 스키마입니다.
실제 API 라우터, WebSocket 엔드포인트, DB 테이블은 아직 없는 상태에서,
프론트/DB/리포트 담당자가 먼저 참고해서 병렬로 작업을 시작할 수 있도록
필드 모양만 먼저 정의해뒀습니다. 판정 로직 자체는 이 파일에 없으며
`backend/app/services/movement/rule_engine.py` 등에 그대로 있습니다.

**포함된 타입**

- `PostureType`, `BurdenLabel`, `EventTrigger`: `rule_engine.py`의 문자열 상수(`"Standing"`, `"Prolonged Load"` 등)와 값이 동일한 Enum. 나중에 판정 결과를 API로 내보낼 때 별도 변환 코드가 필요 없습니다.
- `BodyPart`, `resolve_body_part()`: 일일 리포트의 "최다 부담 부위" 집계용(허리·몸통 / 무릎 / 전신). `posture_type`만으로는 Sit-to-Stand 이벤트를 오분류하므로 `trigger_reason`도 함께 보는 함수로 뒀습니다.
- `PostureFrameState`: 카메라 프레임마다의 "지금 이 순간" 상태(골격 33개 landmark 좌표 포함). DB에 저장하지 않고, **데모 시연용 실시간 오버레이 표시로만** 씁니다.
- `PostureTypeTally`, `LiveAccumulatedState`: **"실시간 탭" 조회 응답**(W-MOTION-001). 조회 시점까지 세션에 누적된 상태를 돌려주는 풀(pull) 방식이며, 임계 이벤트 발생 시 앱이 먼저 알림을 띄우는 푸시 방식은 채택하지 않았습니다 (2026-09-15 팀 결정, 아래 참고).
- `PostureEvent`: 라벨이 Repeated Load 이상으로 올라갔다가 내려오는 구간, 또는 Sit-to-Stand 같은 순간 이벤트를 하나씩 기록하는 저장 단위입니다. DB 저장 및 일일 리포트 집계에 씁니다. `PostureFrameState`와의 차이는 [설계 논의 기록](../../../docs/movement/구현계획서_v3.md) 참고. `trigger_reason=cumulative_research_threshold`인 이벤트는 세션 종료 시 딱 한 번만 기록되는 "그 세션 누적 굴곡 시간" 요약이라 다른 이벤트와 성격이 다릅니다(아래 참고).
- `CalibrationProfileSchema`: `calibration.py`의 `CalibrationProfile`에 `user_id`만 추가한 버전.
- `PostureAggregate`, `DailyReportSummary`: 일일 리포트 조회 API 응답 형태(§5.9). `top_burdened_body_part`로 W-REPORT-002의 "최다 부담 관절"을 표현합니다. `cumulative_forward_bend_sec`(2026-09-15 추가)는 `cumulative_research_threshold` 이벤트만 따로 합산한 값이며, `aggregates`/`top_burdened_body_part`에는 안 섞입니다.

**설계 결정 (확정, 이후 코드 작성 시 이 전제로 진행)**

- 이벤트는 프레임별 스냅샷이 아니라 **구간형**(시작~종료)으로 저장한다.
- 시각은 세션 상대초가 아니라 **절대 UTC datetime**(`started_at`/`ended_at`)으로 저장한다.
- 실시간 상태(`PostureFrameState`)에는 골격 오버레이를 그릴 수 있도록 **33개 landmark 좌표를 포함**한다.
- Supabase 인증이 붙기 전까지 `user_id`는 파일 상단의 **`DEMO_USER_ID` 고정값**을 쓴다. 인증 연동 시 각 호출부의 값만 실제 user_id로 교체하고 이 상수는 제거할 것.

**설계 결정 (2026-09-15 팀 논의, `docs/requirements/` 정합성 점검 반영)**

- 모션 모듈은 계속 진행 (Phase 2 아님, 우선순위 상~중으로 합의).
- **푸시 알림은 만들지 않는다.** W-MOTION-001("실시간 탭에서 누적된 최신 결과 조회")과 UC13("다음날
  루틴 반영, 즉각 개입 없음")을 근거로, 실시간 기능은 풀 방식(`LiveAccumulatedState`)으로만 제공한다.
- Flutter Web 브라우저 카메라 연동은 **데모 전용**이다. 시연 때 모니터로 모션 인식 동작을 보여주기
  위한 것이며, 실제 서비스 전환 시 프라이버시 이슈를 감안해 재검토한다는 것을 문서에 명시한다
  (`구현계획서_v3.md` §4 참고).
- "휴식 부족" 감지(W-MOTION-001의 4항목 중 하나)는 이번 범위에서 **제외**한다.
- 리포트는 관절 좌우 구분 없이 **부위(허리·몸통 / 무릎) 단위**로 집계한다 (`resolve_body_part()`).
- NFR-008/011/012/014(암호화, 영상 보관기한, 동의 철회, 최소 데이터 전달)는 **지금은 코드 주석으로만
  남기고**, 실제 구현은 마이그레이션 작성 시점으로 미룬다.
- **누적 전방굴곡 위험(§2.5)은 실시간 라벨에 영향을 주지 않는다 (2026-09-15 재결정)**. 원래 실시간
  라벨을 강제로 격상시키던 코드가 있었는데, 실기기 데모 중 "Standing이 계속 Prolonged Load로 뜨는"
  증상으로 발견됐다. 원래 의도가 리포트용 사실 안내였던 것과 실시간 판정이 섞여 있었던 것 — 지금은
  세션 종료 시 `trigger_reason=cumulative_research_threshold` 이벤트 하나로만 남고,
  `DailyReportSummary.cumulative_forward_bend_sec`로만 노출된다.

**다음에 이 스키마를 쓰게 될 곳**

- `backend/app/api/v1/movement.py` — 라우터 + `WS /live/stream` 작성 완료(B-1/B-3, 2026-09-15). `/live`·`/events`·`/report/daily` 전부 실제 값을 반환한다(목업 없음)
- `supabase/migrations/` — 컬럼 설계는 [supabase/README.md](../../../supabase/README.md)에 문서화 완료, 실제 `.sql` 마이그레이션은 인증 연동 시점에 작성 예정
- `backend/app/services/movement/events.py` — `EventStore` 저장소 작성 완료(`InMemoryEventStore`), `WS /live/stream`이 실제로 기록
- `backend/app/services/movement/session_manager.py` — `SessionManager` 작성 완료(B-2, 2026-09-15), `WS /live/stream`이 실제로 호출한다
- `backend/app/services/movement/calibration.py` — `CalibrationStore`(`LocalFileCalibrationStore`) + `CalibrationCollector`(비동기 프레임 스트림용 누산기, B-1/B-3) 작성 완료
- `backend/app/services/movement/report.py` — `PostureAggregate`/`DailyReportSummary` 생성 로직 작성 완료(2026-09-15). `top_burdened_body_part`는 `count × 라벨 심각도`로 계산(지속시간 합이면 항상 `duration_sec=0`인 Sit-to-Stand가 1위가 될 수 없어서)

관련 문서: [구현계획서 v3](../../../docs/movement/구현계획서_v3.md) (§2.4~§2.7 판정 로직 근거), [모션 통합 문서](../../../docs/movement/README.md) (분석 모듈 배치 현황)
