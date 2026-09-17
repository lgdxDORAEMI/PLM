# 화면 구현 상태 V2

작성일: 2026-09-17  
범위: 역할별 신규 화면설계서와 DB 문서, `docs/requirements/renew/`, `ROUTE_MAP_V2.md`, `USER_ROLE_FLOW_V2.md`, `SCREEN_CHANGE_IMPACT_V2.md`를 기준으로 한 Flutter 구현 상태.

## 1. 판정 기준

- **완료**: 신규 화면 구조와 필수 상태·이동을 현재 Mock/service abstraction으로 확인할 수 있음
- **일부 완료**: 화면과 주요 동작은 있으나 실제 API·장치 또는 문서의 미확정 항목이 남음
- **Placeholder**: Route는 연결했으나 신규 설계의 상세 UI가 확정되지 않아 임시 안내만 제공
- **삭제 후보 반영**: 과거 UI가 신규 문서의 금지·제외 항목과 충돌해 제거함

백엔드 API와 DB는 수정하지 않았다. 화면 데이터는 기존 Controller → Service → Mock 구조를 유지했다.

## 2. 화면별 상태

| 화면 ID | 화면 | 상태 | 구현 내용과 남은 작업 |
|---|---|---|---|
| `B-ENTRY-001` | 공통 진입 | 일부 완료 | `auth`와 `activeRole`을 분리하고 아내 프로필 완료 여부에 따라 최초 단계/홈으로 분기. 실제 ThinQ session adapter는 미연결 |
| `W-PROFILE-001~006` | 프로필 6단계 | 완료 | 예정일/LMP, 생년월일, 신장·임신 전 체중, 초산/경산, 단태/다태, 알레르기, 주의 진단 입력. 아내 DB 문서의 생선류·땅콩·대두를 추가 |
| `W-PROFILE-007` | 입력 내용 확인 | 완료 | 행별 수정, 최초 완료 후 초대 이동, 수정 저장 후 요약 복귀. 수정 중 뒤로가면 snapshot으로 복원 |
| `W-INVITE-001` | 남편 초대 | 일부 완료 | 링크 표시·복사·OS 공유 문구를 제거하고 ThinQ 알림 발송 흐름으로 교체. 발송은 기존 Mock service이며 실제 ThinQ 연동 필요 |
| `W-HOME-001` | 아내 홈 | 완료 | 컨디션 미입력 CTA, 입력 후 4개 가이드, 수정, 일정 마치기, loading/fallback 상태 유지 |
| `W-COND-001` | 오늘 컨디션 | 완료 | 입덧·통증 부위·피로·기분 입력과 create/edit 이동 유지 |
| `W-TASK-001` | 예정 활동 | 완료 | 9종 선택·직접 추가·미선택 진행 구조 유지 |
| `W-CALLBACK-001` | AI 생성 실패 | 완료 | 저장된 입력 유지 안내, 재시도와 기본 루틴 CTA의 전체 화면을 추가하고 홈 fallback에서 연결 |
| `W-MEAL-001/002` | 식사 목록·상세 | 일부 완료 | 끼니 목록, 추천 상세, 이유·영양·주의·잔여 허용량, 수락/거절/공유 Mock 유지. 상세 URL은 현재 화면 내부 상태를 재사용 |
| `W-CHAT-001` | 식사 재조정 챗봇 | 완료 | 하단 탭 진입과 식사 상세 진입을 구분하고 선택 끼니 context·추천 시작값을 전달 |
| `W-CHAT-002` | 전체 루틴 대화 | Phase 2 | 식사 외 요청에는 지원 범위 안내만 표시 |
| `W-HOUSE-001` | 가사 가이드 | 일부 완료 | 직접/가전/가족 3분류, 공유 선택, 요청 상태, 전송 실패 상태 유지. 실제 가전 실행은 Phase 2 |
| `W-HOUSE-003-1` | 요청 전송 완료 팝업 | 완료 | 선택 수, 수신 위치, 반영 상태 안내 dialog |
| `W-HEALTH-001/002` | 건강 가이드·완료 | 완료 | 부위 우선순위, 대표/보조 활동, 안전 안내, 활동 완료 체크 |
| `W-SLEEP-001` | 수면 가이드 | 완료 | 피로·통증 근거, 권장 취침 시간, 환경 5종, 수면 팁 |
| `W-SLEEP-002` | 환경 설정 | 완료 | 항목별 bottom sheet와 적용/취소/뒤로 닫기. 전체 가전 실행은 비활성 Phase 2 |
| `W-REPORT-001` | Daily 리포트 | 일부 완료 | 루틴·가전·가족 집계, 저장/공유, empty/loading/error. 근거 없는 관절 횟수·최다 관절 UI를 제거하고 홈캠 주의 문구로 교체. 저장 후 홈 초기화 경로 반영 |
| `W-REPORT-001-1` | 공유 완료 팝업 | 완료 | 날짜와 남편 캘린더 조회 위치 안내 |
| `W-MENU-001` | 전역 메뉴 | 완료 | 프로필, 연결 전 초대/연결 후 상태, 설정, 약관. 초대 설명을 ThinQ 알림 기준으로 수정 |
| `B-CAL-001` | 아내 캘린더 | 일부 완료 | 월/날짜 선택, 컨디션·루틴·가전·가족 분담, Daily 리포트 이동. 근거 없는 관절 수치를 홈캠 주의 문구로 교체 |
| `B-MOTION-001` | 아내 실시간 | 일부 완료 | 하단 탭, 감지 ON/OFF, 오늘 누적 시간, 오늘 로그, 상세 안내. 과거 로그·확인 상태·자정 초기화·기기 개발 정보 삭제. 실제 홈카메라 API는 미연결 |
| 설정 | 메뉴 진입 | Placeholder | 신규 문서에 설정 상세 항목이 없어 기존 준비 중 화면 유지 |

