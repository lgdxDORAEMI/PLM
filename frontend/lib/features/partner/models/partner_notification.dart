enum PartnerNotificationType { morningReport, householdRequest, routineChanged }

class PartnerNotificationItem {
  const PartnerNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.reportDate,
    this.requestId,
    this.read = false,
  });

  final String id;
  final PartnerNotificationType type;
  final String title;
  final String message;
  final String timeLabel;
  final String? reportDate;
  final String? requestId;
  final bool read;

  PartnerNotificationItem copyWith({bool? read}) => PartnerNotificationItem(
    id: id,
    type: type,
    title: title,
    message: message,
    timeLabel: timeLabel,
    reportDate: reportDate,
    requestId: requestId,
    read: read ?? this.read,
  );

  factory PartnerNotificationItem.fromJson(Map<String, dynamic> json) {
    final type = switch (json['type']) {
      'household_request' => PartnerNotificationType.householdRequest,
      'condition_changed' => PartnerNotificationType.routineChanged,
      _ => PartnerNotificationType.morningReport,
    };
    final referenceId = json['reference_id']?.toString();
    final targetDate = json['target_date']?.toString();
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    return PartnerNotificationItem(
      id: json['notification_id']?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? '',
      message: json['body']?.toString() ?? '',
      timeLabel: createdAt == null ? '' : _timeLabel(createdAt.toLocal()),
      reportDate: targetDate,
      requestId: type == PartnerNotificationType.householdRequest
          ? referenceId
          : null,
      read: json['read_at'] != null,
    );
  }
}

String _timeLabel(DateTime value) =>
    '${value.month}월 ${value.day}일 '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
