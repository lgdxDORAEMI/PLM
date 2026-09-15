import 'package:flutter/material.dart';

import 'browser_camera_frame_source.dart';
import 'browser_live_transport.dart';
import 'models/posture_frame_state.dart';
import 'movement_controller.dart';
import 'movement_overlay_painter.dart';

/// 모션 인식 데모 화면 (B-4). 카메라를 켜서 캘리브레이션 후 실시간 자세/부담
/// 라벨을 보여준다. 데모 전용이며(구현계획서_v3.md §4), 실제 브라우저 카메라
/// 동작은 이 화면에서 `flutter run -d chrome`으로 수동 확인이 필요하다.
///
/// 실제 dart:html 기반 카메라/WebSocket 구현을 여기서만 연결한다 — 그래야
/// movement_controller.dart는 그 구현들을 몰라도 되고 순수 Dart VM에서
/// 테스트할 수 있다 (movement_controller.dart 상단 주석 참고).
class MovementScreen extends StatefulWidget {
  const MovementScreen({super.key, required this.backendWsUri});

  final Uri backendWsUri;

  @override
  State<MovementScreen> createState() => _MovementScreenState();
}

class _MovementScreenState extends State<MovementScreen> {
  late final MovementController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MovementController(
      wsUri: widget.backendWsUri,
      cameraFrameSourceFactory: BrowserCameraFrameSource.new,
      transportFactory: BrowserLiveTransport.connect,
    );
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('모션 인식 (데모)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: _buildPreview()),
            const SizedBox(height: 16),
            _buildStatusBanner(),
            const SizedBox(height: 16),
            _buildControlButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final viewType = _controller.cameraViewType;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: viewType == null
            ? const Center(
                child: Text('카메라가 꺼져 있습니다', style: TextStyle(color: Colors.white70)),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      HtmlElementView(viewType: viewType),
                      CustomPaint(
                        painter: MovementOverlayPainter(
                          landmarks: _controller.latestFrame?.landmarks ?? const <Landmark>[],
                          sourceWidth: 640,
                          sourceHeight: 480,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    switch (_controller.state) {
      case MovementConnectionState.idle:
        return const Text('시작하려면 아래 버튼을 누르세요.');
      case MovementConnectionState.connecting:
        return const Text('카메라·서버에 연결하는 중...');
      case MovementConnectionState.calibrating:
        final collected = _controller.calibrationCollected;
        final target = _controller.calibrationTarget;
        final label = target > 0 ? '캘리브레이션 중... $collected/$target' : '캘리브레이션 준비 중...';
        return Column(
          children: [
            Text(label),
            const SizedBox(height: 8),
            const Text('편하게 서서 전신이 보이도록 해주세요.', style: TextStyle(fontSize: 12)),
          ],
        );
      case MovementConnectionState.live:
        final frame = _controller.latestFrame;
        if (frame == null) return const Text('판정 대기 중...');
        return _PostureBadge(frame: frame);
      case MovementConnectionState.disconnected:
        return const Text('연결이 끊겼습니다.');
      case MovementConnectionState.error:
        return Text(
          '오류: ${_controller.errorMessage ?? "알 수 없는 오류"}',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
    }
  }

  Widget _buildControlButton() {
    final isRunning = _controller.state != MovementConnectionState.idle &&
        _controller.state != MovementConnectionState.error &&
        _controller.state != MovementConnectionState.disconnected;
    return FilledButton(
      onPressed: isRunning ? _controller.stop : _controller.start,
      child: Text(isRunning ? '중지' : '시작'),
    );
  }
}

class _PostureBadge extends StatelessWidget {
  const _PostureBadge({required this.frame});

  final PostureFrameState frame;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('${frame.posture.value} · ${frame.burdenLabel.value}'),
      backgroundColor: _colorFor(frame.burdenLabel),
    );
  }

  Color _colorFor(BurdenLabel label) {
    switch (label) {
      case BurdenLabel.normal:
        return Colors.green.shade100;
      case BurdenLabel.repeatedLoad:
        return Colors.yellow.shade200;
      case BurdenLabel.prolongedLoad:
        return Colors.orange.shade200;
      case BurdenLabel.highLoadAction:
        return Colors.red.shade200;
    }
  }
}
