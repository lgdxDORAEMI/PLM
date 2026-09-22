-- Extend the existing atomic daily reset with today's motion detection events.
-- Preserve calibration baselines and motion consent, which are not daily records.
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

  -- The movement API and report query both use KST day boundaries. Scope the
  -- delete to this user and [today 00:00, tomorrow 00:00) in that timezone.
  delete from public.posture_events
  where user_id = p_user_id
    and started_at >= (p_target_date::timestamp at time zone 'Asia/Seoul')
    and started_at < ((p_target_date + 1)::timestamp at time zone 'Asia/Seoul');

  delete from public.household_requests
  where wife_user_id = p_user_id and date = p_target_date;

  delete from public.chat_messages
  where routine_item_id in (
    select id from public.routine_items
    where user_id = p_user_id and date = p_target_date
  );

  delete from public.recommendation_feedback
  where routine_item_id in (
    select id from public.routine_items
    where user_id = p_user_id and date = p_target_date
  );

  delete from public.routine_items
  where user_id = p_user_id and date = p_target_date;

  delete from public.daily_routines
  where user_id = p_user_id and date = p_target_date;

  delete from public.daily_conditions
  where user_id = p_user_id and date = p_target_date;
end;
$$;

revoke all on function public.reset_daily_experience(uuid, date) from public, anon, authenticated;
grant execute on function public.reset_daily_experience(uuid, date) to service_role;
