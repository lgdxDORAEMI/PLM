-- FUC-W-PROFILE-002 생년월일(→나이 계산) 저장. 2단계(신장·체중)와 같은 화면에서
-- 함께 입력되므로 별도 테이블 없이 pregnancy_profiles에 컬럼만 추가한다.
alter table public.pregnancy_profiles
  add column if not exists birth_date date;
