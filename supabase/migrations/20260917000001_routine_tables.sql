-- AI 하루 루틴 생성(W-ROUTINE-001/003)에 필요한 테이블. 설계: docs/DB_ERD_스키마.md §3.2, docs/ai_routine/AI_루틴_파이프라인.md
-- 컨벤션(pregnancy_profiles와 동일): enum은 text + check, 접근은 backend(service role)만 → RLS 켜고 정책 없음.
-- 값 범위는 backend/app/schemas/*.py 검증과 같게 유지한다.

-- 1) 프로필 3~6단계 (W-PROFILE-003~006). frontend ProfileDraft 필드와 1:1.
alter table public.pregnancy_profiles
  add column if not exists is_first_pregnancy    boolean,
  add column if not exists is_multiple_pregnancy boolean,
  add column if not exists allergies             text[] not null default '{}',
  add column if not exists medical_conditions    text[] not null default '{}',
  add column if not exists medical_note          text;

-- 2) 당일 컨디션 + 예정 활동 (W-COND-001, W-TASK-001). 사용자·날짜당 1행, 재입력은 덮어쓰기.
create table if not exists public.daily_conditions (
  user_id            uuid not null references auth.users (id) on delete cascade,
  date               date not null,
  nausea             smallint not null check (nausea between 1 and 5),
  waist_pain         smallint not null check (waist_pain between 1 and 5),
  pelvis_pain        smallint not null check (pelvis_pain between 1 and 5),
  leg_pain           smallint not null check (leg_pain between 1 and 5),
  wrist_pain         smallint not null check (wrist_pain between 1 and 5),
  fatigue            smallint not null check (fatigue between 1 and 5),
  mood               smallint not null check (mood between 1 and 5),
  sleep_quality      smallint check (sleep_quality between 1 and 5),  -- 척도 미확정(04_3 #2), null 허용
  planned_activities text[] not null default '{}',                    -- 9종 코드 + 직접 입력
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  primary key (user_id, date)
);
alter table public.daily_conditions enable row level security;

-- 3) 하루 루틴 원본 응답 (W-ROUTINE-001/003). (user, date) 1행 덮어쓰기. source로 폴백률(NFR-016) 측정.
create table if not exists public.daily_routines (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  date            date not null,
  source          text not null check (source in ('ai', 'fallback_prev', 'fallback_template')),
  model           text,
  prompt_version  text,
  request_payload jsonb,   -- AI에 보낸 최소 항목 기록 (NFR-014 감사용)
  response        jsonb,   -- 4종 가이드 원본
  error_message   text,
  generated_at    timestamptz not null default now(),
  unique (user_id, date)
);
alter table public.daily_routines enable row level security;

-- 4) 루틴 항목 (홈 4종 카드, W-RECORD-001/002). payload 모양은 ERD §3.2 카테고리별 정의.
create table if not exists public.routine_items (
  id           uuid primary key default gen_random_uuid(),
  routine_id   uuid not null references public.daily_routines (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  date         date not null,
  category     text not null check (category in ('meal', 'household', 'health', 'sleep')),
  item_key     text not null,   -- 예: meal:lunch, household:laundry
  title        text not null,
  description  text,
  payload      jsonb not null default '{}',
  source_ids   bigint[] not null default '{}',  -- pregnancy_knowledge.id (RAG 근거)
  status       text not null default 'scheduled' check (status in ('scheduled', 'completed', 'skipped')),
  completed_by text check (completed_by in ('wife', 'husband', 'appliance')),
  completed_at timestamptz,
  sort_order   smallint not null default 0
);
create index if not exists routine_items_user_date_idx on public.routine_items (user_id, date);
alter table public.routine_items enable row level security;
