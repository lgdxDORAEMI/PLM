import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/models/live_message.dart';
import 'package:plm_frontend/features/movement/models/posture_frame_state.dart';

void main() {
  group('LiveMessage.fromJson', () {
    test('parses calibration_progress', () {
      final message = LiveMessage.fromJson({
        'type': 'calibration_progress',
        'collected': 3,
        'target': 45,
      });

      expect(message, isA<CalibrationProgress>());
      final progress = message as CalibrationProgress;
      expect(progress.collected, 3);
      expect(progress.target, 45);
    });

    test('parses calibration_done', () {
      final message = LiveMessage.fromJson({'type': 'calibration_done'});
      expect(message, isA<CalibrationDone>());
    });

    test('parses frame with landmarks', () {
      // backend/app/schemas/movement.py의 PostureFrameState 실제 응답 모양과 동일.
      final message = LiveMessage.fromJson({
        'type': 'frame',
        'data': {
          'session_id': '00000000-0000-0000-0000-000000000001',
          'occurred_at': '2026-09-15T01:00:00Z',
          'posture': 'Bending',
          'burden_label': 'Prolonged Load',
          'state_duration_sec': 9.5,
          'cumulative_bend_sec': 12.0,
          'landmarks': [
            {
              'name': 'nose',
              'x': 100.0,
              'y': 50.0,
              'visibility': 0.95,
              'world_x': 0.1,
              'world_y': 0.2,
              'world_z': 0.3,
            },
          ],
        },
      });

      expect(message, isA<FrameUpdate>());
      final frame = (message as FrameUpdate).state;
      expect(frame.posture, PostureType.bending);
      expect(frame.burdenLabel, BurdenLabel.prolongedLoad);
      expect(frame.stateDurationSec, 9.5);
      expect(frame.cumulativeBendSec, 12.0);
      expect(frame.landmarks, hasLength(1));
      expect(frame.landmarks.single.name, 'nose');
      expect(frame.landmarks.single.visibility, 0.95);
    });

    test('unknown type throws FormatException', () {
      expect(() => LiveMessage.fromJson({'type': 'nope'}), throwsFormatException);
    });
  });

  group('PostureType/BurdenLabel fromJson', () {
    test('falls back to unknown/normal for unrecognized values instead of throwing', () {
      expect(PostureType.fromJson('Cartwheel'), PostureType.unknown);
      expect(BurdenLabel.fromJson('Cartwheel'), BurdenLabel.normal);
    });
  });
}
