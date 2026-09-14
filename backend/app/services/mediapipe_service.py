from collections.abc import Sequence


class MediaPipeService:
    """이미지 또는 landmark를 받는 자세 분석 확장 지점."""

    def analyze_pose(
        self,
        *,
        image: bytes | None = None,
        landmarks: Sequence[Sequence[float]] | None = None,
    ) -> dict[str, object]:
        raise NotImplementedError("Pose analysis is not implemented yet")
