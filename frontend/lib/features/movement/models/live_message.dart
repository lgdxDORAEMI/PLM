import 'posture_frame_state.dart';

/// WS `/api/v1/movement/live/stream`이 보내는 세 종류의 메시지 (docs/api.md 참고).
sealed class LiveMessage {
  const LiveMessage();

  static LiveMessage fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'calibration_progress':
        return CalibrationProgress(
          collected: json['collected'] as int,
          target: json['target'] as int,
        );
      case 'calibration_done':
        return const CalibrationDone();
      case 'frame':
        return FrameUpdate(
          PostureFrameState.fromJson(json['data'] as Map<String, dynamic>),
        );
      default:
        throw FormatException('알 수 없는 메시지 type: ${json['type']}');
    }
  }
}

class CalibrationProgress extends LiveMessage {
  const CalibrationProgress({required this.collected, required this.target});
  final int collected;
  final int target;
}

class CalibrationDone extends LiveMessage {
  const CalibrationDone();
}

class FrameUpdate extends LiveMessage {
  const FrameUpdate(this.state);
  final PostureFrameState state;
}
