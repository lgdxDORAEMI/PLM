class BodyLoad {
  const BodyLoad(this.area, this.label, this.value);
  final String area;
  final String label;
  final double value;
}

class BodyCareActivity {
  const BodyCareActivity({
    required this.id,
    required this.area,
    required this.title,
    required this.description,
    required this.guide,
  });
  final String id;
  final String area;
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
      area: '허리',
      title: '골반 흔들기 스트레칭 · 5분',
      description: '앉아서 할 수 있어요 · 28주차 안전 동작',
      guide: '등받이가 있는 의자에 편안히 앉고, 통증이 없는 범위에서 골반을 천천히 좌우로 움직여요.',
    ),
    BodyCareActivity(
      id: 'back-breathing',
      area: '허리',
      title: '등 기대고 호흡하기 · 3분',
      description: '허리 긴장 완화 · 편안한 호흡',
      guide: '등받이에 등을 기대고 어깨 힘을 뺀 뒤, 코로 천천히 들이마시고 길게 내쉬어요.',
    ),
    BodyCareActivity(
      id: 'pelvic-release',
      area: '골반',
      title: '골반 이완 호흡 · 4분',
      description: '누르지 않고 편안하게 이완해요',
      guide: '무릎 사이에 쿠션을 두고 옆으로 누워 골반 주변의 힘을 천천히 풀어요.',
    ),
    BodyCareActivity(
      id: 'calf',
      area: '다리',
      title: '종아리 마사지',
      description: '다리 경련 예방 · 3분',
      guide: '앉은 자세에서 종아리를 아래에서 위로 가볍게 쓸어 올려요.',
    ),
    BodyCareActivity(
      id: 'posture',
      area: '허리',
      title: '앉은 자세 교정',
      description: '허리 뒤 쿠션 위치 안내',
      guide: '허리 곡선 뒤에 작은 쿠션을 두고 양발을 바닥에 편안히 놓아요.',
    ),
  ];

  static List<BodyCareActivity> activitiesFor(String area) => activities
      .where((activity) => activity.area == area)
      .toList(growable: false);
}
