# Supabase

Supabase는 Auth, PostgreSQL Database, Storage를 담당할 예정입니다.

## 모션 인식 기능 테이블 설계 (2026-09-14 설계, 2026-09-16 마이그레이션 적용 완료)

`backend/app/schemas/movement.py`에 정의된 `PostureEvent`, `CalibrationProfileSchema`를 그대로 옮긴
테이블 컬럼안입니다. 실제 `.sql` 마이그레이션은
[supabase/migrations/20260916000000_create_movement_tables.sql](migrations/20260916000000_create_movement_tables.sql)에
있고, `mekqbjztmsbebtqybtuc` 프로젝트(프로필 기능과 같은 프로젝트로 통합)에 적용 완료했습니다.
`SupabaseEventStore`/`SupabaseCalibrationStore`(`backend/app/services/movement/{events,calibration}.py`)가
이 테이블을 사용하는 `EventStore`/`CalibrationStore` 구현체입니다. 아래 표는 그 마이그레이션이 실제로
적용한 컬럼과 동일합니다.

일일 리포트용 별도 테이블은 만들지 않습니다. `posture_events`가 쌓이면 조회 시점에 즉석 집계하는 것으로
충분하고, 아직 쓰이지도 않을 집계 테이블을 미리 만들 이유가 없기 때문입니다.

### `posture_calibration_profiles`

| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | `uuid`, PK, `default gen_random_uuid()` | |
| `user_id` | `uuid`, FK → `auth.users(id)`, not null | 2026-09-16부터 `get_current_user`로 확인한 실제 로그인 사용자 id (`DEMO_USER_ID` 고정값은 제거됨) |
| `baseline_trunk_flexion` | `double precision`, not null | |
| `baseline_knee_angle` | `double precision`, not null | |
| `frame_count` | `integer`, not null | |
| `captured_at` | `timestamptz`, not null | 캘리브레이션 측정 완료 시각 |
| `created_at` | `timestamptz`, not null, `default now()` | 행 생성 시각 |

한 사용자가 재캘리브레이션(§2.3)을 여러 번 할 수 있으므로 `user_id`에 유니크 제약을 걸지 않고,
"가장 최근 행"을 현재 기준선으로 사용하는 쪽을 권장합니다.

### `posture_events`

| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | `uuid`, PK, `default gen_random_uuid()` | `PostureEvent.event_id` |
| `user_id` | `uuid`, FK → `auth.users(id)`, not null | |
| `session_id` | `uuid`, not null | 캘리브레이션~종료까지 한 실행 세션 단위 |
| `posture_type` | `text`, not null | `PostureType` enum 값 그대로 저장 (`"Standing"` 등) |
| `burden_label` | `text`, not null | `BurdenLabel` enum 값 그대로 저장 (`"Prolonged Load"` 등) |
| `started_at` | `timestamptz`, not null | |
| `ended_at` | `timestamptz`, not null | |
| `duration_sec` | `double precision`, not null | |
| `trigger_reason` | `text`, not null | `EventTrigger` enum 값 (`state_duration` / `repeated_count` / `cumulative_research_threshold` / `sit_to_stand`) |
| `rep_count_in_window` | `integer`, nullable | |
| `cumulative_bend_sec` | `double precision`, nullable | |
| `created_at` | `timestamptz`, not null, `default now()` | |

`posture_type`/`burden_label`/`trigger_reason`은 Postgres enum 타입이 아니라 **`text` + 값 검증(앱단 또는
`CHECK` 제약)**으로 둘 것을 권장합니다. 임계값·라벨 체계가 아직 튜닝 중이라(§7, §8) 값이 추가/변경될 수 있는데,
Postgres enum은 값 추가마다 `ALTER TYPE`이 필요해 잦은 변경에 불리합니다.

권장 인덱스: `(user_id, started_at)` — 일일 리포트가 "특정 user_id, 특정 날짜 범위" 조회 위주이기 때문입니다.

**저장 정책 — "위험한 순간만 저장" (2026-09-16 결정)**: 이 테이블에는 부담 라벨이 실제로 `Normal`을 넘어선 구간만 들어옵니다. `burden_label=Normal`인 행은 존재하지 않습니다 — `SessionManager`가 이벤트를 여닫는 시점에 이미 걸러내고 있고(`_track_open_event`), 유일한 예외였던 누적 전방굴곡 기록(`trigger_reason=cumulative_research_threshold`)도 연구 기반 위험 임계값을 실제로 넘긴 세션만 기록하도록 통일했습니다(`_record_cumulative_bend`, `backend/app/schemas/movement.py` 참고). 즉 이 테이블에 행이 있다는 것 자체가 "위험 순간이 감지됐다"는 뜻이며, 별도의 `is_dangerous` 플래그 컬럼은 두지 않습니다.

### RLS 정책 방향

두 테이블 모두 RLS를 켜고, `auth.uid() = user_id`인 행만 select/insert 가능하도록 제한합니다.
서비스 역할 키(`SUPABASE_SERVICE_ROLE_KEY`)를 쓰는 백엔드 배치 작업(예: 향후 야간 리포트 스케줄러)만
이 제약을 우회할 필요가 있으면 그때 별도 정책을 추가합니다.

관련 문서: [모션 인식 스키마](../backend/app/schemas/README.md), [구현계획서 v3](../docs/movement/구현계획서_v3.md)
