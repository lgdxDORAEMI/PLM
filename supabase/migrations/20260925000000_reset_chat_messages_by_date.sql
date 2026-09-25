-- 2026-09-25: 오늘 기록 초기화가 그날 챗봇 대화를 전부 지우도록 범위를 넓힌다.
-- 이전 버전은 routine_item_id로 묶인 대화만 지워 일반 대화가 남았다.
-- 되돌리기: 20260922000000_reset_daily_experience.sql을 다시 실행한다.
-- One RPC call is one PostgreSQL transaction. Only the backend service role
-- may reset the authenticated wife's current KST day.
create or replace function public.reset_daily_experience(
  p_user_id uuid,
  p_target_date date
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_target_date <> (now() at time zone 'Asia/Seoul')::date then
    raise exception 'Only the current KST day can be reset';
  end if;

  if not exists (
    select 1 from public.profiles
    where user_id = p_user_id and role = 'wife'
  ) then
    raise exception 'Only a wife account can reset daily experience';
  end if;

  -- Partner notifications point to today's routine or household request.
  delete from public.notifications n
  where n.recipient_user_id in (
    select husband_user_id from public.partner_links
    where wife_user_id = p_user_id
  )
  and (
    (n.target_date = p_target_date and n.type in
      ('morning_report', 'condition_changed', 'household_request'))
    or n.reference_id in (
      select id from public.daily_routines
      where user_id = p_user_id and date = p_target_date
      union
      select id from public.household_requests
      where wife_user_id = p_user_id and date = p_target_date
    )
  );

  delete from public.daily_reports
  where user_id = p_user_id and date = p_target_date;

  -- Request items cascade with their parent; remove the request before the
  -- routine item it references, including partner confirmation/completion.
  delete from public.household_requests
  where wife_user_id = p_user_id and date = p_target_date;

  -- 2026-09-25: 그날 대화를 전부 지운다. 루틴에 묶인 것만 지우면 하단 탭 일반 대화가
  -- 남아 "초기화했는데 챗봇 기록이 그대로"로 보인다.
  delete from public.chat_messages
  where user_id = p_user_id and date = p_target_date;

  delete from public.recommendation_feedback
  where routine_item_id in (
    select id from public.routine_items
    where user_id = p_user_id and date = p_target_date
  );

  delete from public.routine_items
  where user_id = p_user_id and date = p_target_date;

  -- There may be several revisions for one day.
  delete from public.daily_routines
  where user_id = p_user_id and date = p_target_date;

  delete from public.daily_conditions
  where user_id = p_user_id and date = p_target_date;
end;
$$;

revoke all on function public.reset_daily_experience(uuid, date) from public, anon, authenticated;
grant execute on function public.reset_daily_experience(uuid, date) to service_role;
