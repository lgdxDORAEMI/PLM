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
    # 가시성 가중평균 무릎각 (2026-09-15, 측면 자세 대응). 한쪽이 가려지면
    # 보이는 쪽 비중이 자동으로 커진다. compute_features()에서 직접 계산해
    # 채우므로 더 이상 단순 평균 property가 아니다.
    knee_mean_3d: float = float("nan")
    # 좌우 비대칭
    shoulder_tilt: float = float("nan")
    hip_tilt: float = float("nan")
    knee_diff_3d: float = float("nan")
    low_visibility: list[str] = field(default_factory=list)


def check_visibility(pose: PoseResult, threshold: float = MIN_VISIBILITY) -> list[str]:
    """기준 미달인 관절 이름 목록을 돌려준다. 진단/로깅용이며 더 이상 판정
    가능 여부를 좌우하지 않는다 (아래 compute_features 참고)."""
    return [
        name
        for idx, name in REQUIRED_LANDMARKS.items()
        if pose.visibility[idx] < threshold
    ]


def _weighted_pair(value_a: np.ndarray, weight_a: float, value_b: np.ndarray, weight_b: float) -> np.ndarray:
    """가시성 가중평균. 둘 다 가시성이 거의 0이면 계산 불가(NaN)를 돌려준다.

    옆모습처럼 한쪽 관절이 가려지면 그쪽 가시성이 낮게 나오는데, 예전에는
    좌우 8개 관절이 전부 기준(0.6) 이상이어야만 판정했다. 그래서 몸통을
    옆으로 돌리면 반대쪽 어깨/골반/무릎/발목 가시성이 떨어져 통째로
    Unknown이 되는 문제가 있었다(2026-09-15 실기기 테스트로 발견). 판정에
    실제로 쓰는 값(몸통 굴곡각, 무릎각)은 좌우 평균이므로, 안 보이는 쪽을
    완전히 버리는 대신 가시성 비율대로 반영하면 보이는 쪽 위주로 계산되면서
    정면 판정(양쪽 다 잘 보이는 경우)은 기존과 거의 동일하게 유지된다.
    """
    total = weight_a + weight_b
    if total < 1e-6:
        return np.full_like(np.asarray(value_a, dtype=float), np.nan)
    return (value_a * weight_a + value_b * weight_b) / total


def compute_features(pose: PoseResult, threshold: float = MIN_VISIBILITY) -> FrameFeatures:
    """landmark에서 각도 피처를 계산한다.

    좌우 각각의 가시성으로 가중평균해서 계산하므로, 한쪽만 보여도(옆모습 등)
    보이는 쪽 위주로 몸통 굴곡각/무릎각을 낸다. 몸통과 무릎 양쪽 다 전혀
    계산할 수 없을 때만(예: 사람이 없거나 전신이 안 보일 때) 무효 프레임으로
    처리한다.
    """
    px, world = pose.pixel_xy, pose.world_xyz
    vis = pose.visibility

    sh_vis_l, sh_vis_r = float(vis[LEFT_SHOULDER]), float(vis[RIGHT_SHOULDER])
    hip_vis_l, hip_vis_r = float(vis[LEFT_HIP]), float(vis[RIGHT_HIP])

    # 몸통 축: 골반 중점 → 어깨 중점 (가시성 가중평균 중점)
    hip_mid_2d = _weighted_pair(px[LEFT_HIP], hip_vis_l, px[RIGHT_HIP], hip_vis_r)
    sh_mid_2d = _weighted_pair(px[LEFT_SHOULDER], sh_vis_l, px[RIGHT_SHOULDER], sh_vis_r)
    hip_mid_3d = _weighted_pair(world[LEFT_HIP], hip_vis_l, world[RIGHT_HIP], hip_vis_r)
    sh_mid_3d = _weighted_pair(world[LEFT_SHOULDER], sh_vis_l, world[RIGHT_SHOULDER], sh_vis_r)

    # 이미지/월드 좌표 모두 y축이 아래로 향하므로 '위'는 -y 방향이다.
    up_2d = np.array([0.0, -1.0])
    up_3d = np.array([0.0, -1.0, 0.0])

    trunk_flexion_2d = angle_between(sh_mid_2d - hip_mid_2d, up_2d)
    trunk_flexion_3d = angle_between(sh_mid_3d - hip_mid_3d, up_3d)

    shoulder_vec = px[RIGHT_SHOULDER] - px[LEFT_SHOULDER]
    hip_vec = px[RIGHT_HIP] - px[LEFT_HIP]
    horizontal = np.array([1.0, 0.0])

    left_knee_3d = three_point_angle(world[LEFT_HIP], world[LEFT_KNEE], world[LEFT_ANKLE])
    right_knee_3d = three_point_angle(world[RIGHT_HIP], world[RIGHT_KNEE], world[RIGHT_ANKLE])

    # 무릎각도 좌우 각각 "그 다리를 이루는 세 관절 중 가장 안 보이는 곳"의
    # 가시성을 그 다리의 신뢰도로 써서 가중평균한다.
    left_knee_weight = min(float(vis[LEFT_HIP]), float(vis[LEFT_KNEE]), float(vis[LEFT_ANKLE]))
    right_knee_weight = min(float(vis[RIGHT_HIP]), float(vis[RIGHT_KNEE]), float(vis[RIGHT_ANKLE]))
    knee_mean_3d = float(
        _weighted_pair(np.array(left_knee_3d), left_knee_weight, np.array(right_knee_3d), right_knee_weight)
    )

    valid = not (np.isnan(trunk_flexion_3d) and np.isnan(knee_mean_3d))
    low = check_visibility(pose, threshold)

    return FrameFeatures(
        valid=valid,
        reason="" if valid else "몸통·무릎 각도를 모두 계산할 수 없음 (전신 미검출)",
        trunk_flexion_2d=trunk_flexion_2d,
        trunk_flexion_3d=trunk_flexion_3d,
        left_knee_2d=three_point_angle(px[LEFT_HIP], px[LEFT_KNEE], px[LEFT_ANKLE]),
        right_knee_2d=three_point_angle(px[RIGHT_HIP], px[RIGHT_KNEE], px[RIGHT_ANKLE]),
        left_knee_3d=left_knee_3d,
        right_knee_3d=right_knee_3d,
        knee_mean_3d=knee_mean_3d,
        shoulder_tilt=min(angle_between(shoulder_vec, horizontal),
                          angle_between(-shoulder_vec, horizontal)),
        hip_tilt=min(angle_between(hip_vec, horizontal),
                     angle_between(-hip_vec, horizontal)),
        knee_diff_3d=abs(left_knee_3d - right_knee_3d),
        low_visibility=low,
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
