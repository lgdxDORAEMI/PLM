-- partner_links: 아내-남편 연동 상태 SOURCE. 이번 STEP이 요구하는 "아내/남편 데이터
-- 공유는 family relationship이 확인된 경우에만 가능"의 근거 테이블이다 — 남편 공유
-- 화면(B-CAL-001, B-MOTION-001 조회, H-REPORT-001, H-NOTI-001, H-REQUEST-001 등)은
-- 전부 Service 계층에서 이 테이블에 연동 여부를 먼저 확인한 뒤에만 아내 데이터를
-- 읽도록 구현해야 한다(이 migration은 그 전제가 되는 테이블만 만든다 — Service 로직은
-- 이번 STEP 범위 밖).
create table if not exists public.partner_links (
  wife_user_id uuid primary key references auth.users (id) on delete cascade,
  husband_user_id uuid not null unique references auth.users (id) on delete cascade,
  linked_at timestamptz not null default now()
);

-- PK(wife_user_id) + unique(husband_user_id)로 1:1 관계를 DB 레벨에서 강제한다.
-- 한 아내가 여러 남편과, 한 남편이 여러 아내와 동시에 연동될 수 없다
-- (BACKEND_ARCHITECTURE.md §2 "중복 연동 불가"와 일치).
alter table public.partner_links enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음.
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
