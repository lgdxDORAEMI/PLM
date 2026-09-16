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

  /// 몸통·팔다리 위주 스켈레톤 연결선. 이름은 pose_extractor.py의
  /// LANDMARK_NAMES(MediaPipe 표준 33개)와 동일해야 한다. 얼굴(눈/코/입)은
  /// 자세 판정과 무관해서 뺐다.
  static const List<(String, String)> _connections = [
    ('left_shoulder', 'right_shoulder'),
    ('left_shoulder', 'left_elbow'),
    ('left_elbow', 'left_wrist'),
    ('right_shoulder', 'right_elbow'),
    ('right_elbow', 'right_wrist'),
    ('left_shoulder', 'left_hip'),
    ('right_shoulder', 'right_hip'),
    ('left_hip', 'right_hip'),
    ('left_hip', 'left_knee'),
    ('left_knee', 'left_ankle'),
    ('right_hip', 'right_knee'),
    ('right_knee', 'right_ankle'),
    ('left_ankle', 'left_foot_index'),
    ('right_ankle', 'right_foot_index'),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceWidth <= 0 || sourceHeight <= 0) return;
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final byName = {for (final l in landmarks) l.name: l};
    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 선을 점보다 먼저 그려서, 점이 선 위에 덧그려져 관절이 도드라져 보이게 한다.
    for (final (a, b) in _connections) {
      final la = byName[a];
      final lb = byName[b];
      if (la == null || lb == null) continue;
      if (la.visibility < _minVisibility || lb.visibility < _minVisibility) {
        continue;
      }
      canvas.drawLine(
        Offset(la.x * scaleX, la.y * scaleY),
        Offset(lb.x * scaleX, lb.y * scaleY),
        linePaint,
      );
    }

    final dotPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    for (final landmark in landmarks) {
      if (landmark.visibility < _minVisibility) continue;
      canvas.drawCircle(
        Offset(landmark.x * scaleX, landmark.y * scaleY),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MovementOverlayPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks;
}
