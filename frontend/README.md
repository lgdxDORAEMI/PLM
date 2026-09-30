# PLM Frontend

PLM Frontend는 아내와 남편의 생활 루틴·가족 공유 흐름을 제공하는 Flutter Web 앱입니다. 운영 앱은 <https://lgdxdoraemi.github.io/PLM/>에서 실행됩니다.

## 화면과 기능

### 아내

- 프로필과 출산예정일 입력, 임신 주차 표시
- 오늘 컨디션과 예정 활동 입력
- 컨디션 입력 전에도 프로필 기반 주차 안내 표시
- AI 루틴과 식사·가사·건강·수면 상세 가이드, 변경 없는 홈 재진입 시 메모리 캐시에서 오늘 루틴 즉시 복원
- 식사 메뉴 수락·거절·대체 추천
- 오늘 챗봇 대화 복원, 추천 카드, 컨디션 수정 확인과 루틴 재생성 상태
- 3점 이상 통증 집중 부위별 건강 영상, 다른 부위 영상 선택 조회, 전신 스트레칭 기본 추천과 `활동 완료`·`오늘 안하기` 진행도 반영
- 수면 환경 설정과 연결된 공기청정기 전원·바람세기 실행
- 보유 ThinQ 가전과 빨래·청소·설거지 매칭, 연결 오류 재조회, 가사 분담 요청과 확인·완료 상태
- Daily 리포트, 월별 달력과 기록 날짜를 먼저 표시하고 선택 날짜의 컨디션 7종 점수를 포함한 상세를 독립적으로 갱신하는 캘린더, 오늘 기록 초기화
- 오늘 기록 초기화 후 Entry의 `시작하기`에서 프로필 설정으로 이어지는 재시작 흐름
- 프로필 설정 완료와 배우자 공개를 분리하고, 초대 화면의 `초대하기`를 눌렀을 때만 연결된 남편에게 기록 공개

### 남편

- 연결된 아내의 오전 리포트와 캘린더
- 아내가 `초대하기`를 누르기 전에는 Entry에서 대기하고, 공개 상태가 확인되면 `/husband/calendar`로 자동 이동
- 알림 목록과 읽음 처리
- 가사 요청 상세, 항목별 확인·완료
- 공유 가능한 모션 이벤트와 일일 집계

일반 실시간 화면은 저장된 오늘 모션 이벤트를 조회합니다. 카메라/WebSocket 분석은 `lib/main_movement_debug.dart`를 사용하는 별도 개발 진입점입니다.

## 구조

```text
lib/
├─ core/              # 환경 설정, API 클라이언트
├─ design_system/     # 공통 색상·간격·컴포넌트
├─ features/          # 화면별 model/controller/service/widget
├─ routing/           # 역할별 경로와 세션 상태
├─ shared/            # 공통 상태·표시 컴포넌트
└─ main.dart          # Web 앱 진입점
```

제품 경로는 `Screen → Controller/Store → Service/Repository → ApiClient → Backend`를 사용합니다. Mock Service는 Widget 테스트와 명시적 Preview에서만 사용하며, 실제 API 실패를 Mock 데이터로 감추지 않습니다.

## 상태와 갱신 정책

- 홈 화면은 오늘 루틴을 날짜 단위로 캐시합니다. 일반적인 홈 재진입에서는 기존 결과를 즉시 유지하고, 컨디션 변경·계정 전환 때 캐시를 무효화하며 명시적 갱신은 캐시를 우회합니다.
- 남편 Entry는 계정 bootstrap 상태를 주기적으로 갱신합니다. 목적지가 `husband_invitation_required`인 동안 대기하고, 아내의 `초대하기`로 `husband_calendar`가 반환되면 캘린더 경로로 교체 이동합니다. 프로필 저장 완료만으로는 이 전환이 발생하지 않습니다.
- 루틴 생성은 컨디션/활동 입력 흐름의 명시적 요청에서 수행합니다. 홈 화면의 일반 조회는 기존 루틴을 읽을 뿐 새 루틴을 생성하지 않습니다.
- 캘린더는 월별 기록과 선택 날짜 상세의 로딩·오류 상태를 분리합니다. 월 응답이 오면 달력을 먼저 표시하고, 날짜 상세는 캐시와 요청 번호를 사용해 늦게 도착한 이전 응답이 최신 선택을 덮지 않게 합니다.
- 캘린더 날짜 상세는 통합 API를 우선 사용하고, 통합 API가 없는 Backend에서만 기존 리포트·컨디션 API로 폴백합니다. 기록이 없는 날은 빈 응답으로 구분해 폴백하지 않습니다.
- 홈 첫 진입은 컨디션 응답 하나를 컨디션·할 일이 함께 사용하고, 주차 안내는 루틴 응답에 포함된 값을 씁니다. 루틴이 없거나 안내가 비어 있을 때만 주차 안내를 따로 조회합니다.
- 홈의 네 가이드 조회는 서로 독립이라 함께 보내고, 가사 가이드의 요청 목록은 오늘 날짜만 조회합니다.
- 캘린더 상세의 컨디션은 입덧·허리·골반·다리·손목·피로에 저장된 1~5점을 그대로 표시합니다(기분은 입력하지 않아 표시하지 않음).
- 건강 가이드의 집중 부위 기준은 통증 점수 3점(`보통이에요`) 이상입니다. 집중 부위 카드를 누르면 해당 영상 카드가 활동 영역에 표시되고, 네 통증이 모두 1~2점이면 영상이 연결된 `전신` 활동을 기본 선택합니다. `다른 부위 활동 보기`는 집중 부위를 제외한 조회 전용 선택지입니다. 집중 항목의 `활동 완료`와 왼쪽의 `오늘 안하기`는 취소할 수 없는 최종 상태로 홈 루틴 진행도와 화면 캐시에 즉시 반영되며, 처리 후에도 영상은 다시 열 수 있습니다.

