-- 웬즈데이 AI S3 (R1·R2): 하루 루틴을 버전별로 쌓는다. 설계: docs/ai_wednesday/Ai_wednesday_pipeline_v3.md §3 S3
-- FUC-W-COND-003(확정 전 수정 = 재생성), FUC-W-COND-004(확정 후 재입력 = 덮어쓰지 않고 새 루틴).
--
-- daily_routines: 생성할 때마다 새 행(revision +1). 같은 (user_id, date)에서 revision이 가장 큰 행이 현재 루틴이다.
--                 각 행의 response에 그 버전의 4종 가이드 전체가 남으므로 이력은 여기서 본다.
-- routine_items : "현재 상태" 테이블. 재생성 때 지우지 않고 같은 행을 고쳐 쓴다(item_key 기준).
--                 id가 유지되므로 household_request_items·chat_messages·recommendation_feedback의 FK가 끊기지 않고,
--                 routine_items를 user_id·date로 읽는 다른 도메인 코드도 그대로 동작한다.

-- 1) 같은 날 여러 버전 허용
alter table public.daily_routines drop constraint if exists daily_routines_user_id_date_key;

alter table public.daily_routines
  add column if not exists revision       smallint not null default 1,
  add column if not exists confirmed_at   timestamptz,  -- '저장하고 마치기'로 확정한 시각. null = 확정 전
  add column if not exists change_summary jsonb;        -- 직전 버전 대비 {added, updated, removed, unchanged} item_key 목록

alter table public.daily_routines
  add constraint daily_routines_user_date_revision_key unique (user_id, date, revision);

-- 2) 직전 버전 대비 항목 변화(프론트 배너 색). null = 변화 없음
alter table public.routine_items
  add column if not exists change_kind text check (change_kind in ('added', 'updated', 'removed'));

-- 3) 지난 날짜의 중간 버전 정리. 항목은 항상 최신 버전 행을 가리키므로 중간 버전 삭제는 routine_items에 영향이 없다.
--    오늘(KST) 날짜는 건드리지 않는다. 반환값 = 삭제한 행 수.
create or replace function public.prune_routine_versions()
returns integer
language sql
as $$
  with deleted as (
    delete from public.daily_routines d
    where d.date < (now() at time zone 'Asia/Seoul')::date
      and exists (
        select 1 from public.daily_routines n
        where n.user_id = d.user_id and n.date = d.date and n.revision > d.revision
      )
    returning 1
  )
  select count(*)::integer from deleted;
$$;

-- 정리 스케줄(pg_cron). Supabase 대시보드 → Database → Extensions에서 pg_cron을 켠 뒤 SQL Editor에서 한 번 실행:
--   select cron.schedule('prune-routine-versions', '0 19 * * *', 'select public.prune_routine_versions()');  -- 매일 04:00 KST
-- 확인:  select * from cron.job where jobname = 'prune-routine-versions';
-- 해제:  select cron.unschedule('prune-routine-versions');

-- 되돌리기(같은 날 2행 이상 쌓였으면 먼저 최신 revision만 남긴 뒤 실행):
--   drop function if exists public.prune_routine_versions();
--   alter table public.routine_items drop column if exists change_kind;
--   alter table public.daily_routines drop constraint if exists daily_routines_user_date_revision_key;
--   alter table public.daily_routines drop column if exists change_summary, drop column if exists confirmed_at, drop column if exists revision;
--   alter table public.daily_routines add constraint daily_routines_user_id_date_key unique (user_id, date);
