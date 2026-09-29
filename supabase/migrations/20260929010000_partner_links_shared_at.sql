-- 2026-09-29: 아내가 남편에게 자기 기록을 공개했는지를 서버에 남긴다.
-- 초기화 후 다시 초대를 확인하기 전까지 남편 화면에 아내 정보가 보이면 안 된다.
-- 예전에는 이 상태가 아내 브라우저(localStorage)에만 있어 남편 계정이 알 수 없었다.
-- 되돌리기: 20260929000000_reset_restore_posture_events.sql을 다시 실행한다.
--   shared_at 칸은 남겨 둔다. 백엔드가 이 칸을 읽으므로 백엔드를 먼저 되돌린 뒤에만
--   alter table public.partner_links drop column shared_at;

alter table public.partner_links
  add column if not exists shared_at timestamptz;

-- 이미 연결된 부부는 공개된 상태로 시작한다.
update public.partner_links
set shared_at = linked_at
where shared_at is null;

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

  -- 2026-09-29: 남편 화면 공개를 거둔다. 아내가 초대 화면에서 다시 확인하면 채워진다.
  update public.partner_links
  set shared_at = null
  where wife_user_id = p_user_id;

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