## 환경 설정

```powershell
Copy-Item .env.example .env
```

```dotenv
SUPABASE_URL=<Supabase Project URL>
SUPABASE_ANON_KEY=<Supabase public anon key>
BACKEND_URL=http://localhost:8000
DEMO_EMAIL=
DEMO_PASSWORD=
```

- `SUPABASE_URL`과 `SUPABASE_ANON_KEY`가 모두 있어야 실제 인증·API 모드를 사용합니다.
- 로컬 API 주소는 `.env`의 `BACKEND_URL`을 사용합니다.
- 배포 빌드는 `--dart-define=API_BASE_URL=...` 값을 우선합니다.
- `BACKEND_URL`에는 마지막 `/`를 붙이지 않습니다. `ApiClient`가 `/api/v1/...` 경로를 이어 붙입니다.
- 로컬 Chrome은 `http://localhost:8000`, Android Emulator는 `http://10.0.2.2:8000`, 실제 기기는 같은 네트워크에 있는 PC의 LAN IP를 사용합니다.
- Service Role Key, 등록 계정 비밀번호, LLM·ThinQ 비밀값을 Frontend에 넣지 않습니다.

## 로컬 실행

```powershell
flutter pub get
flutter run -d chrome
```

실행 전에 Backend 연결을 확인합니다.

```powershell
Invoke-RestMethod http://localhost:8000/health
```

정상 응답은 `{"status":"ok"}`입니다. VS Code의 기본 `PLM: Chrome` 설정은 `API_BASE_URL`을 별도로 주입하지 않으므로 `frontend/.env`의 `BACKEND_URL`을 그대로 사용합니다.

로컬 예시 화면만 확인하려면 다음과 같이 실행합니다.

```powershell
flutter run -d chrome --dart-define=PLM_PREVIEW=true
```

사전 등록 계정 자동 진입과 계정 전환은 localhost 또는 Backend의 `FRONTEND_ORIGIN`과 정확히 일치하는 운영 Web Origin에서만 허용됩니다.

## Backend 연결

- REST 기본 주소: `AppConfig.backendUrl`
- API prefix: `/api/v1`
- 인증: Supabase access token을 `Authorization: Bearer ...`로 전달
- 모션 WebSocket: Backend URL에서 `ws://` 또는 `wss://`로 파생
- 404: 오늘 데이터가 아직 없는 정상 빈 상태일 수 있음
- 401: Supabase 세션 확인
- 403: 계정 권한 또는 `FRONTEND_ORIGIN` 확인
- 503: Coolify, Supabase, DB 스키마 또는 LLM 연결 확인

가사 가이드의 `appliance_connection_status`는 다음처럼 처리합니다.

- `connected`: 보유 기기와 빨래·청소·설거지를 매칭합니다.
- `account_mismatch`: 현재 로그인 계정은 서버의 ThinQ PAT 소유 계정이 아닙니다.
- `not_configured`: Backend의 ThinQ 설정이 비어 있거나 Client ID 형식이 잘못됐습니다.
- `auth_error`: PAT 인증 정보를 갱신해야 합니다.
- `timeout`, `error`, `unsupported_country`: 안내와 `가전 다시 확인` 버튼을 표시합니다.

화면별 경로는 [API 문서](../docs/api.md), 연결 상태는 [FE–BE 연결 기록](../docs/FE_BE_CONNECTION_STATUS.md)을 참고합니다.

## 테스트와 빌드

```powershell
flutter analyze
flutter test
flutter build web --release --base-href /PLM/
```

운영 Backend를 지정하는 배포 빌드는 다음 형식입니다.

```powershell
flutter build web --release `
  --base-href /PLM/ `
  --dart-define=API_BASE_URL=https://plm-api.dx6project.site
```

## GitHub Pages 배포

`.github/workflows/deploy-pages.yml`이 다음 과정을 자동 수행합니다.

1. `frontend/`만 체크아웃
2. Flutter 3.44.4 설치
3. Repository Variables로 `frontend/.env` 생성
4. `/PLM/` base href와 Coolify API 주소로 Web 릴리스 빌드
5. `frontend/build/web`만 Pages Artifact로 업로드

필요한 Repository Variables:

```text
API_BASE_URL=https://plm-api.dx6project.site
SUPABASE_URL=<Supabase Project URL>
SUPABASE_ANON_KEY=<Supabase public anon key>
```

`main`의 `frontend/**` 또는 배포 Workflow 변경이 배포를 시작합니다. 수동 배포는 GitHub Actions의 `Flutter Web GitHub Pages 배포`에서 `Run workflow`를 실행합니다. Flutter Web은 hash routing을 사용하므로 내부 주소는 `/#/wife/home` 형태입니다.

이 Workflow는 Frontend만 배포합니다. `backend/**` 변경은 Coolify의 GitHub Webhook과 `backend/Dockerfile` 배포 상태를 별도로 확인해야 합니다.

## 배포 확인

- 앱: <https://lgdxdoraemi.github.io/PLM/>
- 브라우저 Network의 API 호스트가 `plm-api.dx6project.site`인지 확인
- 오래된 UI가 보이면 강력 새로고침하고 GitHub Actions의 배포 `head_sha`가 `origin/main`과 같은지 확인
- UI는 최신인데 API 동작이 이전 버전이면 Coolify의 실행 커밋과 재배포 로그 확인
- Console의 401/403/404/503을 위 연결 기준에 따라 확인

전체 로컬·운영 설정은 [guide.md](../guide.md)를 참고합니다.