## 3. 공통 UI와 이동

- 아내 하단 메뉴는 `홈 / 실시간 / 챗봇 / 캘린더` 네 개이며 각 탭의 root로 stack을 초기화한다.
- 아내 전역 화면은 기존 `TopAppBar`, `WifeNavigationScaffold`, `AppButton`, `AppCard`, `InfoBanner`, `AppDialog`, `AppBottomSheet`를 재사용한다.
- 프로필 최초 등록은 `W-PROFILE-001 → ... → W-PROFILE-007 → W-INVITE-001 → W-HOME-001` 순서다.
- 일반 상세 뒤로가기는 직전 화면, 프로필 onboarding은 이전 단계, summary 수정은 변경 폐기 후 summary, modal/sheet는 부모 화면 유지 규칙을 적용한다.
- 로딩·오류·빈 상태는 기존 `AppLoadingState`, `AppErrorState`, `AppEmptyState`를 사용한다.

## 4. 삭제 후보 반영

- 남편 초대 화면의 링크 문자열, 복사 버튼, 링크 공유·설치 안내를 제거했다.
- 실시간 화면의 Phase 2 미리보기 문구, 확인/확인함 상태, 어제 로그, 자정 초기화 문구, 개발용 기기 상태를 제거했다.
- Daily 리포트와 캘린더의 관절 부담 초과 횟수·최다 부담 관절 표시를 제거했다.
- 가전 자동 실행과 전체 수면 루틴은 Phase 2이므로 실행 가능한 기능처럼 표시하지 않는다.

## 5. 데이터 연결 상태

| 데이터 | 현재 연결 |
|---|---|
| 프로필 | `ProfileDraft`와 Web persistence. 생년월일 포함, ThinQ/Profile API 대체 가능 |
| 당일 컨디션·루틴 | `TodayCareStore`, `PlannedActivityStore`, `RoutineService`/`MockRoutineService` |
| 식사·챗봇 | `MealSelectionStore`, `MealService`, `MealChatService`; 진입 끼니 context 전달 |
| 가사 요청 | `HouseholdRequestService`; 남편 요청 Mock store와 상태 공유 |
| 수면 | `SleepService`와 환경 setting controller |
| 캘린더·리포트 | `RecordService`와 날짜별 Mock record. 영구 저장/API는 미연결 |
| 실시간 | `RealtimeAlertController`의 오늘 Mock 로그와 수집 상태. 영상·장치 API는 미연결 |

## 6. 확인 필요

- 건강 완료 체크의 최종 위치와 해제 정책은 화면설계서에 상세가 없다.
- 수동 진입한 남편 초대 화면에서 `초대장 보내기`/`나중에` 후 메뉴와 홈 중 어느 곳으로 돌아갈지 문서 간 충돌이 있다. 현재는 navigation history가 있으면 이전 화면으로 복귀한다.
- Meal 상세의 URL 복구 시 선택 끼니를 별도 route state로 완전히 복원하는 계약은 추가 확정이 필요하다.
- 홈캠 임계값·보관 기간·동의 철회와 실제 장치 상태는 API/정책 확정이 필요하다.
- 설정 상세 화면은 신규 문서에 정의되지 않았다.

## 7. 검증 범위

- `dart format`: 수정·추가 Dart 33개 파일에 실행, 성공(8개 파일 포맷 변경).
- `flutter analyze --no-pub`: Flutter batch가 Dart 분석기를 시작하지 못하고 `cmd.exe`에서 대기해 중단. Flutter tool snapshot 직접 실행은 SDK cache lock 쓰기 권한이 필요했으며 권한 요청이 거부됨. `FLUTTER_ALREADY_LOCKED=true` 실행도 분석 하위 프로세스 생성이 운영 환경에서 거부되어 완료하지 못함.
- 관련 테스트: 같은 Flutter tool/하위 프로세스 권한 제약으로 실행하지 못함.
- `git diff --check`: 성공.
- 전체 `flutter test`와 `flutter build`: 실행하지 않음.

