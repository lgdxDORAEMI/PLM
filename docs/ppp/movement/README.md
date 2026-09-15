# 모션 데모 배치 및 테스트

사용자가 제공한 `motion_demo.zip`의 파일을 기존 PLM 구조에 맞게 분산 배치했습니다.
ZIP 내부 계획서는 원본 참고 문서이며, 실제 배치와 실행 상태는 이 문서를 기준으로 확인합니다.

## 원본 파일 → 프로젝트 위치

| ZIP 내부 위치 (`motion_demo/` 기준) | 프로젝트 위치 | 역할 |
| --- | --- | --- |
| `app/pose_extractor.py` | `backend/app/services/movement/pose_extractor.py` | 이미지/영상에서 33개 landmark 추출 |
| `app/features.py` | `backend/app/services/movement/features.py` | 관절 각도, 가시성 검사, EMA 평활화 |
| `app/calibration.py` | `backend/app/services/movement/calibration.py` | 개인 기준선 측정 및 편차 계산 |
| `app/rule_engine.py` | `backend/app/services/movement/rule_engine.py` | 자세 상태, 지속시간, 반복과 이벤트 판정 |
| `app/rules.yaml` | `backend/app/services/movement/rules.yaml` | 데모용 자세 및 시간 임계값 |
| `config.yaml` | `backend/app/services/movement/config.yaml` | 카메라 및 피처/캘리브레이션 설정 |
| `app/camera.py` | `tools/motion_demo/camera.py` | 실행 PC의 OpenCV 카메라 입력 |
| `app/imageio_utils.py` | `backend/app/utils/imageio_utils.py` | 한글 경로 이미지 입출력 |
| `models/pose_landmarker_full.task` | `backend/models/pose_landmarker_full.task` | 모델 바이너리 |
| `docs/구현계획서_v3.md` | `docs/movement/구현계획서_v3.md` | 원본 계획서 |
| `docs/임신_주수별_관절부담과_자세분석_연구보고서.docx` | `docs/movement/임신_주수별_관절부담과_자세분석_연구보고서.docx` | 원본 연구보고서 |
| `requirements.txt` | `docs/movement/demo-requirements.txt` | 원본 의존성 기록, 설치에 사용하지 않음 |

추가 작성한 파일:

- `backend/app/services/movement/__init__.py`: 분석 패키지
- `backend/requirements-motion.txt`: 기존 Backend 요구사항 + 선택 의존성 `PyYAML==6.0.3`
- `tools/motion_demo/__main__.py`: 카메라 없는 호환성 검사와 PC 웹캠 데모 실행 진입점
- `tools/motion_demo/test_motion.py`: 각도, 캘리브레이션, 추적 끊김, 세션 분리 등의 테스트
- `frontend/lib/features/movement/README.md`: 향후 Flutter 카메라/UI 구현 위치 안내

## 기존 설정과의 관계

기존 `backend/requirements.txt`, Backend 환경변수, CORS, API, Flutter 의존성 및 화면은 유지했습니다.
`mediapipe_service.py`의 기존 API용 확장 지점도 유지하며 이번 분석 모듈을 자동으로 호출하지 않습니다.
분석 모듈은 직접 import할 수 있고 독립 도구에서 사용합니다. HTTP 분석 API는 아직 없습니다.
모션용 패키지는 별도 가상환경에 설치하므로 기본 Backend 개발에는 추가 설치가 필요 없습니다.

ZIP의 원본 MediaPipe `1.0.1`과 numpy `2.4.6` 고정값은 적용하지 않았습니다.
현재 Backend의 MediaPipe `0.10.35` 및 OpenCV 간접 의존성을 그대로 사용하며 PyYAML만 선택 추가합니다.
`opencv-python`과 `opencv-contrib-python`은 같은 `cv2`를 제공하므로 중복 설치하지 않습니다.
카메라 설정과 규칙은 YAML로 읽으며 비밀 환경변수는 추가하지 않았습니다.

## 이동 과정에서 수정한 내용

- 분석 모듈 import를 패키지 상대 import로 변경했습니다.
- 모델 경로를 `backend/models/`, 설정 경로를 분석 패키지의 YAML 위치로 수정했습니다.
- 캘리브레이션 저장 기본 경로를 Git에서 제외되는 `backend/.local/motion_demo/`로 옮겼습니다.
  독립 웹캠 도구는 기준선을 메모리에만 보관하며 자동 저장하지 않습니다.
