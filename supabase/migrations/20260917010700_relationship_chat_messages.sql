-- chat_messages: 챗봇 대화 이력 SOURCE (FUC-W-CHAT-001/002, FUC-W-MEAL-003).
-- TARGET_DB_SCHEMA.md 기준 NEW. NFR-027(보관·파기 기준 TBD)이 아직 확정되지
-- 않아 이 migration은 컬럼 구조만 만들고 자동 삭제(pg_cron 등)는 추가하지 않는다 —
-- 보관 기간이 정해지면 별도 migration으로 추가한다.
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  -- routine_items는 Protected 테이블. FK 참조만 하고 스키마는 변경하지 않는다.
  routine_item_id uuid references public.routine_items (id),
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  suggested_actions jsonb,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_user_date_idx
  on public.chat_messages (user_id, date, created_at);

-- 민감정보 경계(NFR-013, NFR-027): 대화 원문은 남편에게 노출하지 않고, Daily
-- 리포트에도 원문을 반영하지 않는다 — 이는 이 테이블을 읽는 쪽(Report/Family
-- 응답 Schema)의 책임이며, 이 테이블 자체는 아내 본인 access만 전제한다.
alter table public.chat_messages enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음.
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
