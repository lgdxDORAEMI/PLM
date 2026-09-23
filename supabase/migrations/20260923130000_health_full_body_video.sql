alter table public.health_exercise_videos
  drop constraint if exists health_exercise_videos_pain_type_check,
  drop constraint if exists health_exercise_videos_routine_part_check;

alter table public.health_exercise_videos
  add constraint health_exercise_videos_pain_type_check
    check (pain_type in ('back', 'wrist', 'pelvic', 'leg', 'full_body')),
  add constraint health_exercise_videos_routine_part_check
    check (routine_part in ('waist', 'wrist', 'pelvis', 'leg', 'whole')),
  add column if not exists duration text,
  add column if not exists target text;

insert into public.health_exercise_videos (
  pain_type,
  routine_part,
  title_ko,
  provider,
  youtube_id,
  duration,
  target
)
values (
  'full_body',
  'whole',
  '임산부 전신 저강도 운동',
  'Pregnancy and Postpartum TV',
  'InQu8jMT130',
  '25분',
  '임신 1·2·3분기'
)
on conflict (pain_type) do update set
  routine_part = excluded.routine_part,
  title_ko = excluded.title_ko,
  provider = excluded.provider,
  youtube_id = excluded.youtube_id,
  duration = excluded.duration,
  target = excluded.target,
  is_active = true,
  updated_at = now();
