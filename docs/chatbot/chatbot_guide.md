# 챗봇 메이킹 가이드

> 세션 규칙: `docs/chatbot/chatbot_development_rules.md`
> 근거 요구사항: FUC-W-CHAT-001·003·004, FUC-W-MEAL-003 (`docs/requirements/04_1_기능요구사항명세서.md`)
> 근거 화면: 첨부 1(식사 가이드 → 챗봇), 첨부 2(하단 탭 → 챗봇)

## 0. 한 줄 요약
챗봇은 **하나**다. 같은 엔드포인트·같은 파이프라인을 쓰고, **진입 경로(모드)** 에 따라 AI에게 넘기는 **컨텍스트 양**만 다르다.

| 모드 | 진입 | 구분 방법 | 할 수 있는 것 | 컨텍스트 |
|---|---|---|---|---|
| 일반(tab) | 하단 탭 '챗봇' | `routine_item_id` 없음 | 4종 가이드·기능 설명·임신 생활 질의응답 | 공통 컨텍스트 |
| 식사(meal) | 식사 가이드 AI 배너 | `routine_item_id` 있음 | 질의응답 + **메뉴 재추천** (변경은 사용자가 직접) | 공통 + **식사 메모리** |

- 4종 가이드 = 식사(meal)·가사(household)·건강(health)·수면(sleep). `routine_items.category` 값과 같다.
- 모드 구분에 새 필드를 만들지 않는다. 기존 `ChatMessageInput.routine_item_id` 유무로 판단한다.
- 챗봇은 루틴에 영향을 주지 않는다. 식사 모드도 **추천만** 하고, 식단 변경은 사용자가 직접 한다 (2026-09-22 확정).

### 0.1 진입별 프론트 역할 (2026-09-22 확정)
| # | 진입 | 프론트가 할 일 | 서버가 보는 것 | 모드 |
|---|---|---|---|---|
| 1 | 식사 가이드 AI 배너 (`/wife/chat?source=meal&period=`) | 보던 끼니 카드의 `routine_items.id`를 챗 화면에 넘기고, 메시지를 보낼 때 같이 보냄 | `routine_item_id` 있음 | 식사 모드 |
| 2 | 하단 탭 '챗봇' (`/wife/chat`) | 아무것도 넘기지 않음 | `routine_item_id` 없음 | 일반 모드 |

- 가사·건강·수면 가이드에서 챗봇을 여는 화면은 없다. 라우터의 `source=household|health|sleep`은 뒤로가기 목적지만 정한다 (`frontend/lib/routing/app_router.dart` `_guideRouteFor`).

### 0.2 변경 요청 처리 (2026-09-22 확정)
| 요청 | 일반 모드 (하단 탭) | 식사 모드 (식사 가이드) |
|---|---|---|
| 식사 메뉴 변경 | "식사 가이드의 AI 재조정에서 바꿀 수 있어요" + `식사 가이드 보기` | 재추천만 (추천 카드 → 사용자가 직접 선택, S6) |
| 가사·건강·수면 변경 | "아직 지원하지 않아요" + 해당 가이드 보기 버튼 | 같음 |
| 오늘 컨디션 점수 변경 | 명시적 1~5 값 확인 후 웬즈데이 루틴 백그라운드 재생성(S8) | 같음 |

- 가사·건강·수면 변경(FUC-W-CHAT-002)은 Phase 2 이연이 아니라 **프로젝트 범위에서 제외**한다.
- 버튼은 요청 영역에 따라 `가사 가이드 보기` / `건강 가이드 보기` / `수면 가이드 보기` 중 하나. 누르면 프론트 기존 경로(`householdGuide`, `healthGuide`, `sleepGuide`)로 이동한다.
- "질문"과 "변경 요청"의 구분은 서버(LLM)가 한다. "수면 가이드가 뭐예요?"는 질문이라 답하고, "수면 루틴 바꿔줘"는 변경 요청이라 위 안내로 답한다.

