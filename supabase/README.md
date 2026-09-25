# Supabase 데이터

PLM 백엔드는 Supabase Auth로 사용자를 확인하고 PostgreSQL에 프로필, 일일 기록, 루틴, 대화, 가족 공유, 모션 감지 데이터를 저장합니다. 스키마와 DB 함수의 기준은 [migrations](migrations) 디렉터리의 SQL 파일입니다.

## 주요 데이터

| 영역 | 주요 테이블 |
| --- | --- |
| 사용자·가족 | `profiles`, `pregnancy_profiles`, `partner_invitations`, `partner_links`, `notifications` |
| 오늘 생활 기록 | `daily_conditions`, `daily_routines`, `routine_items`, `recommendation_feedback`, `daily_reports` |
| 가족 분담·대화 | `household_requests`, `chat_messages` |
| AI 지식 | `pregnancy_knowledge` |
| 건강 운동 영상 | `health_exercise_videos` |
| 모션 | `motion_consents`, `posture_calibration_profiles`, `posture_events` |

`daily_routines`는 사용자·날짜별로 여러 revision을 가질 수 있습니다. 화면은 해당 날짜의 최신 루틴과 그 `routine_items`를 사용합니다. 모션 리포트는 `posture_events`를 조회 시 집계합니다. 카메라 프레임 자체는 DB에 보관하지 않습니다.

## 오늘 기록 초기화

`reset_daily_experience(uuid, date)`는 [기본 초기화 마이그레이션](migrations/20260922000000_reset_daily_experience.sql)에 정의되고 [모션 기록 확장 마이그레이션](migrations/20260922010000_reset_today_posture_events.sql), [가족 요청·알림 확장 마이그레이션](migrations/20260923000000_reset_today_family_requests.sql) 순서로 갱신됩니다. 백엔드의 `POST /api/v1/care/today/reset`을 통해 service role로만 호출합니다.

함수는 KST 오늘의 아내 데이터에 대해 남편 알림·리포트·모션 이벤트·가사 요청과 요청 항목·루틴 연관 채팅과 피드백·모든 루틴 revision·컨디션을 하나의 트랜잭션에서 삭제합니다. 프로필, 배우자 연결, 모션 동의와 캘리브레이션 기준선은 유지합니다. `posture_events`는 `started_at`의 KST 날짜 구간으로 제한합니다.

마이그레이션 적용 순서와 환경 설정은 [guide.md](../guide.md), 엔드포인트 계약은 [docs/api.md](../docs/api.md)를 참고하세요. 실제 키나 DB URL은 문서나 Git에 기록하지 않습니다.

건강 운동 영상은 기본 카탈로그 마이그레이션 이후 `20260923130000_health_full_body_video.sql`에서 전신 저강도 운동과 재생 시간·대상 분기 정보를 추가합니다.

## 식사 이미지 Storage

식사 이미지는 공개 버킷 `meal-images`에 두고, 루틴 DB에는 버킷 내부 `imagePath`만 저장합니다.
Supabase SQL Editor에서
[`20260925020000_meal_storage_images.sql`](migrations/20260925020000_meal_storage_images.sql)을 실행한 뒤,
저장소 루트에서 다음 명령으로 사진 20장을 업로드합니다.

```bash
backend/.venv/bin/python supabase/scripts/upload_meal_images.py --dry-run
backend/.venv/bin/python supabase/scripts/upload_meal_images.py
```

업로드는 `backend/.env`의 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`를 사용합니다.
키는 출력하거나 Git에 저장하지 않습니다. 같은 객체 경로는 덮어쓰며 브라우저 캐시는 1시간으로 설정합니다.
