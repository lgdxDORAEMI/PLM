-- profiles: 사용자 역할(wife/husband)과 표시 이름의 유일한 SOURCE (FUC-B-ENTRY-001).
-- TARGET_DB_SCHEMA.md 기준 NEW. account 도메인의 bootstrap 판정이 지금은 Stub 메모리로
-- role="wife" 고정값을 쓰고 있는데(DOMAIN_OWNERSHIP.md 기존 TBD), 이 테이블이 그 대체 SOURCE다.
-- account/schemas.py의 UserRole(wife/husband)과 값이 일치해야 한다.
create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('wife', 'husband')),
  display_name text,
  created_at timestamptz not null default now()
);

-- 접근은 인증을 검증한 backend(service role)만 한다 (기존 컨벤션과 동일).
-- RLS를 켜고 정책을 두지 않아 anon/authenticated 키로의 직접 접근은 전부 차단된다.
-- auth.uid() 기반 정책을 일부러 추가하지 않는다 — 그런 정책은 FastAPI가 수행하는
-- 프로필 완료 상태·역할 판정 로직을 우회해 Frontend가 이 테이블에 직접 붙을 길을
--열어주기 때문이다(이번 STEP 요구사항: "service_role만 믿고 Frontend 접근권한을
-- 열어두지 않는다" — 실제로는 그 반대인 "우회 가능한 정책을 만들지 않는다"는 의미로
-- 해석해 기존 컨벤션을 그대로 따랐다).
alter table public.profiles enable row level security;

-- Grant: 20260917000002_grant_service_role.sql이 이미
-- `alter default privileges in schema public grant all on tables to service_role`를
-- 적용해 뒀으므로, 이 테이블도 생성 즉시 service_role에 자동으로 권한이 부여된다.
-- 별도 grant 문을 추가하지 않는다(중복 방지).
