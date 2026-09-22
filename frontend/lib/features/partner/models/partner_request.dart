enum PartnerRequestStatus { requested, confirmed, completed }

class PartnerRequestTask {
  const PartnerRequestTask({
    required this.id,
    required this.title,
    this.description = '',
    this.routineItemId,
    this.status = PartnerRequestStatus.requested,
  });

  final String id;
  final String title;
  final String description;
  final String? routineItemId;
  final PartnerRequestStatus status;

  PartnerRequestTask copyWith({PartnerRequestStatus? status}) =>
      PartnerRequestTask(
        id: id,
        title: title,
        description: description,
        routineItemId: routineItemId,
        status: status ?? this.status,
      );

  factory PartnerRequestTask.fromJson(Map<String, dynamic> json) =>
      PartnerRequestTask(
        id: json['item_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['helper_info']?.toString() ?? '',
        routineItemId: json['routine_item_id']?.toString(),
        status: _requestStatus(json['status']),
      );
}

class HouseholdDailySummary {
  const HouseholdDailySummary({
    required this.requested,
    required this.confirmed,
    required this.completed,
  });

  final int requested;
  final int confirmed;
  final int completed;

  factory HouseholdDailySummary.fromJson(Map<String, dynamic> json) =>
      HouseholdDailySummary(
        requested: (json['requested'] as num?)?.toInt() ?? 0,
        confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
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
    this.requestedAt,
    this.dailySummary,
  });

  final String id;
  final String requester;
  final String reason;
  final List<PartnerRequestTask> tasks;
  final String supportingInfo;
  final String recordDate;
  final DateTime? requestedAt;
  final HouseholdDailySummary? dailySummary;

  // 이 요청 1건만의 확인/완료 여부 — status getter가 여기에 의존하므로
  // dailySummary(그날 전체 합산)로 바꾸면 안 됨. 화면 표시용 합산 값은
  // daily*Count getter를 대신 쓴다.
  int get confirmedCount => tasks
      .where((task) => task.status != PartnerRequestStatus.requested)
      .length;
  int get completedCount => tasks
      .where((task) => task.status == PartnerRequestStatus.completed)
      .length;

  int get dailyRequestedCount => dailySummary?.requested ?? tasks.length;
  int get dailyConfirmedCount => dailySummary?.confirmed ?? confirmedCount;
  int get dailyCompletedCount => dailySummary?.completed ?? completedCount;

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
        requestedAt: requestedAt,
        dailySummary: dailySummary,
      );

  factory PartnerRequestData.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('가사 요청 응답 형식이 올바르지 않습니다.');
    }
    final dailySummary = json['daily_summary'];
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
      requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? ''),
      dailySummary: dailySummary is Map
          ? HouseholdDailySummary.fromJson(dailySummary.cast())
          : null,
    );
  }
}

PartnerRequestStatus _requestStatus(Object? value) => switch (value) {
  'confirmed' => PartnerRequestStatus.confirmed,
  'completed' => PartnerRequestStatus.completed,
  _ => PartnerRequestStatus.requested,
};
