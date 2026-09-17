-- recommendation_feedback: 메뉴 수락/거절/재요청, 수면 환경 override 이력 SOURCE
-- (FUC-W-MEAL-004, FUC-W-SLEEP-001-1). kind로 도메인을 구분해 한 테이블로 통합한다
-- (DATA_OWNERSHIP.md Duplicate Storage 항목 7 — 도메인별 별도 이력 테이블 금지).
create table if not exists public.recommendation_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- routine_items는 Protected 테이블. FK 참조만 하고 스키마는 변경하지 않는다.
  routine_item_id uuid not null references public.routine_items (id) on delete cascade,
  kind text not null
    check (kind in ('meal_accept', 'meal_reject', 'meal_replace', 'sleep_env_override')),
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists recommendation_feedback_user_created_idx
  on public.recommendation_feedback (user_id, created_at desc);

alter table public.recommendation_feedback enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음.
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
