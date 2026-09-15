# API

개발 기본 주소: `http://localhost:8000`

| Method | Path | 200 응답 | 설명 |
| --- | --- | --- | --- |
| GET | / | `{"message":"PLM API","status":"ok"}` | API 기본 상태 |
| GET | /health | `{"status":"healthy"}` | 프로세스 상태 |

`/health`는 외부 서비스나 DB 연결 상태를 확인하지 않습니다.
Swagger UI: `/docs`, OpenAPI schema: `/openapi.json`.
현재 상태 확인 API는 인증 없이 호출할 수 있습니다. 기능 API는 향후 `app/api/v1`에 추가합니다.

## 임산부 프로필 (W-PROFILE-001)

모든 요청에 `Authorization: Bearer <Supabase access token>`이 필요합니다.

| Method | Path | 성공 응답 | 설명 |
| --- | --- | --- | --- |
| POST | /api/v1/profile | 201 프로필 + 임신 주수 | 프로필 입력 및 저장 (사용자당 1개) |
| GET | /api/v1/profile/me | 200 프로필 + 임신 주수 | 내 프로필 조회 |

요청 본문 (POST)

| 필드 | 타입 | 규칙 |
| --- | --- | --- |
| due_date | `YYYY-MM-DD` | 오늘(KST) 기준 14일 전 ~ 280일 후 |
| age | 정수 | 15 ~ 55 |
| height_cm | 숫자 | 100 ~ 250, 소수 첫째 자리까지 저장 |
| pre_pregnancy_weight_kg | 숫자 | 30 ~ 200, 소수 첫째 자리까지 저장 |
| parity | 문자열 | `primiparous`(초산) / `multiparous`(경산) |
| fetus_count | 문자열 | `singleton`(단태아) / `multiple`(다태아) |

응답 본문은 요청 필드에 `pregnancy_weeks`, `pregnancy_days`를 더한 형태입니다.
임신 주수는 저장하지 않고 조회 시점(KST)에 `출산예정일 - 280일`을 시작일로 계산합니다.

| 상태 코드 | 의미 |
| --- | --- |
| 401 | 토큰 없음 또는 유효하지 않음 |
| 404 | 등록된 프로필 없음 (GET) |
| 409 | 이미 등록된 프로필 있음 (POST) |
| 422 | 입력 검증 실패. `detail[].loc`의 마지막 값이 필드명 |
| 503 | Supabase 설정 누락 또는 연결 실패 |

로컬 Flutter Web의 임의 개발 포트를 허용합니다.
허용 origin은 `http://localhost[:port]`, `http://127.0.0.1[:port]`입니다.
Authorization, Content-Type 헤더와 GET/POST/PUT/PATCH/DELETE/OPTIONS 메서드를 허용합니다.
