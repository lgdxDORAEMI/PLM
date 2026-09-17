-- motion_consents: 모션 모니터링 동의·수집 ON/OFF SOURCE (FUC-B-MOTION-001, NFR-012).
-- Shared Protected(Movement Recognition) 소관 — family.py Stub 위치에서 다루더라도
-- 스키마 변경은 Movement 담당 리뷰가 필요하다(BACKEND_ARCHITECTURE.md §3, §7).
--
-- 재확인 메모: TARGET_DB_SCHEMA.md 초안은 컬럼을 enabled 하나로 뒀었으나, 실제
-- backend/app/domains/family/schemas.py의 MotionPrivacyResponse가
-- consent_granted(동의)와 collection_enabled(수집 ON/OFF)를 별개 필드로 이미
-- 정의해 뒀다. NFR-012가 "동의 철회"와 "ON/OFF 토글"을 분리하라고 요구하는 것과도
-- 일치해, 컬럼을 코드 계약에 맞춰 2개로 정정했다.
create table if not exists public.motion_consents (
  user_id uuid primary key references auth.users (id) on delete cascade,
  consent_granted boolean not null default false,
  collection_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

-- 동의 철회(consent_granted=false)는 collection_enabled도 함께 false로 만들지만,
-- ON/OFF 토글(collection_enabled만 변경)은 consent_granted를 건드리지 않는다 —
-- 이 비대칭은 Service 계층 책임이며 DB 제약으로 강제하지 않는다(NFR-012).
alter table public.motion_consents enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음 — 아내 본인 외에는(남편 포함)
-- 이 테이블에 대한 어떤 조회 경로도 열지 않는다(화면설계서: 남편은 동의/수집 설정을
-- 조회조차 할 수 없음).
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
