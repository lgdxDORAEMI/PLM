# PLM 라우팅 구조 V2

작성일: 2026-09-17  
상태: 구현 전 설계안. 아래 URL은 구현을 위한 제안이며 화면설계서의 URL 요구사항은 아니다.

## 1. 기준과 경계

요구사항은 `docs/requirements/renew/` 전체, `아내_화면설계서.pdf`, `남편_화면설계서.pdf`, `아내 화면 DB스키마.pdf`, `남편 화면 DB 스키마.pdf`, `docs/development/SCREEN_CHANGE_IMPACT_V2.md`만 사용했다. 화면 ID는 `renew/04_1_기능요구사항명세서.md`의 매핑을 따른다. 현재 Flutter 라우터는 현 구현 확인에만 사용한다. ThinQ 로그인, 배너·메뉴, 초대 알림은 호스트 서비스 영역이다.

`/wife`, `/husband`는 **현재 표시 역할**의 URL 구역이다. 역할별 화면과 데이터 권한은 같은 계정에 양쪽 역할 접근권이 있다는 뜻이 아니다. 지정 자료는 아내와 남편이 각자의 ThinQ 계정으로 들어오고 초대로 연결된다고 설명한다. 앱 안의 전환 버튼·두 역할을 가진 한 계정의 권한 모델은 **확인 필요**다. 사용자가 요청한 전환 계약은 아래처럼 명시하되, 권한이 확인되지 않은 전환은 허용하지 않는다.

## 2. 상태와 최초 진입

| 상태 | 의미와 출처 | 라우팅에 쓰는 값 |
|---|---|---|
| `auth` | ThinQ에서 인증한 계정과 세션. 로그인 UI는 ThinQ 영역 | `accountId`, 인증 유효 여부 |
| `activeRole` | 지금 PLM에 표시할 역할. `wife` 또는 `husband` | 역할 URL·쉘·뒤로가기 기준 |
| 역할 접근권 | 인증 계정이 아내 프로필의 소유자인지, 유효하게 연결된 남편 계정인지 검증한 결과 | 허용된 역할 집합. 두 역할 동시 보유 가능 여부는 **확인 필요** |
| 아내 프로필 상태 | 최종 저장 완료 여부 | 최초 1/6 또는 아내 홈 |
| 남편 연결 상태 | 초대 토큰 검증·연동 완료 여부 | 초대 필요 안내 또는 남편 캘린더 |

`auth`와 `activeRole`은 별도 상태다. ThinQ 계정이 로그인되어도 역할은 자동으로 양쪽 모두 허용되지 않는다. 첫 진입의 `B-ENTRY-001`은 ThinQ 홈 배너 또는 메뉴에서 시작한다. 인증/역할 접근권/프로필·연결 상태를 조회한 뒤 다음처럼 분기한다.

| 진입 상황 | 목적지 |
|---|---|
| 아내 접근권, 프로필 미완료 | `/wife/profile/onboarding/1` (`W-PROFILE-001`) |
| 아내 접근권, 프로필 완료 | `/wife/home` (`W-HOME-001`) |
| 남편, ThinQ 초대 알림 선택·토큰 검증·연동 성공 | `/husband/calendar` (`B-CAL-001`) |
| 남편 접근 시 연동 전·초대 전 | `/entry`의 **초대가 필요합니다** 안내 상태 (`B-ENTRY-001`). 별도 남편 가입 화면 없음 |
| 이미 연결된 남편 | `/husband/calendar` (`B-CAL-001`) |

로그인이 없는 상태의 인증 이동, ThinQ 복귀 URL, 서비스 해지 뒤 직접 URL 접근의 세부 처리는 ThinQ 계약 **확인 필요**다. 앱은 로그인 없는 PLM 콘텐츠를 표시하지 않는다. 상태 조회 실패에는 신규 화면을 만들지 않고 진입 화면에서 오류·재시도를 표시한다(UC17).

## 3. Route Tree

