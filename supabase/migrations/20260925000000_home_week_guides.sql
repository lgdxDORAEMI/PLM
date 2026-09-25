-- W-HOME-001: 웬즈데이가 RAG 근거로 만든 홈 주차 안내를 사용자별·KST 날짜별 1건 유지한다.
-- 클라이언트 직접 접근은 허용하지 않고 Backend service role만 사용한다.
create table if not exists public.home_week_guides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  guide_date date not null,
  pregnancy_week smallint not null check (pregnancy_week between 0 and 42),
  week_notes jsonb not null check (
    jsonb_typeof(week_notes) = 'array' and jsonb_array_length(week_notes) = 2
  ),
  caution text not null check (length(trim(caution)) > 0),
  source text not null check (source in ('rag', 'fallback')),
  source_ids bigint[] not null default '{}',
  sources jsonb not null default '[]'::jsonb check (jsonb_typeof(sources) = 'array'),
  model text null,
  prompt_version text not null,
  generated_at timestamptz not null default now(),
  unique (user_id, guide_date)
);

create index if not exists home_week_guides_user_date_idx
on public.home_week_guides (user_id, guide_date desc);

alter table public.home_week_guides enable row level security;

revoke all on table public.home_week_guides from public, anon, authenticated;
grant all on table public.home_week_guides to service_role;
