"""PLM 루트에서 python -m tools.motion_demo로 실행한다."""

import argparse
from itertools import islice
from pathlib import Path
import sys
import time

# 독립 도구에서 backend의 app 패키지를 사용한다. 서버 설정은 변경하지 않는다.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))


def check() -> None:
    import mediapipe as mp
    import numpy as np
    from mediapipe.tasks.python.vision import RunningMode

    from app.services.movement.features import compute_features
    from app.services.movement.pose_extractor import PoseExtractor
    from app.services.movement.rule_engine import RuleEngine
    from .camera import CameraConfig

    print("Camera config:", CameraConfig.load())
    print("MediaPipe:", mp.__version__)
    image = np.zeros((480, 640, 3), dtype=np.uint8)
    for mode in (RunningMode.IMAGE, RunningMode.VIDEO):
        with PoseExtractor(mode) as extractor:
            assert extractor.extract(image, timestamp_ms=1) is None
        print(mode.name, "model inference OK (blank image, no person)")
    engine = RuleEngine()
    engine.update(0.0, True, trunk_dev=30, knee_dev=0)
    judgement = engine.update(1.0, True, trunk_dev=0, knee_dev=0)
    assert judgement.bend_reps_in_window == 1
    print("Rule engine/imports OK; camera was not opened")


def webcam(index: int | None) -> None:
    import cv2
    from mediapipe.tasks.python.vision import RunningMode

    from app.services.movement.calibration import run_calibration
    from app.services.movement.features import EmaSmoother, compute_features
    from app.services.movement.pose_extractor import PoseExtractor
    from app.services.movement.rule_engine import RuleEngine
    from .camera import CameraConfig, CameraSource

    config = CameraConfig.load()
    if index is not None:
        config.index = index
    start = time.monotonic()
    last_timestamp_ms = -1

    def timestamp_ms() -> int:
        nonlocal last_timestamp_ms
        last_timestamp_ms = max(last_timestamp_ms + 1, int((time.monotonic() - start) * 1000))
        return last_timestamp_ms

    try:
        with CameraSource(config) as camera, PoseExtractor(RunningMode.VIDEO) as extractor:
            print("Actual camera spec:", camera.actual_spec)
            print("Calibration: keep your whole body visible and stand comfortably.")

            def calibration_frames():
                for frame in islice(camera.frames(), 450):
                    cv2.imshow("PLM Motion Demo", frame[:, ::-1] if config.mirror_preview else frame)
                    if cv2.waitKey(1) & 0xFF in (27, ord("q")):
                        raise KeyboardInterrupt
                    yield timestamp_ms(), cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # 데모 기준선은 이 실행 세션의 메모리에만 보관한다.
            profile = run_calibration(extractor, calibration_frames())
            print("Calibration OK:", profile.frame_count, "valid frames. Press q or Esc to quit.")
            smoother = EmaSmoother()
            engine = RuleEngine()
            for frame in camera.frames():
                timestamp = timestamp_ms()
                pose = extractor.extract(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB), timestamp)
                features = compute_features(pose) if pose is not None else None
                valid = features is not None and features.valid
                trunk_dev = knee_dev = float("nan")
                if valid:
                    trunk_dev = profile.trunk_deviation(smoother.update("trunk", features.trunk_flexion_3d))
                    knee_dev = profile.knee_deviation(smoother.update("knee", features.knee_mean_3d))
                judgement = engine.update(timestamp / 1000, valid, trunk_dev, knee_dev)
                preview = frame[:, ::-1].copy() if config.mirror_preview else frame.copy()
                if pose is not None:
                    width = frame.shape[1]
                    for (x, y), visibility in zip(pose.pixel_xy, pose.visibility):
                        if visibility >= 0.6:
                            x = width - 1 - x if config.mirror_preview else x
                            cv2.circle(preview, (int(x), int(y)), 3, (0, 255, 0), -1)
                cv2.putText(preview, f"{judgement.posture} | {judgement.burden_label}",
                            (16, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                cv2.imshow("PLM Motion Demo", preview)
                if cv2.waitKey(1) & 0xFF in (27, ord("q")):
                    break
    finally:
        cv2.destroyAllWindows()


def main() -> None:
    parser = argparse.ArgumentParser(description="PC webcam motion demo (not a browser/mobile camera)")
    parser.add_argument("--check", action="store_true", help="check imports/model without opening a camera")
    parser.add_argument("--camera-index", type=int, help="override configured PC camera index")
    args = parser.parse_args()
    try:
        if args.check:
            check()
        else:
            webcam(args.camera_index)
    except KeyboardInterrupt:
        print("Motion demo stopped")


if __name__ == "__main__":
    main()