## 1. 현재 상태 (2026-09-22 코드 기준)
| 항목 | 상태 | 근거 |
|---|---|---|
| `GET/POST /chat/messages` | 있음. 고정 문구만 저장·반환 | `backend/app/api/v1/chat.py` |
| 대화 저장 `chat_messages` | 있음. `routine_item_id`, `suggested_actions(jsonb)` 컬럼 보유 | `supabase/migrations/20260917010700_relationship_chat_messages.sql` |
| 메뉴 수락/거절 이력 `recommendation_feedback` | 테이블만 있음 (`meal_accept/reject/replace`) | `supabase/migrations/20260917010800_...recommendation_feedback.sql` |
| 입력 수집(프로필·컨디션) | 웬즈데이 AI에 있음 → 재사용 | `backend/app/services/routine/inputs.py` |
| 확정 규칙(금지·제한 재료) | 웬즈데이 AI에 있음 → 재사용 | `backend/app/services/routine/rules.py` |
| RAG 검색 | 웬즈데이 AI에 있음 → 재사용 | `backend/app/services/routine/retriever.py` |
| LLM 호출 | OpenAI `gpt-4.1-mini`, JSON 스키마 강제, 8초 타임아웃 | `backend/app/services/routine/generator.py`, `core/config.py` |
| 프론트 챗 화면 | 하나(`MealChatScreen`). 하단 탭 진입도 아침 메뉴 재조정으로 시작 | `frontend/lib/features/meal/screens/meal_chat_screen.dart` |
| 프론트 챗 응답 | 가짜 서비스(`MockMealService`). 백엔드 `/chat` 호출 없음, 기준 메뉴도 가짜 데이터라 `routine_items.id` 아님 | 같은 파일 53·189행 |
| 프론트 "이걸로 할게요" | 앱 안 임시 저장소만 변경, 서버 호출 없음 | `frontend/lib/features/meal/data/meal_selection_store.dart` |
| 프론트 입력창 | 미리보기 모드에서만 켜짐 | `meal_chat_screen.dart` `_chatAvailable` |
| 프론트 비식사 필터 | 서버에 보내기 전 단어 검사로 차단 (`가사·청소·빨래·집안일·건강·운동·스트레칭·수면·잠`) | `frontend/lib/features/meal/controllers/meal_chat_controller.dart` `_isDeferredRoutineRequest` |

- RAG: 질문과 뜻이 가까운 임신 지식 문서 조각을 DB에서 찾아 AI에게 같이 넘기는 방식.
- JSON 스키마 강제: AI 답을 정해진 필드 모양으로만 받는 OpenAI 옵션. 파싱 실패를 막는다.

## 2. 설계 (S 순서)

### ~~S1 공통 컨텍스트 빌더~~
- 구현(09-22, push `967b7fb`): `backend/app/domains/chat/context.py` (`collect_context`, `today_guides`, `banner_text`), 테스트 `backend/tests/test_chat_context.py` 5개. 웬즈데이 쪽은 `collect_facts(require_condition=False)`, `KnowledgeRetriever.search(질문, 주차)` 옵션만 추가.
- 하는 일: 두 모드가 모두 쓰는 "이 사람 기준 정보"를 한 dict로 모은다.
- 내용: 임신 주차, 알레르기·주의 진단, 오늘 컨디션(입덧·통증·피로), 오늘 4종 가이드 제목 목록, RAG 조각 상위 N개.
- 기분(`mood`)은 넣지 않는다. 기분은 수치화해서 케어할 대상이 아니라고 회의에서 결정했다 (2026-09-22, 원격 `4d94b39`에서 입력 화면 제거). DB에는 기본값이 남아 있으므로 읽더라도 버린다.
- 재사용: `inputs.py`(프로필·컨디션), `retriever.py`(RAG), `guide/query_service.py`(오늘 가이드). 새로 만들지 않는다.
- 컨디션이 없으면 프로필·주차만으로 답한다 (FUC-W-CHAT-001 비고).
- 배너 문구("임신 18주차 · 입덧 심함 · 갑각류 알레르기")도 이 dict에서 만든다.

