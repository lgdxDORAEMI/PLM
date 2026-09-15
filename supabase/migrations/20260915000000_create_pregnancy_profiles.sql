-- W-PROFILE-001 임산부 프로필 (화면설계서: 프로필 설정 1~6단계). 사용자당 1행.
-- 단계마다 저장하므로 아직 입력하지 않은 단계의 컬럼은 null이다. 3~6단계는 컬럼을 추가하는 migration으로 확장한다.
-- 값 범위는 backend/app/schemas/profile.py 검증과 동일하게 유지한다.
-- 임신 주수·완료 단계는 날짜와 입력 상태에 따라 달라지므로 저장하지 않고 조회 시 계산한다.
create table if not exists public.pregnancy_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,

  -- 1/6 출산예정일. 마지막 생리 시작일로 입력하면 +280일로 계산해 함께 저장한다.
  due_date date not null,
  last_period_start date,

  -- 2/6 임신 전 신장·체중. 두 값은 함께 저장한다.
  height_cm numeric(4, 1) check (height_cm between 100 and 250),
  pre_pregnancy_weight_kg numeric(4, 1) check (pre_pregnancy_weight_kg between 30 and 200),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint pregnancy_profiles_last_period_matches_due
    check (last_period_start is null or due_date = last_period_start + 280),
  constraint pregnancy_profiles_body_together
    check ((height_cm is null) = (pre_pregnancy_weight_kg is null))
);

-- 접근은 인증을 검증한 backend(service role)만 한다.
-- 정책을 두지 않아 anon/authenticated 키로의 직접 접근은 모두 차단된다.
alter table public.pregnancy_profiles enable row level security;
