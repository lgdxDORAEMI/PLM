-- W-PROFILE-001 출산예정일 입력 규칙 완화 (2026-09-16).
-- 출산예정일은 병원 진단값을 그대로 저장하고, 마지막 생리 시작일은 선택 입력이다.
-- 실제 출산예정일은 초음파로 조정되므로 두 값이 정확히 280일 차이가 아닐 수 있어
-- 기존 CHECK 제약을 제거한다. 입력 범위 검증은 backend/app/schemas/profile.py에서 한다.
alter table public.pregnancy_profiles
  drop constraint if exists pregnancy_profiles_last_period_matches_due;
