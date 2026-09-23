create table if not exists public.health_exercise_videos (
  pain_type text primary key check (pain_type in ('back', 'wrist', 'pelvic', 'leg')),
  routine_part text not null unique check (routine_part in ('waist', 'wrist', 'pelvis', 'leg')),
  title_ko text not null,
  provider text not null,
  youtube_id text not null unique check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.health_exercise_videos enable row level security;

drop policy if exists health_exercise_videos_authenticated_read
  on public.health_exercise_videos;
create policy health_exercise_videos_authenticated_read
  on public.health_exercise_videos
  for select
  to authenticated
  using (is_active);

grant select on public.health_exercise_videos to authenticated;
grant all on public.health_exercise_videos to service_role;

insert into public.health_exercise_videos (
  pain_type,
  routine_part,
  title_ko,
  provider,
  youtube_id
)
values
  ('back', 'waist', '임신 중 허리 통증 완화 스트레칭', 'Pregnancy and Postpartum TV', '33LLeqyVbG0'),
  ('wrist', 'wrist', '임신 중 손목·손 저림 완화 운동', 'Pregnancy and Postpartum TV', '29OhkciWEMY'),
  ('pelvic', 'pelvis', '임신 중 골반 통증 완화 운동', 'Pregnancy and Postpartum TV', 'wqiDZZbaas8'),
  ('leg', 'leg', '임신 중 좌골신경·다리 통증 완화 요가', 'Pregnancy and Postpartum TV', 'SFMoku8trIA')
on conflict (pain_type) do update set
  routine_part = excluded.routine_part,
  title_ko = excluded.title_ko,
  provider = excluded.provider,
  youtube_id = excluded.youtube_id,
  is_active = true,
  updated_at = now();
