# PC 웹캠 모션 테스트

모델과 분석 모듈을 사용하는 독립 개발 도구입니다. PLM 루트에서 실행합니다.
전체 파일 이동 목록, 의존성 설치와 실행 방법은 [모션 통합 문서](../../docs/movement/README.md)에 있습니다.

```powershell
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo --check
.\tools\motion_demo\.venv\Scripts\python.exe -m tools.motion_demo
```

`--check`는 카메라를 열지 않습니다. 기본 실행은 이 Python 프로세스가 실행되는 PC의 웹캠을 엽니다.
모바일 카메라와 Flutter 화면에는 연결되어 있지 않습니다.
