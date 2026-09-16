-- 모션 인식 기능(임산부 부담 자세 감지) DB 계약. 컬럼 설계는 supabase/README.md,
-- backend/app/schemas/movement.py에서 확정된 것을 그대로 옮긴 것이다.
-- 접근은 인증을 검증한 backend(service role)만 한다 (pregnancy_profiles와 동일 컨벤션).
-- 정책을 두지 않아 anon/authenticated 키로의 직접 접근은 모두 차단된다.

-- posture_calibration_profiles: 개인 자세 기준선(baseline). 재캘리브레이션을 여러 번
-- 할 수 있으므로 user_id에 unique를 두지 않고, 가장 최근 행을 현재 기준선으로 쓴다.
create table if not exists public.posture_calibration_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  baseline_trunk_flexion double precision not null,
  baseline_knee_angle double precision not null,
  frame_count integer not null,
  captured_at timestamptz not null,

  created_at timestamptz not null default now()
);

alter table public.posture_calibration_profiles enable row level security;

-- posture_events: 부담 라벨이 실제로 Normal을 넘어선 구간·순간 이벤트만 저장한다
-- ("위험한 순간만 저장" 원칙, 2026-09-16 결정). burden_label='Normal'인 행은 없다.
-- posture_type/burden_label/trigger_reason은 Postgres enum이 아니라 text + check로
-- 둔다 — 임계값·라벨 체계가 튜닝 중이라 값이 추가/변경될 수 있기 때문이다.
create table if not exists public.posture_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_id uuid not null,

  posture_type text not null
    check (posture_type in ('Standing', 'Bending', 'Sitting', 'Unknown')),
  burden_label text not null
    check (burden_label in ('Normal', 'Repeated Load', 'Prolonged Load', 'High-load Action')),
  trigger_reason text not null
    check (trigger_reason in (
      'state_duration', 'repeated_count', 'cumulative_research_threshold', 'sit_to_stand'
    )),

  started_at timestamptz not null,
  ended_at timestamptz not null,
  duration_sec double precision not null,
  rep_count_in_window integer,
  cumulative_bend_sec double precision,

  created_at timestamptz not null default now()
);

-- 일일 리포트가 "특정 user_id, 특정 날짜 범위" 조회 위주라 이 인덱스가 필요하다.
create index if not exists posture_events_user_started_idx
  on public.posture_events (user_id, started_at);

alter table public.posture_events enable row level security;
