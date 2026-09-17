-- notifications: 남편 알림(오전리포트/가사요청/컨디션변경) EVENT 로그 (FUC-H-NOTI-001/002).
-- TARGET_DB_SCHEMA.md 기준 NEW.
--
-- 재확인 메모: type 값은 DB_ERD_스키마.md 초안(4종)이 아니라 실제
-- backend/app/domains/family/schemas.py의 NotificationType(3종:
-- morning_report/household_request/condition_changed)을 기준으로 정정했다.
-- 같은 파일의 NotificationResponse에 있는 target_date/reference_id 필드도
-- TARGET_DB_SCHEMA.md 표에 빠져 있어 여기서 추가했다.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references auth.users (id) on delete cascade,
  type text not null
    check (type in ('morning_report', 'household_request', 'condition_changed')),
  reference_id uuid not null,
  target_date date,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_read_idx
  on public.notifications (recipient_user_id, read_at);

-- 민감정보 경계: title/body에 daily_conditions 원본 점수나 AI 대화 원문을 그대로
-- 넣지 않는다(NFR-013) — 요약 문구만 담아야 하며 이는 Service 계층 책임이다.
alter table public.notifications enable row level security;

-- 접근은 backend(service role)만. RLS 켜고 정책 없음 — 알림 수신자 필터링은
-- FastAPI가 인증된 사용자 id로 recipient_user_id를 조회하는 방식으로 수행한다.
-- Grant: default privileges(20260917000002)로 자동 적용됨. 추가 grant 없음.
