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
    this.video,
    this.completed = false,
    this.skipped = false,
    this.isFocus,
  });
  final String id;
  final String area;
  final String title;
  final String description;
  final String guide;
  final HealthExerciseVideo? video;
  final bool completed;
  final bool skipped;
  final bool? isFocus;
}

class HealthExerciseVideo {
  const HealthExerciseVideo({
    required this.title,
    required this.provider,
    required this.youtubeId,
    this.duration,
    this.target,
  });

  factory HealthExerciseVideo.fromJson(Map<String, dynamic> json) =>
      HealthExerciseVideo(
        title: json['title']?.toString() ?? '',
        provider: json['provider']?.toString() ?? '',
        youtubeId: json['youtube_id']?.toString() ?? '',
        duration: json['duration']?.toString(),
        target: json['target']?.toString(),
      );

  final String title;
  final String provider;
  final String youtubeId;
  final String? duration;
  final String? target;

  bool get canEmbed => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(youtubeId);
}

class BodyCareGuideData {
  const BodyCareGuideData({required this.loads, required this.activities});

  factory BodyCareGuideData.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?)?.whereType<Map>() ?? const [];
    final activities = <BodyCareActivity>[];
    final loadsByArea = <String, BodyLoad>{};
    for (final item in items) {
      final payload = item['payload'] is Map
          ? item['payload'] as Map
          : const <String, dynamic>{};
      final itemKey = item['item_id']?.toString() ?? '';
      final area = payload['bodyArea']?.toString() ?? '';
      final video = payload['video'];
      if (itemKey.isEmpty || area.isEmpty) continue;
      activities.add(
        BodyCareActivity(
          id: itemKey,
          area: area,
          title: item['title']?.toString() ?? '',
          description:
              item['description']?.toString() ??
              payload['reason']?.toString() ??
              '',
          guide: payload['guide']?.toString() ?? '',
          video: video is Map
              ? HealthExerciseVideo.fromJson(video.cast<String, dynamic>())
              : null,
          completed: item['status'] == 'completed',
          skipped: item['status'] == 'skipped',
          isFocus: payload.containsKey('isFocus')
              ? payload['isFocus'] == true
              : null,
        ),
      );
      final loads = payload['loads'];
      if (loads is List) {
        for (final value in loads.whereType<Map>()) {
          final loadArea = value['area']?.toString() ?? '';
          if (loadArea.isEmpty) continue;
          loadsByArea[loadArea] = BodyLoad(
            loadArea,
            value['label']?.toString() ?? '',
            ((value['value'] as num?)?.toDouble() ?? 0).clamp(0, 1),
          );
        }
      }
    }
    return BodyCareGuideData(
      loads: loadsByArea.values.toList(growable: false),
      activities: activities,
    );
  }

  final List<BodyLoad> loads;
  final List<BodyCareActivity> activities;
}

abstract final class BodyCareMockData {
  static const loads = [
    BodyLoad('허리', '매우 심해요', 1),
    BodyLoad('골반', '보통이에요', .6),
    BodyLoad('다리', '조금 있어요', .4),
  ];
  static const activities = [
    BodyCareActivity(
      id: 'pelvis',
      area: '허리',
      title: '골반 흔들기 스트레칭 · 5분',
      description: '앉아서 할 수 있어요 · 28주차 안전 동작',
      guide: '등받이가 있는 의자에 편안히 앉고, 통증이 없는 범위에서 골반을 천천히 좌우로 움직여요.',
      video: HealthExerciseVideo(
        title: '임신 중 허리 통증 완화 스트레칭',
        provider: 'Pregnancy and Postpartum TV',
        youtubeId: '33LLeqyVbG0',
      ),
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
      video: HealthExerciseVideo(
        title: '임신 중 골반 통증 완화 운동',
        provider: 'Pregnancy and Postpartum TV',
        youtubeId: 'wqiDZZbaas8',
      ),
    ),
    BodyCareActivity(
      id: 'calf',
      area: '다리',
      title: '종아리 마사지',
      description: '다리 경련 예방 · 3분',
      guide: '앉은 자세에서 종아리를 아래에서 위로 가볍게 쓸어 올려요.',
      video: HealthExerciseVideo(
        title: '임신 중 좌골신경·다리 통증 완화 요가',
        provider: 'Pregnancy and Postpartum TV',
        youtubeId: 'SFMoku8trIA',
      ),
    ),
    BodyCareActivity(
      id: 'posture',
      area: '허리',
      title: '앉은 자세 교정',
      description: '허리 뒤 쿠션 위치 안내',
      guide: '허리 곡선 뒤에 작은 쿠션을 두고 양발을 바닥에 편안히 놓아요.',
    ),
    BodyCareActivity(
      id: 'wrist-release',
      area: '손목',
      title: '손목과 손 저림 이완',
      description: '무리 없이 손목을 천천히 움직여요',
      guide: '팔을 편안히 두고 손목을 통증 없는 범위에서 천천히 움직여요.',
      video: HealthExerciseVideo(
        title: '임신 중 손목·손 저림 완화 운동',
        provider: 'Pregnancy and Postpartum TV',
        youtubeId: '29OhkciWEMY',
      ),
    ),
    BodyCareActivity(
      id: 'whole-body',
      area: '전신',
      title: '전신 저강도 운동',
      description: '임신 전 기간에 맞춘 25분 운동',
      guide: '통증이 없는 범위에서 천천히 따라 하고 불편하면 즉시 멈춰요.',
      video: HealthExerciseVideo(
        title: '임산부 전신 저강도 운동',
        provider: 'Pregnancy and Postpartum TV',
        youtubeId: 'InQu8jMT130',
        duration: '25분',
        target: '임신 1·2·3분기',
      ),
    ),
  ];

  static List<BodyCareActivity> activitiesFor(String area) => activities
      .where((activity) => activity.area == area)
      .toList(growable: false);
}