```text
/entry                                      B-ENTRY-001: ThinQ 진입 상태 확인·초대 필요 안내
/invite/accept                              ThinQ 초대 알림 handoff: 토큰 검증·연동, 성공 시 남편 홈
/role/switch/:targetRole                    화면 없는 내부 전환 명령; targetRole = wife | husband

/wife                                       아내 접근권 + activeRole=wife
  /home                                     W-HOME-001, 하단 탭 루트
  /live                                     B-MOTION-001, 하단 탭 루트
  /chat                                     W-CHAT-001, 하단 탭 루트
  /calendar                                 B-CAL-001, 하단 탭 루트
  /profile/onboarding/:step                 W-PROFILE-001~006, step=1..6
  /profile/onboarding/summary               W-PROFILE-007
  /profile/edit/:step                       W-PROFILE-001~006, 기존 값 수정
  /profile/edit/summary                     W-PROFILE-007, 수정값 확인
  /invite                                   W-INVITE-001, 미연결일 때만
  /menu                                     W-MENU-001
  /condition                                W-COND-001
  /tasks                                    W-TASK-001
  /routine/fallback                         W-CALLBACK-001
  /meal                                     W-MEAL-001
  /meal/:mealKey                            W-MEAL-002, 끼니별 상세
  /house                                    W-HOUSE-001
  /health                                   W-HEALTH-001; W-HEALTH-002는 화면 내 완료 요소
  /sleep                                    W-SLEEP-001
  /report/:date                             W-REPORT-001, 날짜별 Daily 리포트

/husband                                    연결된 남편 접근권 + activeRole=husband
  /calendar                                 B-CAL-001, 남편 홈
  /live                                     B-MOTION-001, 오늘만 조회
  /notifications                            H-NOTI-001
  /report/morning/:date                     H-REPORT-001
  /report/daily/:date                       B-CAL-001의 '이 날 리포트 보기' 대상
  /requests/:requestId                      H-REQUEST-001
  /requests/:requestId/result               H-REQUEST-002
```

`/husband/report/daily/:date`는 공통 Daily 리포트 데이터의 남편 **조회 전용** 경로다. 남편용 전체 화면의 상세 디자인·고유 화면 ID는 지정 자료에 없어 **확인 필요**다. `W-REPORT-001`의 아내 편집·공유 동작을 남편에게 노출하지 않는다. `/wife/chat`은 탭에서 빈 맥락으로 열고, 식사 상세에서는 끼니·선택 메뉴의 진입 맥락을 전달한다. 이 맥락의 실제 저장 형식은 구현 계약이며 새 화면이 아니다. `W-CHAT-002` 전체 루틴 자유 조정은 Phase 2이므로 별도 MVP route를 만들지 않는다. 설정은 `W-MENU-001`의 진입 항목만 근거가 있고 상세 화면은 미정이므로 route 확정 전 **확인 필요**다.

### 공통 화면과 역할별 접근

`B-CAL-001`과 `B-MOTION-001`은 데이터·화면 개념을 공유하되 `/wife/...`와 `/husband/...`의 역할별 URL을 둔다. 아내 캘린더에는 오늘 실시간 버튼이 필요 없고, 남편 캘린더는 **오늘을 선택했을 때만** 실시간 버튼을 보인다. 남편 실시간은 공유된 오늘 로그의 조회만 가능하다. 아내만 감지 ON/OFF를 조작한다. 과거 홈캠 내용은 캘린더 날짜의 Daily 리포트 주의사항으로 본다.

### 주요 화면 이동

| 출발 | 행동 | 도착 |
|---|---|---|
| `/wife/home` | 컨디션 체크 | `/wife/condition` → `/wife/tasks` → 루틴 생성 후 `/wife/home`; 생성 실패 시 `/wife/routine/fallback`에서 재시도 |
| `/wife/home` | 가이드 선택 | 식사 `/wife/meal`, 가사 `/wife/house`, 건강 `/wife/health`, 수면 `/wife/sleep` |
| `/wife/meal` | 끼니 선택·상세에서 재조정 | `/wife/meal/:mealKey` → 끼니 맥락을 가진 `/wife/chat` |
| `/wife/home` | 오늘의 일정 마치기 | `/wife/report/:date`의 미확정 미리보기; `저장하고 마치기` 후 홈으로 복귀 |
| `/wife/calendar` | 이 날 리포트 보기 | `/wife/report/:date`의 저장된 날짜별 기록 |
| `/husband/calendar` | 알림 아이콘 | `/husband/notifications` → 오전 리포트·가사 요청·변경된 날짜 요약 |
| `/husband/calendar` | 이 날 리포트 보기 | `/husband/report/daily/:date` |
| `/husband/calendar` | 오늘 선택 후 실시간 버튼 | `/husband/live` |
| `/husband/requests/:requestId` | 완료 전 확인 팝업에서 확정 | `/husband/requests/:requestId/result` → 캘린더 |

