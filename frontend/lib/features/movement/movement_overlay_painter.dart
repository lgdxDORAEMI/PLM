import 'package:flutter/material.dart';

import 'models/posture_frame_state.dart';

/// landmark 좌표는 캡처 프레임 크기(BrowserCameraFrameSource.captureWidth/Height)
/// 기준 픽셀 좌표라서, 실제 위젯 표시 크기로 스케일링해서 그린다.
class MovementOverlayPainter extends CustomPainter {
  MovementOverlayPainter({
    required this.landmarks,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final List<Landmark> landmarks;
  final double sourceWidth;
  final double sourceHeight;

  static const double _minVisibility = 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceWidth <= 0 || sourceHeight <= 0) return;
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    for (final landmark in landmarks) {
      if (landmark.visibility < _minVisibility) continue;
      canvas.drawCircle(Offset(landmark.x * scaleX, landmark.y * scaleY), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MovementOverlayPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks;
}
