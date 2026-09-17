-- household_requests(+items): 가사 도움 요청 SOURCE (FUC-W-HOUSE-003, FUC-H-REQUEST-001~003).
-- 부모-자식 관계라 한 migration에 묶는다(BACKEND_COLLABORATION.md 2.2 예외).
--
-- 재확인 메모(migration 작성 전 실제 코드와 대조): TARGET_DB_SCHEMA.md 초안은
-- status 값을 구 ERD 초안(삭제됨)의 (requested, confirmed, done)으로 뒀었으나,
-- 실제로 이미 구현된 backend/app/domains/family/schemas.py의
-- HouseholdRequestStatus/HouseholdItemStatus가 (unconfirmed, confirmed, completed)로
-- 정의돼 있어 이 값을 기준으로 정정했다 — 코드가 문서보다 최신 계약이다.
-- 같은 이유로 완료 시각 컬럼명도 done_at이 아니라 completed_at으로, item 단위
-- status 컬럼도 원안에 없었지만 HouseholdRequestItem.status가 실제로 존재해 추가했다.
create table if not exists public.household_requests (
  id uuid primary key default gen_random_uuid(),
  wife_user_id uuid not null references auth.users (id) on delete cascade,
  husband_user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  reason_text text,
  status text not null default 'unconfirmed'
    check (status in ('unconfirmed', 'confirmed', 'completed')),
  requested_at timestamptz not null default now(),
  confirmed_at timestamptz,
  completed_at timestamptz
);

create index if not exists household_requests_husband_status_idx
  on public.household_requests (husband_user_id, status);
create index if not exists household_requests_wife_date_idx
  on public.household_requests (wife_user_id, date);

-- wife_user_id/husband_user_id 조합이 실제 partner_links에 존재하는지는 Postgres
-- CHECK 제약으로 강제할 수 없다(서브쿼리 불가) — Service 계층이 반드시 partner_links를
-- 먼저 조회해 확인한 뒤에만 이 테이블에 행을 만들어야 한다(family relationship 전제).
alter table public.household_requests enable row level security;

create table if not exists public.household_request_items (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.household_requests (id) on delete cascade,
  -- routine_items는 Protected 테이블이다. 여기서는 FK로 "참조"만 하며 routine_items
  -- 자체의 스키마는 절대 변경하지 않는다(BACKEND_COLLABORATION.md 2.4 — 참조만 하는
  -- 쪽은 단독 작업 가능, 참조 대상 테이블 변경만 승인 필요).
  routine_item_id uuid references public.routine_items (id),
  title text not null,
  helper_info text,
  status text not null default 'unconfirmed'
    check (status in ('unconfirmed', 'confirmed', 'completed'))
);

create index if not exists household_request_items_request_id_idx
  on public.household_request_items (request_id);

alter table public.household_request_items enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음(아내가 쓰고 남편이 상태를 갱신하는
-- 양방향 공유 테이블이지만, "남편 본인 요청만 확인/완료 가능"한 권한 검증은 FastAPI가
-- partner_links·request 소유자 대조로 수행한다 — DB 정책으로 열지 않는다).
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
