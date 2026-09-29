-- 2026-09-29: 오늘 기록 초기화가 당일 posture_events를 다시 지우도록 복구한다.
-- 20260925000000_reset_chat_messages_by_date.sql이 posture_events 삭제가 없던
-- 09-22 원본을 기준으로 함수를 덮어써 삭제 블록이 빠졌다. 나머지 동작은 09-25 그대로다.
-- 되돌리기: 20260925000000_reset_chat_messages_by_date.sql을 다시 실행한다.
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

  -- 2026-09-29: 09-25 버전에서 빠진 당일(KST) 자세 이벤트 삭제를 복구한다.
  delete from public.posture_events
  where user_id = p_user_id
    and started_at >= (p_target_date::timestamp at time zone 'Asia/Seoul')
    and started_at < ((p_target_date + 1)::timestamp at time zone 'Asia/Seoul');

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
