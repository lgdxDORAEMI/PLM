-- chat_messages.recommendation: 식사 모드 챗봇의 추천 카드 1장(FUC-W-MEAL-003, 챗봇 S5).
-- 모양은 routine_items meal payload와 같다: {title, reason, nutritionTags, cautions}.
-- 챗봇은 추천만 하고 루틴을 바꾸지 않는다. 사용자가 고르면 프론트가 기존 Care API로 보낸다.
-- 추천이 없는 메시지(일반 모드·질문 답변)는 null. 기존 행·다른 코드 영향 없음.
-- 되돌리기: alter table public.chat_messages drop column if exists recommendation;
alter table public.chat_messages add column if not exists recommendation jsonb;
