"""카메라 입력 추상화.

OS별로 OpenCV 백엔드가 다르므로 실행 환경에 맞춰 자동 선택한다.
카메라 스펙은 config.yaml에서 코드 수정 없이 변경할 수 있다.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import cv2
import numpy as np
import yaml

CONFIG_PATH = (
    Path(__file__).resolve().parents[2]
    / "backend" / "app" / "services" / "movement" / "config.yaml"
)

_BACKENDS = {
    "auto": None,
    "any": cv2.CAP_ANY,
    "dshow": cv2.CAP_DSHOW,
    "msmf": cv2.CAP_MSMF,
    "avfoundation": cv2.CAP_AVFOUNDATION,
    "v4l2": cv2.CAP_V4L2,
}


def _default_backend() -> int:
    if sys.platform.startswith("win"):
        return cv2.CAP_DSHOW
    if sys.platform == "darwin":
        return cv2.CAP_AVFOUNDATION
    if sys.platform.startswith("linux"):
        return cv2.CAP_V4L2
    return cv2.CAP_ANY


@dataclass
class CameraConfig:
    index: int = 0
    width: int = 1280
    height: int = 720
    fps: int = 30
    backend: str = "auto"
    mirror_preview: bool = True

    @classmethod
    def load(cls, path: Path = CONFIG_PATH) -> "CameraConfig":
        if not path.exists():
            return cls()
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        return cls(**(data.get("camera") or {}))

    def resolve_backend(self) -> int:
        key = self.backend.lower()
        if key not in _BACKENDS:
            raise ValueError(f"알 수 없는 backend: {self.backend} (가능: {', '.join(_BACKENDS)})")
        return _BACKENDS[key] if _BACKENDS[key] is not None else _default_backend()


class CameraSource:
    """웹캠 프레임 공급자. 향후 IP캠/다중 카메라로 교체해도 인터페이스는 유지한다."""

    def __init__(self, config: CameraConfig | None = None):
        self.config = config or CameraConfig.load()
        self._capture: cv2.VideoCapture | None = None

    def open(self) -> "CameraSource":
        capture = cv2.VideoCapture(self.config.index, self.config.resolve_backend())
        if not capture.isOpened():
            raise RuntimeError(
                f"카메라를 열 수 없습니다 (index={self.config.index}, "
                f"backend={self.config.backend}). config.yaml에서 index를 바꿔보세요."
            )

        capture.set(cv2.CAP_PROP_FRAME_WIDTH, self.config.width)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self.config.height)
        capture.set(cv2.CAP_PROP_FPS, self.config.fps)
        self._capture = capture
        return self

    @property
    def actual_spec(self) -> dict:
        """카메라가 실제로 적용한 값. 요청값과 다를 수 있다."""
        if self._capture is None:
            raise RuntimeError("카메라가 열려 있지 않습니다.")
        return {
            "width": int(self._capture.get(cv2.CAP_PROP_FRAME_WIDTH)),
            "height": int(self._capture.get(cv2.CAP_PROP_FRAME_HEIGHT)),
            "fps": self._capture.get(cv2.CAP_PROP_FPS),
        }

    def frames(self) -> Iterator[np.ndarray]:
        """BGR 프레임을 순차적으로 내보낸다(원본, 반전 없음)."""
        if self._capture is None:
            raise RuntimeError("open()을 먼저 호출하세요.")
        while True:
            ok, frame = self._capture.read()
            if not ok:
                break
            yield frame

    def close(self) -> None:
        if self._capture is not None:
            self._capture.release()
            self._capture = None

    def __enter__(self) -> "CameraSource":
        return self.open()

    def __exit__(self, *exc_info) -> None:
        self.close()
