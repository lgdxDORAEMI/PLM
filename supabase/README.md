# Supabase

Supabase는 Auth, PostgreSQL Database, Storage를 담당할 예정입니다.

## 모션 인식 기능 테이블 설계 (2026-09-14, 설계 문서 — 실제 마이그레이션 아직 없음)

`backend/app/schemas/movement.py`에 정의된 `PostureEvent`, `CalibrationProfileSchema`를 그대로 옮긴
테이블 컬럼안입니다. Supabase 프로젝트에 인증 연동이 안 됐고, 프로젝트 전체의 공통 컨벤션(예: `updated_at`
트리거, soft delete 여부)도 아직 안 정해져 있어 지금은 `.sql` 마이그레이션을 만들지 않고 설계만 문서화합니다.
실제 연동 시점에 이 표를 그대로 첫 마이그레이션으로 옮기면 됩니다.

일일 리포트용 별도 테이블은 만들지 않습니다. `posture_events`가 쌓이면 조회 시점에 즉석 집계하는 것으로
충분하고, 아직 쓰이지도 않을 집계 테이블을 미리 만들 이유가 없기 때문입니다.

### `posture_calibration_profiles`

| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | `uuid`, PK, `default gen_random_uuid()` | |
| `user_id` | `uuid`, FK → `auth.users(id)`, not null | Supabase Auth 연동 전까지는 `schemas/movement.py`의 `DEMO_USER_ID` 고정값을 씀 |
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

### RLS 정책 방향

두 테이블 모두 RLS를 켜고, `auth.uid() = user_id`인 행만 select/insert 가능하도록 제한합니다.
서비스 역할 키(`SUPABASE_SERVICE_ROLE_KEY`)를 쓰는 백엔드 배치 작업(예: 향후 야간 리포트 스케줄러)만
이 제약을 우회할 필요가 있으면 그때 별도 정책을 추가합니다.

관련 문서: [모션 인식 스키마](../backend/app/schemas/README.md), [구현계획서 v3](../docs/movement/구현계획서_v3.md)