알림의 오전 리포트는 `/husband/report/morning/:date`, 가사 요청은 `/husband/requests/:requestId`, 루틴 변경은 `/husband/calendar`에서 해당 날짜 요약으로 이동한다. 루틴 변경 후 아내 홈은 같은 루틴의 4가이드를 갱신하며, Daily 리포트 확정 뒤 당일 재체크는 새 루틴을 만든다. 이 상태 구분은 별도 화면 경로가 아닌 데이터로 처리한다.

### 초대와 연결

아내 최초 저장: `/wife/profile/onboarding/summary` → `/wife/invite` → 발송 또는 `나중에` → `/wife/home`. 발송은 ThinQ 알림 요청이며 PLM 알림함 경로가 아니다. 미연결이면 `/wife/menu`에서 `/wife/invite` 재진입이 가능하고, 연결되면 해당 메뉴가 사라진다. 초대 전 아내는 그대로 홈을 사용한다.

남편은 ThinQ 초대 알림을 통해 `/invite/accept` handoff를 시작한다. 토큰은 ThinQ 연동 계약으로 전달하며 URL에 노출하는 형식은 **확인 필요**다. 토큰 만료·재사용·중복 연동·서버 실패는 UC16의 실패 안내·재시도/재초대 요청으로 처리한다. 성공 시 남편 접근권을 다시 조회하고 `/husband/calendar`로 이동한다. 연결되지 않은 남편의 `/husband/*` 직접 접근은 `/entry`의 초대 필요 안내로 보낸다.

수동 초대의 반환 위치는 `renew/03` UC15 기본 흐름·`renew/01_PRD`가 **이전 화면**, UC15 대안 흐름이 **두 버튼 모두 홈**이라고 서로 다르다. 최초 초대는 홈으로 확정하고, 메뉴에서 연 수동 초대의 발송/나중에 반환 지점은 **확인 필요**로 남긴다.

## 4. 사용자 전환 계약

`/role/switch/:targetRole`은 화면을 렌더링하지 않는 내부 명령 route다. 실제 전환 UI의 위치·노출 자체는 **확인 필요**이며, 두 역할 접근권이 확인된 계정에서만 이 명령을 호출할 수 있다.

1. 현재 `auth.accountId`로 `targetRole` 접근권을 재검증한다. `husband`는 연동 완료, `wife`는 해당 계정의 프로필 접근권이 전제다.
2. 허용되면 `activeRole = targetRole`을 세션 상태와 해당 `accountId`에 묶인 지속 저장소에 반영한다. 인증 계정은 그대로 둔다.
3. 이전 역할의 상세·모달·탭 navigation stack을 **초기화**하고 `wife → /wife/home`, `husband → /husband/calendar`로 이동한다. 아내 프로필 미완료라면 최초 진입 규칙에 따라 1/6으로 보낸다.
4. 접근권이 없으면 `activeRole`과 현재 화면을 유지하고 전환 불가를 안내한다. 별도 역할 선택/가입 화면은 만들지 않는다.

URL 직접 접근으로 다른 역할 화면을 요청해도 자동 전환하지 않는다. 현재 `activeRole`과 URL 역할이 다르면 현재 역할 홈으로 보내고, 해당 역할 접근권이 없는 경우에도 콘텐츠를 표시하지 않는다. 명시적 전환 명령만 `activeRole`을 바꿀 수 있다. 한 ThinQ 계정이 양쪽 역할을 실제로 가질 수 있는지, 전환 UI·실패 안내 문구·저장 기간은 **확인 필요**다.

## 5. Bottom Navigation, 전체 화면, 오버레이

| 역할 | 하단 탭 | 이동 규칙 |
|---|---|---|
| 아내 | `홈` `/wife/home` · `실시간` `/wife/live` · `챗봇` `/wife/chat` · `캘린더` `/wife/calendar` | 탭을 누르면 해당 루트로 이동. 직전 상세 history를 쌓지 않음 (`FUC-B-NAV-001`) |
| 남편 | 없음 | `/husband/calendar`가 홈. 알림·리포트·요청은 캘린더에서 열고, 실시간은 캘린더에서 오늘 선택 시 버튼으로만 진입 |