- 원본 규칙 엔진의 `시작 시각 0`이 거짓으로 처리되어 숙임 횟수가 누락되는 부분을 수정했습니다.
- 원본 문서, 모델과 데모 판정 임계값은 변경하지 않았습니다.

## 설치 및 검증 (PLM 루트에서)

Windows PowerShell:

```powershell
python -m venv tools/motion_demo/.venv
.\tools\motion_demo\.venv\Scripts\python.exe -m pip install -r backend/requirements-motion.txt
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo --check
.\tools\motion_demo\.venv\Scripts\python.exe -m unittest tools.motion_demo.test_motion -v
```

설치된 Python의 `ensurepip`가 실패하면 아래 대체 명령을 사용합니다. 시스템 pip가 필요합니다.

```powershell
py -m venv --without-pip tools/motion_demo/.venv
py -m pip --python tools/motion_demo/.venv/Scripts/python.exe install pip -r backend/requirements-motion.txt
```

macOS/Linux:

```sh
python3 -m venv tools/motion_demo/.venv
tools/motion_demo/.venv/bin/python -m pip install -r backend/requirements-motion.txt
tools/motion_demo/.venv/bin/python -m tools.motion_demo --check
tools/motion_demo/.venv/bin/python -m unittest tools.motion_demo.test_motion -v
```

`--check`는 카메라를 열지 않고, 실제 모델을 로드해 IMAGE/VIDEO 모드에서 빈 이미지 추론을 확인합니다.
사람이 없는 결과를 확인하는 호환성 검사이며 인식 정확도나 실제 FPS 검증은 아닙니다.

## PC 웹캠 실행

```powershell
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo
# 다른 PC 카메라 선택
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo --camera-index 1
```

시작 시 편안하게 서서 전신이 보이도록 개인 기준선을 측정합니다.
유효 프레임 부족 시 종료됩니다. 이후 미리보기에는 landmark 점과 자세/부담 라벨이 표시됩니다.
`q` 또는 Esc로 종료합니다. 미리보기 반전은 모델 입력에 적용하지 않습니다.
카메라 사용 권한과 실제 GUI 세션이 필요합니다. 다른 앱이 카메라를 점유하면 종료 후 다시 시도합니다.
이 도구는 사용자가 실행할 때만 카메라를 열고 영상과 결과를 자동 저장하거나 서버로 전송하지 않습니다.

## 웹 및 모바일 적용 범위

현재는 Python 실행 PC의 카메라만 지원합니다. Python 서버의 `VideoCapture(0)`은 접속 사용자의 카메라를 열지 않습니다.
Flutter의 `features/movement`에서 브라우저 촬영을 구현하고 프레임 전송 API를 추가해야 웹/모바일에서 사용할 수 있습니다.
모바일 카메라 테스트에는 HTTPS와 브라우저 카메라 권한이 필요합니다.
휴대폰의 localhost는 휴대폰 자신이므로 별도 접근 가능한 Backend 주소가 필요합니다.
현재 localhost CORS 설정을 유지했으므로 HTTPS 테스트 origin을 명시적으로 허용하거나 같은 origin의 프록시가 필요합니다.
근거: [MDN getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia).

규칙 엔진, 평활화와 기준선은 한 사용자 세션당 별도 인스턴스를 사용해야 합니다.
캘리브레이션 파일은 데모용이며 운영에서는 사용자별 저장과 인증을 별도로 설계해야 합니다.
원본의 시간/각도 임계값은 데모 값으로, 사용자 대상 정확도 검증은 아직 수행하지 않았습니다.

## 배치 후 검증 결과

- 별도 모션 가상환경에서 `--check`의 실제 모델 IMAGE/VIDEO 추론 성공
- 모션 로직 테스트 7개 통과
- 기존 Backend API/CORS 테스트 2개 통과
- 기본 Backend 및 모션 환경의 `pip check` 통과
- 모델, 문서, 원본 의존성 기록, YAML, 이미지 입출력 코드 총 7개 파일의 원본 대비 해시 일치
- 모델 실행 시 feedback tensor 기능을 비활성화한다는 경고가 출력되지만 추론은 성공

실제 웹캠 촬영, 사용자 자세 인식 정확도/FPS, 모바일 카메라는 아직 검증하지 않았습니다.
모델, 코드와 문서는 Git에 포함할 수 있으며 테스트 가상환경과 개인 캘리브레이션 데이터는 제외됩니다.
