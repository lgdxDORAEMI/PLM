enum MovementAlertLevel { neutral, caution, high }

class MovementAlert {
  const MovementAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.suggestion,
    required this.time,
    required this.level,
  });
  final String id;
  final String title;
  final String description;
  final String suggestion;
  final String time;
  final MovementAlertLevel level;

  factory MovementAlert.fromJson(Map<String, dynamic> json) {
    final posture = json['posture_type']?.toString() ?? '';
    final burden = json['burden_label']?.toString() ?? '';
    final trigger = json['trigger_reason']?.toString() ?? '';
    final startedAt = DateTime.tryParse(json['started_at']?.toString() ?? '');
    return MovementAlert(
      id: json['event_id']?.toString() ?? '',
      title: _eventTitle(posture, burden),
      description: '${_postureLabel(posture)} · ${_burdenLabel(burden)}',
      suggestion: _triggerLabel(trigger),
      time: startedAt == null ? '' : _timeLabel(startedAt.toLocal()),
      // High-load Action(앉았다 일어남)은 하루에도 수십 번 일어나는 정상적인
      // 동작이라 경고 톤이 아니라 중립 톤으로 보여준다(2026-09-23 결정).
      level: switch (burden) {
        'Prolonged Load' => MovementAlertLevel.high,
        'High-load Action' => MovementAlertLevel.neutral,
        _ => MovementAlertLevel.caution,
      },
    );
  }

  static String _eventTitle(String posture, String burden) =>
      '${_postureLabel(posture)} ${_burdenLabel(burden)} 감지';

  static String _postureLabel(String value) => switch (value.toLowerCase()) {
    'bending' => '허리 숙임',
    'standing' => '서 있기',
    'sitting' => '앉기',
    _ => value,
  };

  static String _burdenLabel(String value) => switch (value) {
    'Repeated Load' => '반복 부담',
    'Prolonged Load' => '지속 부담',
    'High-load Action' => '고부담 동작',
    'Normal' => '일반 동작',
    _ => value,
  };

  static String _triggerLabel(String value) => switch (value) {
    'state_duration' => '한 번에 오래 지속돼 감지됐어요.',
    'repeated_count' => '반복 횟수 기준을 넘어 감지됐어요.',
    'cumulative_research_threshold' => '누적된 부담 시간이 기준을 넘어 감지됐어요.',
    'sit_to_stand' => '앉았다 일어나는 동작으로 감지됐어요.',
    _ => value,
  };

  static String _timeLabel(DateTime value) {
    final period = value.hour < 12 ? '오전' : '오후';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$period ${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class MovementDashboardData {
  const MovementDashboardData({
    required this.alerts,
    required this.forwardBendSeconds,
    required this.burdenEventCount,
    required this.narratives,
    required this.consentGranted,
    required this.collectionEnabled,
  });

  final List<MovementAlert> alerts;
  final double forwardBendSeconds;
  final int burdenEventCount;
  final List<String> narratives;
  final bool consentGranted;
  final bool collectionEnabled;
}

abstract final class MovementMockData {
  static const alerts = [
    MovementAlert(
      id: 'back-load',
      title: '허리 부담 기준 초과',
      description: '허리에 반복적인 부담이 감지되었어요.',
      suggestion: '10분 이상 같은 자세로 작업한 것으로 보여요.',
      time: '오전 10:24',
      level: MovementAlertLevel.high,
    ),
    MovementAlert(
      id: 'pelvis',
      title: '골반 주의 상태가 감지되었어요',
      description: '골반에 무리가 갈 수 있는 자세가 감지되었어요.',
      suggestion: '앉았다 일어나는 동작이 평소보다 많았어요.',
      time: '오전 09:18',
      level: MovementAlertLevel.caution,
    ),
    MovementAlert(
      id: 'standing',
      title: '장시간 서 있기 패턴이 감지되었어요',
      description: '40분 이상 연속으로 서 있는 상태가 감지되었어요.',
      suggestion: '잠시 앉아 휴식을 취하는 것이 좋아요.',
      time: '오전 08:03',
      level: MovementAlertLevel.caution,
    ),
    MovementAlert(
      id: 'repeated-bending',
      title: '반복해서 숙이는 동작이 감지되었어요',
      description: '짧은 시간 동안 허리를 여러 번 숙였어요.',
      suggestion: '바닥 물건은 가족에게 부탁하거나 집게 도구를 사용해 주세요.',
      time: '오전 07:42',
      level: MovementAlertLevel.high,
    ),
    MovementAlert(
      id: 'rest-needed',
      title: '휴식이 필요한 활동량이에요',
      description: '쉬는 시간 없이 움직임이 이어졌어요.',
      suggestion: '편한 자세로 앉아 10분 정도 쉬어 주세요.',
      time: '오전 07:10',
      level: MovementAlertLevel.caution,
    ),
  ];
}