Route Tree의 화면 경로는 각각 전체 화면 destination으로 취급한다. 특히 `W-CALLBACK-001`, 남편 요청 완료 결과 `H-REQUEST-002`, 날짜별 Daily 리포트는 팝업이 아닌 전체 화면이다. 프로필 6단계·요약, 초대, 가이드 상세, 알림·오전 리포트도 전체 화면이다. 아내 탭 루트에서 하단 바를 고정할지 상세에서 노출할지는 설계서의 각 화면 표기를 따른다. 화면별 바 노출이 서로 다른 부분은 **확인 필요**다.

| 현재 전체 화면에 얹는 UI | 처리 |
|---|---|
| `W-SLEEP-002` 수면 환경 항목 설정 | `/wife/sleep` 위 바텀시트. 적용/취소/뒤로 시 시트만 닫음 |
| `W-HOUSE-003-1` 가사 요청 전송 완료 | `/wife/house` 위 팝업 |
| `W-REPORT-001-1` 남편 공유 완료 | `/wife/report/:date` 위 팝업 |
| 남편 가사 요청 완료 전 확인 | `/husband/requests/:requestId` 위 확인 팝업. 확인 후 결과 전체 화면으로 이동 |

오버레이는 URL에 별도 route를 만들지 않는다. 새로고침 시 부모 전체 화면을 복구한다. 남편 요청 결과는 팝업으로 대체하지 않는다.

## 6. 뒤로가기와 새로고침 복구

| 상황 | 동작 |
|---|---|
| 일반 상세 | 실제 직전 PLM 화면으로 복귀 (`FUC-B-NAV-002` A). 직접 URL로 들어와 내부 이력이 없으면 해당 역할 홈으로 복귀 |
| 최초 프로필 설정 | 이전 Step. 최종 저장 전 완전 종료 후에는 1/6부터 재진입 (`FUC-B-NAV-002` B) |
| 프로필 수정 | 저장하지 않은 변경은 폐기하고 입력 확인 `W-PROFILE-007`로 복귀. 행 저장은 같은 요약으로 복귀 (`FUC-B-NAV-002` C) |
| 바텀시트·모달 | 부모 페이지를 유지하고 오버레이만 닫음 (`FUC-B-NAV-002` D) |
| 아내 하단 탭 이동 후 뒤로 | 이전 상세로 돌아가지 않음. 탭 루트에서의 시스템 뒤로/ThinQ 복귀 규칙은 **확인 필요** |
| 역할 전환 후 뒤로 | 이전 역할 스택으로 돌아가지 않음. 대상 역할 홈이 새 루트 |

새로고침 시 ① ThinQ 인증 상태 재확인 ② `accountId`에 묶어 저장한 `activeRole` 복원 ③ 접근권·프로필/연동 상태 재검증 ④ 현재 URL의 역할·route·날짜/요청 ID를 검증한다. 모두 유효하면 동일한 전체 화면 URL과 데이터를 복원한다. URL 역할이 `activeRole`과 다르거나 route/대상 데이터가 유효하지 않으면 현재 역할 홈으로 이동한다. 남편 연동이 해제되었으면 초대 필요 안내로 이동한다. 프로필 미완료는 step URL과 관계없이 1/6으로 이동한다. 오버레이와 임시 입력 draft는 복원하지 않는다. 저장된 `activeRole`이 없을 때는 ThinQ 진입 맥락과 검증된 역할 접근권으로 역할을 정하며, 둘 다 가능한 경우 우선 역할은 **확인 필요**다. 저장 범위·만료 기간과 ThinQ 세션 변경 신호도 **확인 필요**다.

## 7. 구현 순서와 미결정 사항

1. `auth`/역할 접근권/`activeRole` 분리와 진입 guard, 아내 프로필·남편 연동 분기.
2. 아내 4탭 루트와 남편 캘린더 루트, 공통 캘린더·실시간 역할별 권한.
3. 온보딩→초대, ThinQ 초대 수락, 알림→리포트·요청, Daily 리포트 전체 화면 경로.
4. 상세 뒤로가기·모달 처리, 새로고침·직접 URL guard, 전환 명령과 스택 초기화.

**확인 필요:** 한 계정의 양쪽 역할 접근 가능 여부와 전환 UI, 수동 초대 반환 위치, 남편 Daily 리포트 상세 디자인/ID, 탭 루트 시스템 뒤로 동작, 남편 하단 바 그림과 기능 명세 충돌, 남편 실시간 토글 그림과 조회 전용 규칙 충돌, 설정 상세 route. 영향도 문서 §9의 나머지 충돌은 해당 기능 구현 전에 함께 정리한다.
