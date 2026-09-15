// backend/app/schemas/movement.py의 PostureType/BurdenLabel/Landmark/PostureFrameState와
// 값이 1:1 대응한다. 이 프로젝트엔 OpenAPI 코드젠이 없어서 손으로 맞춘 것이며,
// 백엔드 스키마가 바뀌면 이 파일도 같이 고쳐야 한다.

/// rule_engine.py의 자세 상태 문자열과 동일하다.
enum PostureType {
  standing('Standing'),
  bending('Bending'),
  sitting('Sitting'),
  unknown('Unknown');

  const PostureType(this.value);
  final String value;

  static PostureType fromJson(String value) =>
      PostureType.values.firstWhere((e) => e.value == value, orElse: () => PostureType.unknown);
}

/// rule_engine.py의 부담 라벨 문자열과 동일하다.
enum BurdenLabel {
  normal('Normal'),
  repeatedLoad('Repeated Load'),
  prolongedLoad('Prolonged Load'),
  highLoadAction('High-load Action');

  const BurdenLabel(this.value);
  final String value;

  static BurdenLabel fromJson(String value) =>
      BurdenLabel.values.firstWhere((e) => e.value == value, orElse: () => BurdenLabel.normal);
}

class Landmark {
  const Landmark({
    required this.name,
    required this.x,
    required this.y,
    required this.visibility,
  });

  final String name;
  final double x;
  final double y;
  final double visibility;

  factory Landmark.fromJson(Map<String, dynamic> json) => Landmark(
    name: json['name'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    visibility: (json['visibility'] as num).toDouble(),
  );
}

/// WS `{"type": "frame", "data": ...}`의 data 부분.
/// world_x/y/z는 오버레이 표시에 쓰지 않아서 파싱하지 않는다.
class PostureFrameState {
  const PostureFrameState({
    required this.posture,
    required this.burdenLabel,
    required this.stateDurationSec,
    required this.cumulativeBendSec,
    required this.landmarks,
  });

  final PostureType posture;
  final BurdenLabel burdenLabel;
  final double stateDurationSec;
  final double cumulativeBendSec;
  final List<Landmark> landmarks;

  factory PostureFrameState.fromJson(Map<String, dynamic> json) => PostureFrameState(
    posture: PostureType.fromJson(json['posture'] as String),
    burdenLabel: BurdenLabel.fromJson(json['burden_label'] as String),
    stateDurationSec: (json['state_duration_sec'] as num).toDouble(),
    cumulativeBendSec: (json['cumulative_bend_sec'] as num).toDouble(),
    landmarks: (json['landmarks'] as List<dynamic>)
        .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
