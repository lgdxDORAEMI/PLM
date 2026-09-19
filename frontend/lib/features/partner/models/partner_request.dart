enum PartnerRequestStatus { requested, confirmed, completed }

class PartnerRequestTask {
  const PartnerRequestTask({
    required this.id,
    required this.title,
    this.description = '',
    this.status = PartnerRequestStatus.requested,
  });

  final String id;
  final String title;
  final String description;
  final PartnerRequestStatus status;

  PartnerRequestTask copyWith({PartnerRequestStatus? status}) =>
      PartnerRequestTask(
        id: id,
        title: title,
        description: description,
        status: status ?? this.status,
      );

  factory PartnerRequestTask.fromJson(Map<String, dynamic> json) =>
      PartnerRequestTask(
        id: json['item_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['helper_info']?.toString() ?? '',
        status: _requestStatus(json['status']),
      );
}

class PartnerRequestData {
  const PartnerRequestData({
    required this.id,
    required this.requester,
    required this.reason,
    required this.tasks,
    required this.supportingInfo,
    this.recordDate = '2026-09-13',
  });

  final String id;
  final String requester;
  final String reason;
  final List<PartnerRequestTask> tasks;
  final String supportingInfo;
  final String recordDate;

  int get confirmedCount => tasks
      .where((task) => task.status != PartnerRequestStatus.requested)
      .length;
  int get completedCount => tasks
      .where((task) => task.status == PartnerRequestStatus.completed)
      .length;

  PartnerRequestStatus get status {
    if (tasks.isNotEmpty && completedCount == tasks.length) {
      return PartnerRequestStatus.completed;
    }
    if (confirmedCount > 0) return PartnerRequestStatus.confirmed;
    return PartnerRequestStatus.requested;
  }

  PartnerRequestData copyWith({List<PartnerRequestTask>? tasks}) =>
      PartnerRequestData(
        id: id,
        requester: requester,
        reason: reason,
        tasks: tasks ?? this.tasks,
        supportingInfo: supportingInfo,
        recordDate: recordDate,
      );

  factory PartnerRequestData.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('가사 요청 응답 형식이 올바르지 않습니다.');
    }
    return PartnerRequestData(
      id: json['request_id']?.toString() ?? '',
      requester: json['requester_display_name']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      tasks: items
          .whereType<Map>()
          .map((item) => PartnerRequestTask.fromJson(item.cast()))
          .toList(growable: false),
      supportingInfo: '',
      recordDate: json['target_date']?.toString() ?? '',
    );
  }
}

PartnerRequestStatus _requestStatus(Object? value) => switch (value) {
  'confirmed' => PartnerRequestStatus.confirmed,
  'completed' => PartnerRequestStatus.completed,
  _ => PartnerRequestStatus.requested,
};
