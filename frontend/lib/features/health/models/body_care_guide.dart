class BodyLoad {
  const BodyLoad(this.area, this.label, this.value);
  final String area;
  final String label;
  final double value;
}

class BodyCareActivity {
  const BodyCareActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.guide,
  });
  final String id;
  final String title;
  final String description;
  final String guide;
}

abstract final class BodyCareMockData {
  static const loads = [
    BodyLoad('허리', '부담 높음', .86),
    BodyLoad('골반', '부담 보통', .58),
    BodyLoad('다리', '여유 있음', .28),
  ];
  static const activities = [
    BodyCareActivity(
      id: 'pelvis',
      title: '골반 흔들기 스트레칭 · 5분',
      description: '앉아서 할 수 있어요 · 28주차 안전 동작',
      guide: '등받이가 있는 의자에 편안히 앉고, 통증이 없는 범위에서 골반을 천천히 좌우로 움직여요.',
    ),
    BodyCareActivity(
      id: 'calf',
      title: '종아리 마사지',
      description: '다리 경련 예방 · 3분',
      guide: '앉은 자세에서 종아리를 아래에서 위로 가볍게 쓸어 올려요.',
    ),
    BodyCareActivity(
      id: 'posture',
      title: '앉은 자세 교정',
      description: '허리 뒤 쿠션 위치 안내',
      guide: '허리 곡선 뒤에 작은 쿠션을 두고 양발을 바닥에 편안히 놓아요.',
    ),
  ];
}
