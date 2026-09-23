-- 챗봇 S8: 컨디션 수정 확인 및 백그라운드 루틴 재생성 상태.
-- assistant 메시지에만 사용하며, 메시지 id를 작업 id로 재사용한다.
-- 모양: {status, summary, changes, error_message?, routine_revision?}
-- 되돌리기: alter table public.chat_messages drop column if exists routine_update;
alter table public.chat_messages
  add column if not exists routine_update jsonb;
