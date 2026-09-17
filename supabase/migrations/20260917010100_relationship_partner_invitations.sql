-- partner_invitations: 남편 초대 1회성 토큰 SOURCE (FUC-W-INVITE-001, FUC-H-INVITE-001).
-- TARGET_DB_SCHEMA.md 기준 NEW. account/schemas.py의 InvitationResponse가 이 테이블에서
-- invitation_id/invitation_url/expires_at을 만들어 낸다(token 자체는 응답에 노출하지 않음).
create table if not exists public.partner_invitations (
  id uuid primary key default gen_random_uuid(),
  wife_user_id uuid not null references auth.users (id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now(),

  -- NFR-026: 유효시간 72시간 이내. 생성 시각 기준 최대 72시간까지만 만료시각을
  -- 허용해 DB 레벨에서 강제한다. "1회성"(재사용 금지)은 CHECK로 표현할 수 없어
  -- (같은 행을 두 번 읽는 검증이 필요) Service 계층이 `used_at is null` 확인 후
  -- 토큰을 소비할 때마다 `used_at`을 채우는 방식으로 강제한다.
  constraint partner_invitations_max_72h
    check (expires_at <= created_at + interval '72 hours')
);

create index if not exists partner_invitations_wife_user_id_idx
  on public.partner_invitations (wife_user_id);

-- 접근은 backend(service role)만. RLS 켜고 정책 없음 — anon/authenticated 직접 접근 차단.
-- 남편이 토큰을 "검증"하는 경로도 FastAPI(service role)를 거치며, 토큰 자체를 클라이언트가
-- 직접 조회할 수 있는 정책을 열지 않는다(토큰 추측 공격 표면을 만들지 않기 위함).
alter table public.partner_invitations enable row level security;

-- Grant: default privileges(20260917000002)로 service_role에 자동 적용됨. 추가 grant 없음.