### ~~S2 응답 생성 + 폴백~~
- 구현(09-22, push `967b7fb`): `backend/app/domains/chat/responder.py` (`generate_reply`, `build_prompt`), 테스트 `backend/tests/test_chat_responder.py` 6개. LLM 호출은 웬즈데이 `OpenAIRoutineGenerator.generate` 재사용, 전체 상한 9.5초, 검색 실패는 참고 자료 없이 진행. 모드별 지시는 `extra_rules`로 S3·S5에서 덧붙인다.
- 변경: DB 저장은 엔드포인트 연결과 함께 S3에서 한다. 위험 신호는 고정 문구 대신 지시문 규칙 3으로 처리한다("지금 바로 병원에 문의해 주세요"를 먼저 말함).
- 하는 일: 컨텍스트 + 최근 대화 + 질문 → OpenAI → 스키마 검증 → 저장.
- 응답 스키마(공통): `content`(답변), `suggested_actions`(버튼 라벨 목록, 최대 2개).
- 폴백: 타임아웃·오류 시 고정 안내 문구 반환 + 로그 (FUC-W-CALLBACK-001 ②). 재시도 없음(10초 제한).
- 최근 대화: 같은 날짜·같은 모드(`routine_item_id` 동일)의 `chat_messages` 최근 6개만 넣는다.

### ~~S3 일반 모드 (하단 탭)~~
- 구현(09-22, 팀원 `ea80650`, 원격 기준): `POST /chat/messages`가 AI 답 생성·저장, 끼니 항목 확인(`validate_meal_item`), 모드별 이력, 일반 모드 규칙. 프론트도 실제 API에 연결(비식사 단어 필터는 실서버 모드에서 끔). 로컬에서 따로 만든 S3·S4 코드(`GET /chat/context` 등)는 원격과 겹쳐 버렸다(규칙 14).
- 하는 일: 기존 `POST /chat/messages`의 고정 문구를 S1+S2 결과로 바꾼다.
- 대상 질의: 4종 가이드 내용 설명, 앱 기능 사용법, 음식·생활 질의 (첨부 2 "마라탕 먹어도 될까요?").
- 금지: 루틴 변경. 메뉴를 바꿔 달라고 하면 "식사 가이드의 AI 재조정에서 바꿀 수 있어요" + `식사 가이드 보기` 버튼 (FUC-W-CHAT-003 ①).
- 가사·건강·수면 변경 요청은 §0.2대로 "아직 지원하지 않아요" + 해당 가이드 보기 버튼. 식사 모드에서도 같다.
- 첫 인사: 현재 임신 주차를 안내하는 고정 템플릿. LLM 호출 안 함.

### S4 식사 모드 시작 (챗봇이 먼저 말하기)
- 상태(09-22): 일부. 끼니 항목 확인은 팀원 `ea80650`에 있고, 첫 질문은 프론트 고정 문구(`meal_chat_controller.dart`). 서버 배너·빠른 답 API는 없다(필요하면 다시 결정).
- 하는 일: 식사 가이드 배너 탭 시 배너("아침 메뉴를 다시 고르는 중")와 챗봇 첫 질문을 돌려준다.
- 첫 질문은 고정 템플릿("아침 메뉴, 어떤 점이 고민이세요?") + 빠른 답 버튼(`속이 좀 메슥거려요` 등). LLM 호출 안 함.
- 엔드포인트: `POST /chat/sessions/meal` 입력 `routine_item_id` → 출력 `banner`, `opening_message`. (신규 1개)

