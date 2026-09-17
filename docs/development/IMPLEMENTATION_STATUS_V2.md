# 화면 구현 상태 V2

작성일: 2026-09-18

## 판정 기준

요구사항 renew 문서, 아내·남편 화면설계서, 아내·남편 DB 스키마와 이번 작업의 V2 문서만 기준으로 한다.

- **완료**: 설계 화면과 핵심 이동 및 상태가 구현됨
- **일부 완료**: UI와 이동은 구현됐으나 실제 API가 Mock 또는 local 상태임
- **Placeholder**: 설계 상세가 없거나 외부 연동 전 안내 화면임

## 아내 화면

| 범위 | 상태 | 구현 내용 |
|---|---|---|
| 공통 진입·프로필 1~7단계 | 일부 완료 | 인증·프로필 상태별 분기, 입력·요약·수정 구현. ThinQ 세션/API 미연결 |
| 남편 초대 | 일부 완료 | 발송·건너뛰기·메뉴 복귀 구현. 실제 ThinQ 알림은 Mock |
| Home·컨디션·예정 활동·AI 실패 | 완료 | 입력, 수정, 루틴 생성, fallback 이동 연결 |
| 식사 목록·상세·재조정 채팅 | 일부 완료 | 끼니별 상세 URL과 새로고침 복원, 추천 교체·공유·채팅 구현. AI/API는 Mock |
| 가사·건강·수면 | 일부 완료 | 카드, 완료/요청 Dialog, 수면 Bottom Sheet 구현. 가전 실행은 Phase 2 |
| Daily Report·공유 Dialog | 일부 완료 | 날짜별 조회·공유 완료 안내 구현. 저장 API는 Mock |
| Menu·Calendar·실시간 | 일부 완료 | 모든 경로 연결. 실시간 장치/영상 API는 Mock |
| 설정 | Placeholder | 신규 문서에 상세 UI가 없어 준비 화면 유지 |

아내 Bottom Navigation은 **홈 / 실시간 / 채팅 / 캘린더** 4개다.

## 남편 화면

| 범위 | 상태 | 구현 내용 |
|---|---|---|
| 최초 진입·초대 수락 | 일부 완료 | 연결 전 안내, token 검증, 연결 완료 분기 구현. ThinQ API는 Mock |
| Calendar Home | 완료 | 남편 기본 Home, 날짜별 기록과 상세 이동 구현 |
| 오전 컨디션 Report | 완료 | 컨디션·예정 활동·4개 생활 요약 표시 |
| Notification | 일부 완료 | 읽음 상태와 Report/Request 이동 구현. push API 미연결 |
| Request·완료 확인·결과 | 일부 완료 | 요청 단위 완료, 확인 Dialog, 결과 Fullscreen 구현. 저장 API는 local |
| 실시간 | 일부 완료 | 오늘 날짜 진입과 읽기 화면 구현. 장치/영상 API 미연결 |
| Daily Report | 일부 완료 | 경로와 조회 화면 연결. 남편 전용 상세 설계는 확인 필요 |

남편 화면설계서에는 Bottom Navigation이 없으므로 구현하지 않았다.

## Route와 사용자 전환

- auth/session과 activeRole을 분리했다.
- activeRole은 wife 또는 husband이며 계정별 Web 저장소에서 복원한다.
- 명시적 전환은 권한과 남편 연결 상태를 확인한 뒤 stack을 제거하고 아내 Home 또는 남편 Calendar Home으로 이동한다.
- URL 직접 접근만으로 역할을 바꾸거나 로그인 세션을 생성하지 않는다.
- 다른 역할 URL은 현재 역할 Home으로 보정하고 최초 진입에서는 브라우저 주소도 교체한다.
- 초대 수락은 연결 상태만 갱신하며 인증 계정에 남편 권한을 임의로 추가하지 않는다.
- 미연결 남편은 /entry에서 연결 필요 안내를 본다.

## 데이터 연결 상태

| 데이터 | 현재 연결 |
|---|---|
| 사용자·역할·연결 | AuthSessionStore, ActiveRoleStore, PartnerConnectionStore; ThinQ API 미연결 |
| 아내 프로필 | ProfileStore/ProfileDraft; DB API 미연결 |
| 컨디션·활동·루틴 | local store와 MockRoutineService |
| 식사·채팅 | MealSelectionStore, MealService, MealChatService; AI/API는 Mock |
| 가사 요청 | 아내·남편 공유 요청 store; DB API 미연결 |
| 수면 | SleepService와 local 설정 controller |
| Calendar·Report | RecordService/MockRecordService; 영구 저장 API 미연결 |
| Notification | PartnerNotificationStore; push API 미연결 |
| 실시간 | RealtimeAlertController; 카메라·장치 API 미연결 |

## 삭제·미사용 후보

- features/entry/EntryScreen: 실제 router가 사용하지 않고 route guard가 진입을 처리한다.
- RouteNames.partnerMorningReportPattern, partnerRequestPattern: husband 명칭으로 대체된 호환 별칭이며 직접 참조가 없다.
- 필수 route의 식사 상세 Placeholder는 실제 MealGuideScreen 연결로 제거했다.
- 알 수 없는 URL fallback, 상세 미정 설정, 미연결 남편 안내 Placeholder는 유지한다.

## 확인 필요

- 같은 ThinQ 계정의 아내·남편 권한 정책과 전환 UI 위치
- 초대 화면에서 메뉴로 돌아갈 위치에 대한 문서 간 차이
- 남편 Daily Report의 별도 화면 ID와 상세 디자인
- 설정 상세 화면
- 가전 실행, 영상·이상행동 임계값, 데이터 보관 정책
- 남편 DB 문서의 Report 알림 포함 범위가 중복 서술된 부분

## 최종 검증

- 정적 검토: 전체 diff, route/import/Placeholder, 문서 route 대응, Bottom Navigation, 역할 전환, DB 데이터 연결 확인
- 수동 Smoke Test: Chrome 430×932에서 아내·남편 주요 화면, Back, 새로고침, 직접 URL, 역할별 navigation 확인
- dart format: 수정 Dart·테스트 파일 포맷 완료
- flutter analyze --no-pub: deprecated API 1건을 수정한 뒤 **No issues found**
- flutter test --no-pub: 최초 6건 실패를 실패 파일별로 재현해 역할 세션 초기화와 오래된 assertion을 수정. 마지막 전체 실행 **79개 통과**
- flutter build web --no-pub: **성공**, `build/web` 생성. 미사용 CupertinoIcons font 안내가 있었으나 빌드 결과에는 영향 없음
