-- daily_reports: 확정된 Daily/오전 리포트 집계 SOURCE (FUC-W-REPORT-001/001-1/002,
-- FUC-H-REPORT-001). TARGET_DB_SCHEMA.md 기준 NEW.
create table if not exists public.daily_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  kind text not null check (kind in ('morning', 'daily')),
  content jsonb not null,
  shared_at timestamptz,
  created_at timestamptz not null default now(),

  -- NFR-028: "Daily 리포트는 날짜당 1개만 존재"를 kind별로 확장 적용한다
  -- (morning/daily 각각 날짜당 1개, 동일 날짜 재확정은 upsert로 덮어쓴다).
  unique (user_id, date, kind)
);

create index if not exists daily_reports_user_date_idx
  on public.daily_reports (user_id, date);

-- 민감정보 경계(NFR-013): content에는 남편 공유 허용 범위를 벗어나는 원본
-- (컨디션 점수 원본, AI 대화 원문 등)을 담지 않는다 — Service 계층 책임이며
-- 이 컬럼 자체는 jsonb라 DB가 필드 단위로 강제할 수 없다.
alter table public.daily_reports enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음. 남편이 이 테이블을 읽는 경로도
-- FastAPI가 partner_links로 연동을 확인하고 kind=morning 등 허용 범위만 가공해
-- 응답한다 — 남편에게 이 테이블 직접 조회 정책을 열지 않는다.
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
