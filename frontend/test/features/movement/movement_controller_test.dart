import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/models/posture_frame_state.dart';
import 'package:plm_frontend/features/movement/movement_controller.dart';

import 'fakes.dart';

void main() {
  late FakeCameraFrameSource camera;
  late FakeLiveTransport transport;
  late MovementController controller;

  setUp(() {
    camera = FakeCameraFrameSource();
    transport = FakeLiveTransport();
    controller = MovementController(
      wsUri: Uri.parse('ws://localhost:8000/api/v1/movement/live/stream'),
      cameraFrameSourceFactory: () => camera,
      transportFactory: (_) async => transport,
    );
  });

  test('start()은 카메라를 켜고 calibrating 상태로 전환한다', () async {
    await controller.start();

    expect(camera.started, isTrue);
    expect(controller.state, MovementConnectionState.calibrating);
    expect(controller.cameraViewType, 'fake-view-type');
  });

  test('카메라 프레임은 그대로 transport로 전달된다', () async {
    await controller.start();

    final bytes = Uint8List.fromList([1, 2, 3]);
    camera.emitFrame(bytes);
    await Future<void>.delayed(Duration.zero);

    expect(transport.sentFrames, [bytes]);
  });

  test('calibration_progress 메시지로 진행률이 갱신된다', () async {
    await controller.start();

    transport.emitMessage('{"type": "calibration_progress", "collected": 5, "target": 45}');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, MovementConnectionState.calibrating);
    expect(controller.calibrationCollected, 5);
    expect(controller.calibrationTarget, 45);
  });

  test('calibration_done 이후 frame 메시지가 오면 live 상태로 최신 프레임을 들고 있다', () async {
    await controller.start();

    transport.emitMessage('{"type": "calibration_done"}');
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, MovementConnectionState.live);

    transport.emitMessage('''
      {"type": "frame", "data": {
        "session_id": "00000000-0000-0000-0000-000000000001",
        "occurred_at": "2026-09-15T01:00:00Z",
        "posture": "Sitting", "burden_label": "High-load Action",
        "state_duration_sec": 0.0, "cumulative_bend_sec": 0.0, "landmarks": []
      }}
    ''');
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, MovementConnectionState.live);
    expect(controller.latestFrame?.posture, PostureType.sitting);
    expect(controller.latestFrame?.burdenLabel, BurdenLabel.highLoadAction);
  });

  test('stop()은 카메라/transport를 정리하고 idle로 되돌린다', () async {
    await controller.start();
    await controller.stop();

    expect(camera.disposed, isTrue);
    expect(transport.closed, isTrue);
    expect(controller.state, MovementConnectionState.idle);
    expect(controller.cameraViewType, isNull);
  });

  test('연결 중 예외가 나면 error 상태가 되고 리소스를 정리한다', () async {
    final failing = MovementController(
      wsUri: Uri.parse('ws://localhost:8000/api/v1/movement/live/stream'),
      cameraFrameSourceFactory: () => camera,
      transportFactory: (_) async => throw StateError('연결 실패'),
    );

    await failing.start();

    expect(failing.state, MovementConnectionState.error);
    expect(failing.errorMessage, contains('연결 실패'));
    expect(camera.disposed, isTrue);
  });
}
