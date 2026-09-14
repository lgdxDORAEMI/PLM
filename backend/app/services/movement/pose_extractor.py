"""MediaPipe Pose landmark 추출 모듈."""

from dataclasses import dataclass
from pathlib import Path

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python.vision import (
    PoseLandmarker,
    PoseLandmarkerOptions,
    RunningMode,
)

MODEL_PATH = Path(__file__).resolve().parents[3] / "models" / "pose_landmarker_full.task"

LANDMARK_NAMES = [
    "nose", "left_eye_inner", "left_eye", "left_eye_outer",
    "right_eye_inner", "right_eye", "right_eye_outer",
    "left_ear", "right_ear", "mouth_left", "mouth_right",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_pinky", "right_pinky",
    "left_index", "right_index", "left_thumb", "right_thumb",
    "left_hip", "right_hip", "left_knee", "right_knee",
    "left_ankle", "right_ankle", "left_heel", "right_heel",
    "left_foot_index", "right_foot_index",
]

# 부담 자세 판정에 사용하는 주요 landmark 인덱스
LEFT_SHOULDER, RIGHT_SHOULDER = 11, 12
LEFT_HIP, RIGHT_HIP = 23, 24
LEFT_KNEE, RIGHT_KNEE = 25, 26
LEFT_ANKLE, RIGHT_ANKLE = 27, 28


@dataclass
class PoseResult:
    """한 프레임의 자세 추정 결과."""

    pixel_xy: np.ndarray      # (33, 2) 이미지 픽셀 좌표
    visibility: np.ndarray    # (33,) 가시성 점수
    world_xyz: np.ndarray     # (33, 3) 골반 중심 원점 3D 좌표(미터)

    @property
    def detected(self) -> bool:
        return self.pixel_xy.size > 0


class PoseExtractor:
    """이미지/프레임에서 33개 landmark를 추출한다."""

    def __init__(self, running_mode: RunningMode = RunningMode.IMAGE):
        # 경로를 넘기면 MediaPipe의 C++ 로더가 한글 경로를 열지 못하므로 바이트로 전달한다.
        options = PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_buffer=MODEL_PATH.read_bytes()),
            running_mode=running_mode,
            num_poses=1,
        )
        self._running_mode = running_mode
        self._landmarker = PoseLandmarker.create_from_options(options)

    def extract(self, rgb_image: np.ndarray, timestamp_ms: int | None = None) -> PoseResult | None:
        """RGB 이미지에서 landmark를 추출한다. 사람이 없으면 None.

        VIDEO 모드로 생성했다면 timestamp_ms를 반드시 넘겨야 하며,
        MediaPipe가 이전 프레임 결과를 추적에 활용해 속도와 안정성이 올라간다.
        """
        height, width = rgb_image.shape[:2]
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_image)

        if self._running_mode == RunningMode.VIDEO:
            if timestamp_ms is None:
                raise ValueError("VIDEO 모드에서는 timestamp_ms가 필요합니다.")
            result = self._landmarker.detect_for_video(mp_image, timestamp_ms)
        else:
            result = self._landmarker.detect(mp_image)

        if not result.pose_landmarks:
            return None

        landmarks = result.pose_landmarks[0]
        world_landmarks = result.pose_world_landmarks[0]

        return PoseResult(
            pixel_xy=np.array([[lm.x * width, lm.y * height] for lm in landmarks]),
            visibility=np.array([lm.visibility for lm in landmarks]),
            world_xyz=np.array([[lm.x, lm.y, lm.z] for lm in world_landmarks]),
        )

    def close(self) -> None:
        self._landmarker.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        self.close()
