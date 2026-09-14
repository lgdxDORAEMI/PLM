"""한글 경로 대응 이미지 입출력.

OpenCV의 imread/imwrite는 Windows에서 비ASCII 경로를 처리하지 못한다.
프로젝트 경로에 한글이 포함되어 있으므로 이 래퍼를 통해 읽고 쓴다.
"""

from pathlib import Path

import cv2
import numpy as np


def imread(path: str | Path) -> np.ndarray | None:
    """BGR 이미지를 읽는다. 실패 시 None."""
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def imwrite(path: str | Path, image: np.ndarray) -> bool:
    """BGR 이미지를 저장한다."""
    path = Path(path)
    success, buffer = cv2.imencode(path.suffix, image)
    if not success:
        return False
    buffer.tofile(str(path))
    return True
