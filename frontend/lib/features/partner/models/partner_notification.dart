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
  }) : assert(
         (type == PartnerNotificationType.morningReport &&
                 reportDate != null) ||
             (type == PartnerNotificationType.householdRequest &&
                 requestId != null) ||
             (type == PartnerNotificationType.routineChanged &&
                 reportDate != null),
       );

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
}
