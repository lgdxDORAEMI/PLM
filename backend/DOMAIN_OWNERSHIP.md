# Backend Domain Ownership

## 목적

세 명의 Backend 개발자가 같은 Router나 Service 파일을 동시에 수정하지 않도록 작업 경계를 고정한다. API 요청·응답은 `schemas.py`, 비즈니스 규칙은 `service.py`, 저장소 계약은 `repository.py`, 임시 구현은 `stub_repository.py`에 둔다.

기능 판단의 Source of Truth는 다음 문서만 사용한다.

1. `docs/requirements/아내_화면설계서.pdf`
2. `docs/requirements/남편_화면설계서.pdf`
3. `docs/requirements/03_유스케이스명세서.md`
4. `docs/requirements/04_1_기능요구사항명세서.md`
5. `docs/requirements/04_2_비기능요구사항명세서.md`

## 개발자별 소유 경계

| 담당 | 도메인 | 소유 파일 | 주요 FUC |
|---|---|---|---|
| Backend A | Account | `app/domains/account/**`, `app/api/v1/account.py` | FUC-B-ENTRY-001, FUC-W-PROFILE-001~009, FUC-W-INVITE-001~002, FUC-H-INVITE-001 |
| Backend B | Care | `app/domains/care/**`, `app/api/v1/care.py` | FUC-W-COND-001~004, FUC-W-TASK-001, FUC-W-RECORD-001, FUC-W-REPORT-001~002, FUC-B-CAL-001 |
| Backend C | Family | `app/domains/family/**`, `app/api/v1/family.py` | FUC-W-HOUSE-003, FUC-W-RECORD-002, FUC-H-REPORT-001, FUC-H-NOTI-001~002, FUC-H-REQUEST-001~003, FUC-B-MOTION-001 |

`app/services/routine/**`, `app/api/v1/routine.py`, `app/services/movement/**`, `app/api/v1/movement.py`, `backend/models/**`는 보호 영역이다. Care와 Family가 해당 기능을 필요로 하면 새 Service/Repository port 또는 query adapter를 추가한다.

## 구현 순서

```text
Schema contract
→ Router
→ Service Protocol
→ Repository Protocol
→ Stub Repository
→ Supabase/외부 시스템 Adapter
```

- Router는 인증과 HTTP 오류 변환만 담당한다.
- Service는 FastAPI와 Supabase를 import하지 않는다.
- Repository 구현을 바꿔도 Schema와 URL은 유지한다.
- Stub은 프로세스 메모리 전용이며 서버 재시작 시 초기화된다.
- Stub 전용 상태 주입 함수는 공개 API로 노출하지 않는다.

## 현재 교체 지점

| Stub | 실제 구현 시 교체 대상 |
|---|---|
| `StubAccountRepository` | Supabase 사용자 역할, Profile 완료 여부, Partner invitation/link adapter |
| `StubCareRepository` | 컨디션·실행 기록·날짜당 단일 Daily report·Calendar query adapter |
| `StubFamilyRepository` | Partner link, household request, notification, morning report, motion consent adapter |

## 권한 및 공유 범위

- 모든 API는 Supabase Bearer token을 요구한다.
- 남편에게 공유 가능한 데이터는 오전 리포트, Daily 리포트, 가사 요청, 홈캠 공유 정보, 캘린더 기록뿐이다.
- Profile 원본, 컨디션 원본, AI 대화 원문을 Family 응답 Schema에 넣지 않는다.
- 가사 요청 상태 변경은 새 알림을 만들지 않는다.
- 모션 OFF는 신규 수집만 중지하며 기존 기록을 삭제하지 않는다.
- 모션 동의 철회는 동의와 수집을 모두 끄지만 기존 로그 삭제 API를 제공하지 않는다.

## TBD

- `FUC-H-INVITE-001`: 화면·인증 복귀 계약은 여전히 미확정이지만, 수락 Router(`POST /account/partner-invitations/{token}/accept`)는 STEP 13에서 이미 추가됐다(API 계약만 구현, 화면 연동은 보류). 2026-09-20 팀 결정: 실사용 연동은 이 Router 경로 대신 `partner_links`를 운영자가 수동으로 미리 삽입하는 방식으로 진행한다.
- Account Stub의 기본 역할은 로컬 계약 확인을 위해 Wife다. 실제 adapter에서는 인증 사용자 역할과 서비스 가입 상태를 조회해야 한다.
- ~~Calendar의 4단계 컨디션 지수 계산식~~ — 2026-09-22 팀 결정으로 확정(mood 제외, 경계값 2/3/4 유지, 가중치 미도입). Motion 감지 임계값은 최신 문서에서 수치가 확정되지 않았다. Stub은 계산 알고리즘을 확정하지 않는다.
- Motion WebSocket 연결 전에 동의·수집 설정을 검사하는 adapter 연결은 보호된 `movement.py` 변경이 필요하므로 별도 합의 후 진행한다.
