"""관절 각도 계산 및 유효 프레임 판별.

각도는 2D(픽셀)와 3D(world) 두 방식으로 함께 계산한다.
2D는 카메라를 정면으로 향한 동작에 약하고(깊이 정보 없음),
3D는 추정값이라 흔들릴 수 있어 어느 쪽을 쓸지는 실측으로 정한다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import yaml

from .pose_extractor import (
    LEFT_ANKLE,
    LEFT_HIP,
    LEFT_KNEE,
    LEFT_SHOULDER,
    RIGHT_ANKLE,
    RIGHT_HIP,
    RIGHT_KNEE,
    RIGHT_SHOULDER,
    PoseResult,
)

CONFIG_PATH = Path(__file__).resolve().parent / "config.yaml"

# 자세 판정에 반드시 실제로 보여야 하는 관절
REQUIRED_LANDMARKS = {
    LEFT_SHOULDER: "left_shoulder",
    RIGHT_SHOULDER: "right_shoulder",
    LEFT_HIP: "left_hip",
    RIGHT_HIP: "right_hip",
    LEFT_KNEE: "left_knee",
    RIGHT_KNEE: "right_knee",
    LEFT_ANKLE: "left_ankle",
    RIGHT_ANKLE: "right_ankle",
}


def _load_settings() -> dict:
    if not CONFIG_PATH.exists():
        return {}
    return yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8")) or {}


_SETTINGS = _load_settings()
MIN_VISIBILITY: float = (_SETTINGS.get("features") or {}).get("min_visibility", 0.6)
SMOOTHING_ALPHA: float = (_SETTINGS.get("features") or {}).get("smoothing_alpha", 0.3)


def angle_between(v1: np.ndarray, v2: np.ndarray) -> float:
    """두 벡터 사이 각도(도)."""
    n1, n2 = np.linalg.norm(v1), np.linalg.norm(v2)
    if n1 == 0 or n2 == 0:
        return float("nan")
    cosine = np.clip(np.dot(v1, v2) / (n1 * n2), -1.0, 1.0)
    return float(np.degrees(np.arccos(cosine)))


def three_point_angle(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """b를 꼭짓점으로 하는 a-b-c 사이각(도). 다리가 곧게 펴지면 180에 가깝다."""
    return angle_between(a - b, c - b)


@dataclass
class FrameFeatures:
    """한 프레임에서 계산한 자세 피처."""

    valid: bool
    reason: str = ""
    # 몸통이 수직에서 벗어난 각도. 곧게 서면 0에 가깝고 숙일수록 커진다.
    trunk_flexion_2d: float = float("nan")
    trunk_flexion_3d: float = float("nan")
    # 무릎 사이각. 곧게 펴면 180에 가깝고 앉으면 작아진다.
    left_knee_2d: float = float("nan")
    right_knee_2d: float = float("nan")
    left_knee_3d: float = float("nan")
    right_knee_3d: float = float("nan")
    # 좌우 비대칭
    shoulder_tilt: float = float("nan")
    hip_tilt: float = float("nan")
    knee_diff_3d: float = float("nan")
    low_visibility: list[str] = field(default_factory=list)

    @property
    def knee_mean_3d(self) -> float:
        return float(np.nanmean([self.left_knee_3d, self.right_knee_3d]))


def check_visibility(pose: PoseResult, threshold: float = MIN_VISIBILITY) -> list[str]:
    """기준 미달인 관절 이름 목록을 돌려준다. 비어 있으면 판정 가능."""
    return [
        name
        for idx, name in REQUIRED_LANDMARKS.items()
        if pose.visibility[idx] < threshold
    ]


def compute_features(pose: PoseResult, threshold: float = MIN_VISIBILITY) -> FrameFeatures:
    """landmark에서 각도 피처를 계산한다. 가시성 미달이면 계산하지 않는다."""
    low = check_visibility(pose, threshold)
    if low:
        return FrameFeatures(
            valid=False,
            reason=f"가시성 미달 관절 {len(low)}개",
            low_visibility=low,
        )

    px, world = pose.pixel_xy, pose.world_xyz

    # 몸통 축: 골반 중점 → 어깨 중점
    hip_mid_2d = (px[LEFT_HIP] + px[RIGHT_HIP]) / 2
    sh_mid_2d = (px[LEFT_SHOULDER] + px[RIGHT_SHOULDER]) / 2
    hip_mid_3d = (world[LEFT_HIP] + world[RIGHT_HIP]) / 2
    sh_mid_3d = (world[LEFT_SHOULDER] + world[RIGHT_SHOULDER]) / 2

    # 이미지/월드 좌표 모두 y축이 아래로 향하므로 '위'는 -y 방향이다.
    up_2d = np.array([0.0, -1.0])
    up_3d = np.array([0.0, -1.0, 0.0])

    shoulder_vec = px[RIGHT_SHOULDER] - px[LEFT_SHOULDER]
    hip_vec = px[RIGHT_HIP] - px[LEFT_HIP]
    horizontal = np.array([1.0, 0.0])

    left_knee_3d = three_point_angle(world[LEFT_HIP], world[LEFT_KNEE], world[LEFT_ANKLE])
    right_knee_3d = three_point_angle(world[RIGHT_HIP], world[RIGHT_KNEE], world[RIGHT_ANKLE])

    return FrameFeatures(
        valid=True,
        trunk_flexion_2d=angle_between(sh_mid_2d - hip_mid_2d, up_2d),
        trunk_flexion_3d=angle_between(sh_mid_3d - hip_mid_3d, up_3d),
        left_knee_2d=three_point_angle(px[LEFT_HIP], px[LEFT_KNEE], px[LEFT_ANKLE]),
        right_knee_2d=three_point_angle(px[RIGHT_HIP], px[RIGHT_KNEE], px[RIGHT_ANKLE]),
        left_knee_3d=left_knee_3d,
        right_knee_3d=right_knee_3d,
        shoulder_tilt=min(angle_between(shoulder_vec, horizontal),
                          angle_between(-shoulder_vec, horizontal)),
        hip_tilt=min(angle_between(hip_vec, horizontal),
                     angle_between(-hip_vec, horizontal)),
        knee_diff_3d=abs(left_knee_3d - right_knee_3d),
    )


class EmaSmoother:
    """지수이동평균 평활화. landmark 떨림이 반복 횟수 오계수로 이어지는 것을 막는다."""

    def __init__(self, alpha: float = SMOOTHING_ALPHA):
        self.alpha = alpha
        self._state: dict[str, float] = {}

    def update(self, key: str, value: float) -> float:
        if value is None or np.isnan(value):
            return self._state.get(key, float("nan"))
        previous = self._state.get(key)
        smoothed = value if previous is None else self.alpha * value + (1 - self.alpha) * previous
        self._state[key] = smoothed
        return smoothed

    def get(self, key: str) -> float:
        return self._state.get(key, float("nan"))

    def reset(self) -> None:
        self._state.clear()
