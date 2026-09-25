# PLM Frontend

PLM Frontend는 아내와 남편의 생활 루틴·가족 공유 흐름을 제공하는 Flutter Web 앱입니다. 운영 앱은 <https://lgdxdoraemi.github.io/PLM/>에서 실행됩니다.

## 화면과 기능

### 아내

- 프로필과 출산예정일 입력, 임신 주차 표시
- 오늘 컨디션과 예정 활동 입력
- 컨디션 입력 전에도 프로필 기반 주차 안내 표시
- AI 루틴과 식사·가사·건강·수면 상세 가이드, 변경 없는 홈 재진입 시 오늘 루틴 즉시 복원
- 식사 메뉴 수락·거절·대체 추천
- 최근 챗봇 대화 복원, 추천 카드, 컨디션 수정 확인과 루틴 재생성 상태
- 건강 영상 재생과 실행 완료, 수면 환경 설정
- 가사 분담 요청과 확인·완료 상태
- Daily 리포트, 월 기록을 먼저 표시하고 선택 날짜 상세를 독립적으로 갱신하는 캘린더, 오늘 기록 초기화

### 남편

- 연결된 아내의 오전 리포트와 캘린더
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
- Service Role Key, 등록 계정 비밀번호, LLM·ThinQ 비밀값을 Frontend에 넣지 않습니다.

## 로컬 실행

```powershell
flutter pub get
flutter run -d chrome
```

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
- 503: Railway, Supabase, DB 스키마 또는 LLM 연결 확인

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
  --dart-define=API_BASE_URL=https://plm-backend-production-cc76.up.railway.app
```

## GitHub Pages 배포

`.github/workflows/deploy-pages.yml`이 다음 과정을 자동 수행합니다.

1. `frontend/`만 체크아웃
2. Flutter 3.44.4 설치
3. Repository Variables로 `frontend/.env` 생성
4. `/PLM/` base href와 Railway API 주소로 Web 릴리스 빌드
5. `frontend/build/web`만 Pages Artifact로 업로드

필요한 Repository Variables:

```text
API_BASE_URL=https://plm-backend-production-cc76.up.railway.app
SUPABASE_URL=<Supabase Project URL>
SUPABASE_ANON_KEY=<Supabase public anon key>
```

`main`의 `frontend/**` 또는 배포 Workflow 변경이 배포를 시작합니다. 수동 배포는 GitHub Actions의 `Flutter Web GitHub Pages 배포`에서 `Run workflow`를 실행합니다. Flutter Web은 hash routing을 사용하므로 내부 주소는 `/#/wife/home` 형태입니다.

## 배포 확인

- 앱: <https://lgdxdoraemi.github.io/PLM/>
- 브라우저 Network의 API 호스트가 Railway인지 확인
- 오래된 UI가 보이면 강력 새로고침
- Console의 401/403/404/503을 위 연결 기준에 따라 확인

전체 로컬·운영 설정은 [guide.md](../guide.md)를 참고합니다.