### ~~S5 식사 메모리 + 재추천 카드~~
- 구현(09-22, 커밋 전): `backend/app/domains/chat/meal_memory.py`(메모리 1~3 읽기·지시문·금지어 검사), `service.py` 식사 모드 분기, `responder.py` `MEAL_REPLY_SCHEMA`(카드 없으면 null). 카드 저장은 **B안: `chat_messages.recommendation jsonb` 칸 신설**(migration `20260922000000`, 실DB 적용은 사용자가 SQL Editor에서). 금지 재료 카드는 버리고 문장도 고정 문구. 테스트 `backend/tests/test_chat_meal.py` 6개.
- 09-22 실호출 후 수정: 추천이 오늘 점심·저녁 메뉴를 그대로 가져와서, 지시문에 "[오늘 4종 가이드]의 meal은 선택지가 아니다, 겹치지 않는 새 메뉴"를 추가. 재확인 1회: "바나나 감자 찜"(새 메뉴), $0.0018, 4.54초.
- 09-22 결정(대화 기억): LLM 이력 = **같은 날짜 대화 전체(모드 무관) 최근 20개**, 이전 추천 카드는 `[추천: 메뉴명]`으로 붙여 반복 추천 방지. 화면 목록은 모드별 유지.
- 하는 일: 식사 모드에서만 아래 메모리를 컨텍스트에 추가하고, 답에 **새 추천 카드**를 붙인다.
- 식사 메모리 4종:

| # | 메모리 | 출처 | 쓰는 이유 |
|---|---|---|---|
| 1 | 보던 끼니 카드 (메뉴·이유·영양 태그·조심할 것) | `routine_items.payload` (`routine_item_id`) | "무엇을 다시 고르는지" 재설명 없이 시작 |
| 2 | 확정 규칙 (금지·제한 재료) | `rules.apply_rules(facts)` | 알레르기·임당 등 절대 조건. AI 판단 대상 아님 |
| 3 | 과거 메뉴 거절·교체 이력 최근 10건 | `recommendation_feedback` (`meal_*`) | 싫어한 메뉴 반복 추천 방지 |
| 4 | 이 끼니 대화 이력 | `chat_messages` (같은 `routine_item_id`) | "냄새가 부담" 같은 방금 한 말 반영 |

- 식사 모드 응답 스키마 = 공통 + `recommendation`(`title`, `reason`, `nutritionTags`, `cautions`). 모양은 웬즈데이 `_MEAL_ITEM.payload`와 같게 맞춘다 → 사용자가 선택할 때 프론트가 변환 없이 기존 Care API로 보낼 수 있다.
- 검증: 추천에 금지 재료가 들어가면 버린다. 웬즈데이 `service._banned_words` 재사용.
- 저장: ~~`suggested_actions` jsonb에 같이 넣는다~~ → 09-22 B안으로 변경. 전용 칸 `chat_messages.recommendation`에 저장한다.

### ~~S6 이걸로 할게요 / 다른 메뉴 보기~~
- 구현(09-22, 커밋 전): 백엔드는 카드가 있으면 버튼 2개를 고정으로 붙이는 것까지. 버튼 동작은 프론트 몫이라 `docs/api.md` '챗봇' 절에 계약으로 적었다. 카드가 Care API 입력(`RoutineItemUpdateInput`)에 그대로 들어가는지 테스트로 확인.
- 챗봇은 추천까지만 한다. 두 버튼 모두 **챗봇 API가 루틴·피드백을 쓰지 않는다**.
- `이걸로 할게요`: 사용자가 직접 식단을 바꾸는 동작이다. 프론트가 기존 Care API `PUT /care/routine-items/{id}`(`feedback_kind=meal_replace`, `payload`=추천 카드)를 호출한다 (`backend/app/api/v1/care.py`, Care 소유). 챗봇 쪽 신규 엔드포인트 없음.
- `다른 메뉴 보기`: 같은 조건으로 S5를 다시 호출한다 = `POST /chat/messages`를 한 번 더 보낸다. 신규 엔드포인트 없음. 이미 보여준 추천은 이 끼니 대화 이력(식사 메모리 4)에 있으므로 반복하지 않는다.
- 대화 원문은 Daily 리포트에 넣지 않는다. 챗봇 대화는 conversation history(FUC-W-CHAT-004 ①)로만 저장하고, routine event(②)는 만들지 않는다.

