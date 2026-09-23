enum HouseholdTaskOwner { self, appliance, partner }

enum HouseholdTaskStatus { planned, running, reserved, shared, confirmed, done }

class HouseholdTask {
  const HouseholdTask({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    this.status = HouseholdTaskStatus.planned,
    this.selected = false,
    this.applianceNames = const [],
    this.airPurifierDeviceId,
  });

  final String id;
  final String title;
  final String description;
  final HouseholdTaskOwner owner;
  final HouseholdTaskStatus status;
  final bool selected;
  final List<String> applianceNames;

  /// 실제 ThinQ 제어가 가능한 공기청정기 항목일 때만 채워진다. 그 외 가전(세탁기 등)은
  /// 계속 로컬 시연으로 남는다.
  final String? airPurifierDeviceId;

  HouseholdTask copyWith({HouseholdTaskStatus? status, bool? selected}) {
    return HouseholdTask(
      id: id,
      title: title,
      description: description,
      owner: owner,
      status: status ?? this.status,
      selected: selected ?? this.selected,
      applianceNames: applianceNames,
      airPurifierDeviceId: airPurifierDeviceId,
    );
  }
}

abstract final class HouseholdTaskMockData {
  static const tasks = [
    HouseholdTask(
      id: 'clear-table',
      title: '식탁 위 정리 — 서서 5분',
      description: '짧게 서서 할 수 있는 가벼운 정리',
      owner: HouseholdTaskOwner.self,
    ),
    HouseholdTask(
      id: 'water-plants',
      title: '화분 물주기 — 앉아서 가능',
      description: '무리되면 언제든 가족에게 넘길 수 있어요',
      owner: HouseholdTaskOwner.self,
    ),
    HouseholdTask(
      id: 'vacuum',
      title: '거실 바닥 청소',
      description: '로봇청소기 · 약 25분',
      owner: HouseholdTaskOwner.appliance,
    ),
    HouseholdTask(
      id: 'laundry',
      title: '빨래 — 세탁부터 건조까지',
      description: '널지 않아도 되도록 건조기 자동 연결',
      owner: HouseholdTaskOwner.appliance,
    ),
    HouseholdTask(
      id: 'dishes',
      title: '설거지',
      description: '식기세척기 · 숙이는 시간 줄이기',
      owner: HouseholdTaskOwner.appliance,
    ),
    HouseholdTask(
      id: 'heavy-items',
      title: '장보기 · 무거운 것 옮기기',
      description: '드는 동작이 많아 오늘은 남편이 맡으면 좋아요',
      owner: HouseholdTaskOwner.partner,
      selected: true,
    ),
  ];
}