## 8. 남편 화면 구현 상태

| 화면 ID | 화면 | 상태 | 구현 내용과 남은 작업 |
|---|---|---|---|
| `B-ENTRY-001` | 남편 최초 진입 | 일부 완료 | 연결 전 `/entry`에서 `초대가 필요합니다` 안내. 별도 가입 절차 없음. 실제 ThinQ session adapter는 미연결 |
| ThinQ 초대 handoff | 초대 수락·연결 | 일부 완료 | 토큰 유효성 검증 후 남편 연결 상태·`activeRole=husband`를 반영하고 남편 캘린더로 stack 초기화. 만료·사용됨·중복 연결 오류 안내. 실제 ThinQ API는 Mock |
| `B-CAL-001` | 남편 Home/캘린더 | 완료 | 캘린더를 남편 기본 Home으로 사용. 알림, 날짜별 리포트, 오늘 날짜에서만 실시간 진입. 프로필과 Bottom Navigation 없음 |
| `H-REPORT-001` | 오전 컨디션 리포트 | 완료 | 임신 주차, 컨디션 요약, 예정 활동, 식사·가사·건강·수면 4가이드 요약의 조회 전용 화면 |
| Daily 리포트 조회 | 캘린더 날짜 리포트 | 일부 완료 | `/husband/report/daily/:date`에서 남편용 읽기 전용 리포트 shell을 재사용. 별도 화면 ID와 최종 상세 디자인은 지정 자료에 없어 확인 필요 |
| `H-NOTI-001` | 통합 알림 | 완료 | 오전 리포트·가사 요청·루틴 변경 3종, 읽음 상태, 모두 읽음, 대상 화면 이동. ThinQ 초대 알림은 목록에서 제외 |
| `H-REQUEST-001` | 가사 요청 확인·수행 | 완료 | 요청 이유·항목·보조 정보 표시. 항목별 버튼을 제거하고 요청 카드 전체를 `미확인 → 확인 → 완료` 단일 상태로 전환 |
| 완료 확인 Modal | 요청 완료 확인 | 완료 | 요청 카드 전체 완료 여부를 확인하며 취소 시 현재 요청 화면 유지 |
| `H-REQUEST-002` | 요청 완료 결과 | 완료 | Dialog를 제거하고 독립 전체 화면으로 구현. 아내 화면·캘린더·Daily 리포트 반영 위치와 가족 분담 건수 표시 |
| `B-MOTION-001` | 남편 실시간 | 일부 완료 | 남편 캘린더에서 오늘 선택 시에만 진입, Bottom Navigation 없음, 수집 토글은 읽기 전용. 실제 홈카메라 API는 미연결 |
| 사용자 전환 | 역할 전환 기반 | 일부 완료 | 명시적 전환 명령 시 `activeRole=husband`, 남편 캘린더로 이동하고 이전 stack 제거. 전환 UI와 한 계정의 양 역할 권한은 요구사항에서 미정 |

### 남편 데이터 연결

- 오전 리포트와 캘린더는 기존 `RecordService`/`MockRecordService`를 조회 전용으로 사용한다.
- 알림은 `PartnerNotificationStore`에 오전 리포트·가사 요청·루틴 변경 3종과 읽음 상태를 보존한다.
- 가사 요청은 `PartnerRequestStore`의 요청 카드 단위 상태를 사용한다. 요청 항목 수와 카드 상태를 아내 가사 화면·캘린더 집계와 공유한다.
- 초대 연결은 기존 `InvitationService` abstraction과 `PartnerConnectionStore`, 분리된 `AuthSessionStore`/`ActiveRoleStore`를 사용한다.

### 남편 화면 제외 항목

- 남편 Bottom Navigation, 프로필, 온보딩, 챗봇, 가이드 편집 화면은 만들지 않았다.
- 남편 PLM 알림함에 ThinQ 초대 알림을 추가하지 않았다.
- 아내 프로필 원본·컨디션 입력 원본·AI 대화 원문을 남편 화면에 노출하지 않았다.

### 남편 화면 검증 결과

- `dart format`: 남편 화면과 관련 테스트 파일에 실행, 성공.
- `flutter analyze --no-pub`: 최초 8개 항목을 발견해 미사용 코드·import와 lint를 수정한 뒤 재실행, **No issues found**.
- `flutter test test/features/partner/partner_flows_test.dart --no-pub`: Flutter test runner가 시작되지 않은 채 `cmd.exe`에서 장시간 대기해 사용자 중단. 남은 테스트용 `cmd` 프로세스는 종료함. 테스트 성공 여부는 확인되지 않음.
- 전체 `flutter test`와 `flutter build`: 실행하지 않음.