- 09-22 추가: 식사 가이드 화면의 '다른 메뉴 보기'가 끼니당 메뉴 1개라 넘어가지 않던 문제 → `POST /chat/meal-alternative`(S5 식사 메모리 재사용, 저장 없음) + 프론트 `fetchAlternative` 연결(사용자 승인으로 규칙 6 예외). 실호출 2회 3.00초·2.74초, 고구마죽 → 고구마 닭가슴살 샐러드.

### S7 계약·테스트
- `docs/api.md`에 S3~S6 요청·응답 추가 (프론트 전달용, 규칙 6).
- `docs/api.md`에 프론트 요청 사항 함께 적기 (`frontend/`는 수정하지 않는다):
  1. 식사 가이드 진입 시 보던 끼니의 `routine_items.id`를 챗 화면에 넘기고 메시지마다 `routine_item_id`로 보낸다. 가짜 데이터 기준 메뉴는 쓰지 않는다.
  2. 하단 탭 진입은 `routine_item_id` 없이 일반 모드로 시작한다. 아침 메뉴 재조정 배너·첫 인사를 쓰지 않는다.
  3. 실제 서버 모드에서는 `_isDeferredRoutineRequest` 필터를 끄고 모든 메시지를 `/chat`으로 보낸다. 미리보기 모드에서는 유지해도 된다.
  4. `suggested_actions`의 가이드 보기 버튼은 해당 가이드 경로로 이동한다.
  5. "이걸로 할게요"는 기존 Care API `PUT /care/routine-items/{id}`(`meal_replace`)를 호출한다. 앱 안 임시 저장소만 바꾸지 않는다. "다른 메뉴 보기"는 `POST /chat/messages` 재호출.
- 테스트: 기존 `backend/tests/test_chat.py`에 모드 분기·폴백·금지 재료 차단 3건 추가.

### S8 챗봇 컨디션 수정 + 백그라운드 루틴 재생성
- 구현(09-23): 챗봇 Structured Outputs에 `condition_update`를 추가한다. 명시적 1~5 값만 수정 후보로 만들고, 모호한 표현은 값을 다시 묻는다. `mood`는 기존 결정대로 제외한다.
- 사용자 확인 전에는 저장하지 않는다. assistant 메시지의 `routine_update`가 `awaiting_confirmation` 상태와 수정 후보를 보관한다.
- `POST /chat/messages/{message_id}/routine-update` 확인 요청은 `queued`로 즉시 반환한다. FastAPI 백그라운드 작업이 Care 컨디션을 병합 저장한 뒤 기존 `RoutineService.generate_today()`를 호출한다.
- 상태는 `GET /chat/messages/{message_id}/routine-update`로 조회한다. `queued`·`running` 중에도 일반 `POST /chat/messages`를 막지 않는다.
- 프론트는 확인 카드와 진행 상태를 별도로 표시하고 2초 간격으로 상태를 확인한다. 채팅 입력의 `responding` 상태와 루틴 작업 상태를 분리한다.
- 실패하면 컨디션 저장 사실을 숨기지 않고 재시도를 제공한다. 기존 웬즈데이의 부분 재생성·폴백·가족 알림 흐름을 재사용한다.
- 저장: 신규 테이블 없이 `chat_messages.routine_update jsonb`를 사용하고 assistant 메시지 id를 작업 id로 쓴다.

