# FE–BE 연결 기준 상태

확인일: 2026-09-23. 기준: `frontend/lib/**`, `backend/app/**`, `docs/backend/**`, `frontend/README.md`의 현재 코드. 문서의 구현 상태가 코드와 다르면 코드를 우선한다.

## 판정 기준

- **REAL**: 대상 기능의 현재 범위에서 Backend API를 호출한다.
- **PARTIAL**: 실 API를 쓰는 부분과 local 또는 미구현 부분이 함께 있다.
- **MOCK**: 제품 경로가 Mock/local 데이터만 쓴다.
- **PHASE2**: 현재 연결 점검 범위 밖으로 명시된 기능이다.

아래 API 경로는 모두 `/api/v1`을 앞에 붙인다. `수정 파일`의 `—`는 이번 단계에서 코드 수정이 없다는 뜻이다. 실 API 경로는 Supabase 설정이 있을 때 선택된다. 설정 없는 데모와 주입된 테스트 서비스의 Mock 경로는 별도이며, API 요청 실패 시 Mock으로 자동 전환하지 않는다.

| 기능 | 기존 상태 | 최종 상태 | API | 수정 파일 |
|---|---|---|---|---|
| Profile | REAL | REAL | `GET /profile/me`, `PUT /profile/me/{due-date,body,pregnancy-history,pregnancy-count,allergies,medical-notes}` | — |
| Today Condition | REAL | REAL | `GET/PUT /care/conditions/{date}` | — |
| Activity | REAL | REAL | `GET /care/conditions/{date}`, `PUT /care/conditions/{date}/activities`, `POST /routine/today` | — |
| Daily Routine | REAL | REAL | `GET/POST /routine/today` | — |
| Home Weekly Guide | 미연결 | REAL | `GET /routine/home`; 컨디션·오늘 루틴 유무와 무관하게 주차별 안내 조회 | `frontend/lib/features/home/**` |
| Meal | PARTIAL | REAL | `GET /meals/today`, `PUT /care/routine-items/{id}`, `POST /chat/meal-alternative`, `GET/POST /chat/messages` 연결. 저장된 추천 카드도 대화 이력에서 복원 | `frontend/lib/features/meal/**` |
| Household | PARTIAL | PARTIAL | `GET /household/today`, `POST/GET /family/household-requests` 연결. 요청 목록 조회로 아내 화면의 남편 확인·완료 상태 복원. ThinQ 가전 실행 API는 없음 | `frontend/lib/features/household/controllers/household_guide_controller.dart` |
| Health | REAL | REAL | `GET /health/today`, `PUT /care/routine-items/{id}/execution` | — |
| Sleep | PARTIAL | PARTIAL | `GET /sleep/today`, `PUT /care/routine-items/{id}/sleep-environment` 연결. ThinQ 실행 API는 없음 | — |
| Calendar | REAL | REAL | `GET /care/calendar/{month}`, 선택일 `GET /care/daily-reports/{date}` | — |
| Daily Report | REAL | REAL | `POST /care/daily-reports/{date}/preview`, `POST /care/daily-reports/{date}/finalize`, `GET /care/daily-reports/{date}` | — |
| Partner Notification | REAL | REAL | `GET /family/notifications`, `POST /family/notifications/{id}/read` | — |
| Partner Household Request | REAL | REAL | `GET /family/household-requests`, `GET /family/household-requests/{id}`, `POST /family/household-requests/{id}/items/{item_id}/{confirm,complete}` | — |
| Motion | PHASE2 | PHASE2 | 제품 조회는 `GET /movement/events`, `GET /movement/report/daily`, `GET /family/motion/privacy` 연결. 별도 카메라 데모는 `WS /movement/live/stream` 사용 | — |

## 남은 경계

- Chat은 실제 AI 응답, 대화 이력, 추천 카드, 컨디션 기반 루틴 수정 상태를 Backend와 `chat_messages`에 연결한다.
- Household/Sleep의 가전 버튼은 local 실행 이력만 기록한다. ThinQ 제어 API가 없으며 이번 범위에서 제외했다.
- 가사 요청의 기존 전송 계약은 항목 제목을 보낸다. 아내 화면은 오늘 요청의 제목으로 진행 상태를 대응시킨다. 동일한 제목이 여러 루틴 항목에 쓰일 경우 항목별 식별은 이 계약만으로 불가능하다. 요청 데이터 구조 변경은 이번 범위에서 제외했다.
- `docs/backend/SCREEN_DATA_API_MAPPING.md` 등의 오래된 Stub 표기 대신 실제 `backend/app/api/v1/**` 라우트와 서비스 구현으로 판정했다.

## 검증

- `flutter analyze`: 아래 실행 결과로 갱신
- `flutter test`: 아래 실행 결과로 갱신
- `flutter build web`: 아래 실행 결과로 갱신

## 후속 변경: 챗봇 대화 연결 (2026-09-22)

`/wife/chat`의 일반 대화와 식사 루틴별 대화는 `GET/POST /api/v1/chat/messages`에 연결된다. Backend는 OpenAI로 답변을 생성하고 질문·답변·추천 카드·루틴 수정 상태를 `chat_messages`에 저장한다. 식사 재추천과 교체도 연결되어 있으며, API 또는 대화 이력 조회 실패 시 Mock으로 자동 전환하지 않는다.
