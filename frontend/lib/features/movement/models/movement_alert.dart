enum MovementAlertLevel { caution, high }

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
      id: 'bending',
      title: '반복 숙이기 동작이 누적되었어요',
      description: '허리를 숙이는 동작이 여러 번 감지되었어요.',
      suggestion: '누적 시 허리 통증으로 이어질 수 있어요.',
      time: '어제 오후 07:41',
      level: MovementAlertLevel.high,
    ),
  ];
}
