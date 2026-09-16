"""개인 기준선(baseline) 캘리브레이션.

사용자마다 평소 서 있는 자세가 다르므로(체형·습관 차이),
"절대 각도"가 아니라 "본인 기준선 대비 편차"로 판정하기 위한 모듈이다.
학습이 아니라 단순 평균값 저장이며, 근거는 계획서 §2.3 참고.

저장 방식(CalibrationStore)은 이 파일에서 함께 정의하되 `CalibrationProfile`
자체와는 분리했다 (B-5, 2026-09-15). 로컬 파일 구현체(`LocalFileCalibrationStore`)와
Supabase 구현체(`SupabaseCalibrationStore`, 2026-09-16 추가) 둘 다 있고,
`run_calibration()`이나 호출부는 store 인스턴스만 바꾸면 그대로 재사용된다.
컬럼 설계는 `supabase/README.md`와
`supabase/migrations/20260916000000_create_movement_tables.sql`의
`posture_calibration_profiles` 참고.
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Protocol
from uuid import UUID

import httpx
import numpy as np
import yaml
from postgrest.exceptions import APIError

from ..supabase_service import SupabaseService
from .features import FrameFeatures, compute_features
from .pose_extractor import PoseExtractor

logger = logging.getLogger(__name__)

CONFIG_PATH = Path(__file__).resolve().parent / "config.yaml"
DEFAULT_STORE_DIR = Path(__file__).resolve().parents[3] / ".local" / "motion_demo" / "calibration"


def _capture_frames_setting() -> int:
    if not CONFIG_PATH.exists():
        return 45
    data = yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8")) or {}
    return (data.get("calibration") or {}).get("capture_frames", 45)


@dataclass
class CalibrationProfile:
    """개인 기준선. 서 있는 자세의 몸통 축·무릎각 평균값을 저장한다.

    저장/조회는 이 클래스가 아니라 CalibrationStore가 담당한다 (관심사 분리).
    """

    baseline_trunk_flexion: float
    baseline_knee_angle: float
    frame_count: int
    captured_at: float

    def trunk_deviation(self, current_flexion: float) -> float:
        """기준선 대비 몸통 굴곡 편차(도). 양수면 기준보다 더 숙인 상태."""
        return current_flexion - self.baseline_trunk_flexion

    def knee_deviation(self, current_knee_angle: float) -> float:
        """기준선 대비 무릎각 편차(도). 음수면 기준보다 더 굽힌 상태."""
        return current_knee_angle - self.baseline_knee_angle


class CalibrationStore(Protocol):
    """사용자별 캘리브레이션 기준선 저장소. 구현체를 바꿔도 호출부는 그대로다."""

    def save(self, user_id: UUID, profile: CalibrationProfile) -> None: ...

    def load(self, user_id: UUID) -> CalibrationProfile | None: ...


class LocalFileCalibrationStore:
    """데모/로컬 개발용 구현체. 사용자별로 JSON 파일 하나씩 저장한다.

    TODO (NFR-008, 2026-09-15 결정 — 지금은 주석만): 여기 저장되는 각도 데이터도
    민감정보로 분류되므로, 실제 서비스에서는 파일 저장이 아니라 암호화된 DB
    저장(Supabase)으로 교체해야 한다.
    """

    def __init__(self, base_dir: Path = DEFAULT_STORE_DIR):
        self.base_dir = base_dir

    def _path(self, user_id: UUID) -> Path:
        return self.base_dir / f"{user_id}.json"

    def save(self, user_id: UUID, profile: CalibrationProfile) -> None:
        path = self._path(user_id)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(asdict(profile), ensure_ascii=False, indent=2), encoding="utf-8")

    def load(self, user_id: UUID) -> CalibrationProfile | None:
        path = self._path(user_id)
        if not path.exists():
            return None
        return CalibrationProfile(**json.loads(path.read_text(encoding="utf-8")))


class CalibrationStorageError(Exception):
    """DB 저장 또는 조회에 실패했다."""


class SupabaseCalibrationStore:
    """Supabase(Postgres) 기반 CalibrationStore 구현체 (2026-09-16 추가).

    profile_service.ProfileService와 같은 쿼리 패턴을 따르되, 생성자는 Client가
    아니라 SupabaseService를 받는다 — 이 store는 ProfileService처럼 요청마다
    새로 만드는 게 아니라 `movement.py`가 앱 시작 시점에 한 번만 만드는
    singleton이라, `.client`(실제 연결)를 생성자에서 바로 만들면 SUPABASE_*
    환경변수가 없을 때 앱 자체가 기동 실패한다. SupabaseService.client는
    지연 프로퍼티라, 실제 DB 요청이 오는 시점에야 연결을 만들고 그때
    실패하면 여기서 CalibrationStorageError로 감싼다.

    재캘리브레이션을 여러 번 할 수 있으므로 user_id에 unique 제약을 두지
    않고(supabase/README.md 참고) save()는 항상 새 행을 insert, load()는
    captured_at 기준 가장 최근 행 하나를 가져온다.

    TODO (NFR-008, 2026-09-15 결정 — 지금은 주석만): 여기 저장되는 각도
    데이터도 민감정보로 분류되므로, 컬럼 단위 암호화 적용이 필요할 수 있다
    (지금은 미구현).
    """

    TABLE = "posture_calibration_profiles"

    def __init__(self, supabase: SupabaseService) -> None:
        self.supabase = supabase

    def save(self, user_id: UUID, profile: CalibrationProfile) -> None:
        row = {
            "user_id": str(user_id),
            "baseline_trunk_flexion": profile.baseline_trunk_flexion,
            "baseline_knee_angle": profile.baseline_knee_angle,
            "frame_count": profile.frame_count,
            "captured_at": _epoch_to_iso(profile.captured_at),
        }
        self._run(lambda: self._client().table(self.TABLE).insert(row).execute())

    def load(self, user_id: UUID) -> CalibrationProfile | None:
        rows = self._run(
            lambda: self._client()
            .table(self.TABLE)
            .select("baseline_trunk_flexion", "baseline_knee_angle", "frame_count", "captured_at")
            .eq("user_id", str(user_id))
            .order("captured_at", desc=True)
            .limit(1)
            .execute()
        )
        if not rows:
            return None
        row = rows[0]
        return CalibrationProfile(
            baseline_trunk_flexion=row["baseline_trunk_flexion"],
            baseline_knee_angle=row["baseline_knee_angle"],
            frame_count=row["frame_count"],
            captured_at=_iso_to_epoch(row["captured_at"]),
        )

    def _client(self) -> Any:
        try:
            return self.supabase.client
        except ValueError as error:  # SUPABASE_* 환경변수 누락
            raise CalibrationStorageError from error

    def _run(self, request: Any) -> list[dict]:
        try:
            return request().data
        except (APIError, httpx.HTTPError) as error:
            logger.exception("캘리브레이션 DB 요청 실패")
            raise CalibrationStorageError from error


def _epoch_to_iso(value: float) -> str:
    return datetime.fromtimestamp(value, tz=timezone.utc).isoformat()


def _iso_to_epoch(value: str) -> float:
    return datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()


class CalibrationCollector:
    """프레임을 한 번에 하나씩 받아 캘리브레이션 표본을 모으는 누산기.

    run_calibration()은 동기 제너레이터(frame_source)를 순회하는 걸 전제로 하는데,
    WebSocket처럼 프레임이 비동기로 하나씩 들어오는 상황에는 그 형태가 맞지 않는다
    (B-1, 2026-09-15). 같은 판정 로직(가시성 필터링 + median)을 두 경로 모두에서
    쓰기 위해 이 클래스로 뽑아냈고, run_calibration()도 내부적으로 이걸 쓴다.
    """

    def __init__(self, extractor: PoseExtractor, num_frames: int | None = None):
        self.extractor = extractor
        self.num_frames = num_frames or _capture_frames_setting()
        self._trunk_samples: list[float] = []
        self._knee_samples: list[float] = []

    @property
    def collected(self) -> int:
        return len(self._trunk_samples)

    @property
    def done(self) -> bool:
        return self.collected >= self.num_frames

    def add_frame(self, rgb_frame, timestamp_ms: int) -> FrameFeatures | None:
        """프레임 하나를 넣는다. 사람이 없거나 가시성 미달이면 표본에 반영하지 않는다."""
        pose = self.extractor.extract(rgb_frame, timestamp_ms=timestamp_ms)
        if pose is None:
            return None

        features = compute_features(pose)
        if features.valid:
            self._trunk_samples.append(features.trunk_flexion_3d)
            self._knee_samples.append(features.knee_mean_3d)
        return features

    def build_profile(self) -> CalibrationProfile:
        """지금까지 모인 표본으로 기준선을 만든다. 표본이 너무 적으면 실패한다."""
        if self.collected < self.num_frames // 2:
            raise RuntimeError(
                f"유효 프레임이 너무 적습니다 ({self.collected}/{self.num_frames}). "
                "전신이 잘 보이는 위치에서 다시 시도하세요."
            )
        return CalibrationProfile(
            baseline_trunk_flexion=float(np.median(self._trunk_samples)),
            baseline_knee_angle=float(np.median(self._knee_samples)),
            frame_count=self.collected,
            captured_at=time.time(),
        )


def run_calibration(
    extractor: PoseExtractor,
    frame_source,
    num_frames: int | None = None,
    on_progress=None,
) -> CalibrationProfile:
    """frame_source가 내보내는 (timestamp_ms, rgb_frame)을 받아 기준선을 측정한다.

    사용자가 "평소 편하게 서 있는 자세"를 유지하는 동안 호출되어야 한다.
    PC 웹캠 데모(tools/motion_demo)처럼 동기 루프로 프레임을 순회할 수 있는
    경우에 쓴다. WebSocket처럼 비동기로 한 프레임씩 받는 경우는 CalibrationCollector를
    직접 쓴다.
    """
    collector = CalibrationCollector(extractor, num_frames)
    for timestamp_ms, rgb_frame in frame_source:
        features = collector.add_frame(rgb_frame, timestamp_ms)
        if features is not None and on_progress:
            on_progress(collector.collected, collector.num_frames, features)
        if collector.done:
            break

    return collector.build_profile()