## 3. 공통 규칙
1. 의료 판단·진단을 하지 않는다. 위험 신호(출혈·심한 복통 등)는 "병원에 바로 문의" 고정 문구.
2. LLM에는 NFR-014 허용 키만 넘긴다. 이름·이메일·키 금지 (`inputs.py` 머리 주석과 동일).
3. 대화 원문은 남편에게 노출하지 않는다 (`chat_messages` RLS 주석).
4. 챗봇은 메뉴·가사·건강·수면 루틴을 직접 바꾸지 않는다. 단, S8에서 사용자가 확인한 오늘 컨디션 변경은 기존 웬즈데이 재생성 흐름을 호출한다. 식사 모드는 추천만 하고, 식단 변경은 사용자가 기존 Care API로 직접 한다 (S6).
5. 모델·타임아웃은 `Settings`(`llm_model`) 값을 그대로 쓴다. 챗봇 전용 설정을 만들지 않는다.
6. 가사·건강·수면 루틴 변경은 어느 모드에서도 하지 않는다 (§0.2, 범위 제외).

## 4. 영향 범위 / 되돌리는 법
| S | 바뀌는 곳 | 되돌리는 법 |
|---|---|---|
| S1~S3 | `backend/app/domains/chat/**`, `api/v1/chat.py` | 해당 파일 `git checkout` → 고정 문구 응답으로 복귀 |
| S4 | `GET /chat/context`·`GET /chat/messages`에 `routine_item_id` 쿼리 추가 (신규 엔드포인트 없음) | `git checkout`으로 S3 상태 복귀 |
| S6 | 백엔드 변경 없음 (기존 Care API 사용) | 해당 없음 |
| S8 | `domains/chat/**`, `api/v1/chat.py`, `api/v1/routine.py`, 프론트 챗 화면·서비스 | 해당 파일 복구 후 `chat_messages.routine_update` 컬럼 제거 |
| DB | migration `20260922000000_chat_messages_recommendation.sql` (칸 1개 추가, S5) | `alter table public.chat_messages drop column if exists recommendation;` |
| DB(S8) | migration `20260923140000_chat_routine_update.sql` | `alter table public.chat_messages drop column if exists routine_update;` |

## 5. 비용
| 구분 | 값 | 비고 |
|---|---|---|
| 추정 | 메시지 1건 약 $0.0015 (입력 ~2,500토큰 + 출력 ~300토큰, gpt-4.1-mini) | 식사 모드는 메모리로 입력 +500토큰 정도 |
| 실측 | 09-22 S3 일반 모드 2회 합계 $0.0026 (입력 5,857 / 출력 157 / 임베딩 30토큰) = 1건 약 $0.0013. 응답 3.64초·2.62초 | testwife 오늘 날짜(팀원 합의), 만든 `chat_messages` 4행 삭제·0행 복구 확인 |
| 실측 (S5) | 09-22 식사 모드 2회 합계 $0.0033 (입력 7,034 / 출력 322 / 임베딩 22토큰) = 1건 약 $0.0017. 응답 3.77초·2.91초. 카드·버튼 정상, 알레르기(우유·계란) 반영, 두 번째 추천이 첫 번째와 다름 | testwife 오늘, 팀원이 만든 아침 항목을 읽기만 함. 만든 `chat_messages` 4행 삭제·12행 복구 확인 |

## 6. 가정 (아니면 말해달라)
1. 챗봇 도메인(`domains/chat/**`)을 이번에 우리가 맡는다. 파일 머리 주석상 원래 소유는 Developer B.
2. 첨부 2의 `대체 메뉴 추천` 버튼(일반 모드)은 **텍스트로 대안만 알려주고 선택 버튼은 없다**. 추천 카드와 `이걸로 할게요`는 식사 모드에서만.
3. 챗봇은 `routine_items`·`recommendation_feedback`에 쓰지 않고 읽기만 한다. 쓰는 테이블은 `chat_messages` 하나.
4. 식사 모드 첫 질문·빠른 답 버튼은 고정 템플릿이다 (LLM 비용·지연 없음).
5. "변경 요청 미지원"은 가사·건강·수면에 해당한다. 식사 가이드에서 들어오면 메뉴 재추천은 지원하되, 교체는 사용자가 직접 한다 (FUC-W-MEAL-003).
