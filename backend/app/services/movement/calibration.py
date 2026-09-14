"""개인 기준선(baseline) 캘리브레이션.

사용자마다 평소 서 있는 자세가 다르므로(체형·습관 차이),
"절대 각도"가 아니라 "본인 기준선 대비 편차"로 판정하기 위한 모듈이다.
학습이 아니라 단순 평균값 저장이며, 근거는 계획서 §2.3 참고.
"""

from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
import yaml

from .features import FrameFeatures, compute_features
from .pose_extractor import PoseExtractor

CONFIG_PATH = Path(__file__).resolve().parent / "config.yaml"
DEFAULT_PROFILE_PATH = Path(__file__).resolve().parents[3] / ".local" / "motion_demo" / "calibration_profile.json"


def _capture_frames_setting() -> int:
    if not CONFIG_PATH.exists():
        return 45
    data = yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8")) or {}
    return (data.get("calibration") or {}).get("capture_frames", 45)


@dataclass
class CalibrationProfile:
    """개인 기준선. 서 있는 자세의 몸통 축·무릎각 평균값을 저장한다."""

    baseline_trunk_flexion: float
    baseline_knee_angle: float
    frame_count: int
    captured_at: float

    def save(self, path: Path = DEFAULT_PROFILE_PATH) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(asdict(self), ensure_ascii=False, indent=2), encoding="utf-8")

    @classmethod
    def load(cls, path: Path = DEFAULT_PROFILE_PATH) -> "CalibrationProfile | None":
        if not path.exists():
            return None
        return cls(**json.loads(path.read_text(encoding="utf-8")))

    def trunk_deviation(self, current_flexion: float) -> float:
        """기준선 대비 몸통 굴곡 편차(도). 양수면 기준보다 더 숙인 상태."""
        return current_flexion - self.baseline_trunk_flexion

    def knee_deviation(self, current_knee_angle: float) -> float:
        """기준선 대비 무릎각 편차(도). 음수면 기준보다 더 굽힌 상태."""
        return current_knee_angle - self.baseline_knee_angle


def run_calibration(
    extractor: PoseExtractor,
    frame_source,
    num_frames: int | None = None,
    on_progress=None,
) -> CalibrationProfile:
    """frame_source가 내보내는 (timestamp_ms, rgb_frame)을 받아 기준선을 측정한다.

    사용자가 "평소 편하게 서 있는 자세"를 유지하는 동안 호출되어야 한다.
    가시성 미달 프레임은 표본에서 제외한다.
    """
    num_frames = num_frames or _capture_frames_setting()
    trunk_samples: list[float] = []
    knee_samples: list[float] = []

    collected = 0
    for timestamp_ms, rgb_frame in frame_source:
        pose = extractor.extract(rgb_frame, timestamp_ms=timestamp_ms)
        if pose is None:
            continue

        features: FrameFeatures = compute_features(pose)
        if on_progress:
            on_progress(collected, num_frames, features)

        if not features.valid:
            continue

        trunk_samples.append(features.trunk_flexion_3d)
        knee_samples.append(features.knee_mean_3d)
        collected += 1
        if collected >= num_frames:
            break

    if collected < num_frames // 2:
        raise RuntimeError(
            f"유효 프레임이 너무 적습니다 ({collected}/{num_frames}). "
            "전신이 잘 보이는 위치에서 다시 시도하세요."
        )

    return CalibrationProfile(
        baseline_trunk_flexion=float(np.median(trunk_samples)),
        baseline_knee_angle=float(np.median(knee_samples)),
        frame_count=collected,
        captured_at=time.time(),
    )
