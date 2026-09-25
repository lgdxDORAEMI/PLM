-- 식사 이미지를 앱 번들이 아닌 Supabase Storage 공개 버킷에서 제공한다.
-- DB에는 프로젝트 URL과 분리된 버킷 내부 imagePath만 저장한다.
begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'meal-images',
  'meal-images',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create temporary table meal_image_paths (
  title text primary key,
  image_path text not null
) on commit drop;

insert into meal_image_paths (title, image_path)
values
  ('베리 요거트 귀리죽', 'breakfast/berry_yogurt_oatmeal.jpg'),
  ('계란찜과 흰쌀죽', 'breakfast/steamed_egg_rice_porridge.jpg'),
  ('바나나 두유 스무디', 'breakfast/banana_soy_smoothie.jpg'),
  ('시금치 두부 된장국과 밥', 'breakfast/spinach_tofu_soybean_soup.jpg'),
  ('고구마와 삶은 달걀', 'breakfast/sweet_potato_boiled_egg.jpg'),
  ('닭가슴살 채소 샐러드', 'lunch/chicken_breast_salad.jpg'),
  ('소고기 미역국과 잡곡밥', 'lunch/beef_seaweed_soup_multigrain_rice.jpg'),
  ('연어구이와 현미밥', 'lunch/grilled_salmon_brown_rice.jpg'),
  ('두부 채소 비빔밥', 'lunch/tofu_vegetable_bibimbap.jpg'),
  ('닭죽과 나물 반찬', 'lunch/chicken_porridge_greens.jpg'),
  ('야채죽과 두부 반찬', 'dinner/vegetable_porridge_tofu.jpg'),
  ('대구 맑은탕과 흰쌀밥', 'dinner/cod_clear_soup_rice.jpg'),
  ('가지 두부조림과 현미밥', 'dinner/eggplant_tofu_brown_rice.jpg'),
  ('닭안심 채소볶음과 밥', 'dinner/chicken_vegetable_stir_fry.jpg'),
  ('버섯 들깨 칼국수', 'dinner/mushroom_perilla_kalguksu.jpg'),
  ('따뜻한 우유 한 컵', 'snack/warm_milk.jpg'),
  ('바나나와 견과류 한 줌', 'snack/banana_nuts.jpg'),
  ('찐 감자 반 개', 'snack/steamed_potato.jpg'),
  ('플레인 요거트와 블루베리', 'snack/plain_yogurt_blueberry.jpg'),
  ('삶은 달걀과 방울토마토', 'snack/boiled_egg_cherry_tomato.jpg');

-- 기존 앱 에셋 필드는 카탈로그 밖 메뉴까지 포함해 모두 제거한다.
update public.routine_items
set payload = coalesce(payload, '{}'::jsonb) - 'imageAsset'
where category = 'meal'
  and coalesce(payload, '{}'::jsonb) ? 'imageAsset';

update public.recommendation_feedback
set payload = coalesce(payload, '{}'::jsonb) - 'imageAsset'
where kind = 'meal_replace'
  and coalesce(payload, '{}'::jsonb) ? 'imageAsset';

-- 현재 저장된 루틴 및 대체 메뉴를 Storage 상대 경로로 백필한다.
update public.routine_items as item
set payload = coalesce(item.payload, '{}'::jsonb)
  || jsonb_build_object('imagePath', mapping.image_path)
from meal_image_paths as mapping
where item.category = 'meal'
  and item.title = mapping.title;

update public.recommendation_feedback as feedback
set payload = coalesce(feedback.payload, '{}'::jsonb)
  || jsonb_build_object('imagePath', mapping.image_path)
from meal_image_paths as mapping
where feedback.kind = 'meal_replace'
  and feedback.payload->>'title' = mapping.title;

commit;
