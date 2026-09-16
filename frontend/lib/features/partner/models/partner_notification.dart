enum PartnerNotificationType { morningReport, householdRequest }

class PartnerNotificationItem {
  const PartnerNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.read = false,
  });

  final String id;
  final PartnerNotificationType type;
  final String title;
  final String message;
  final String timeLabel;
  final bool read;

  PartnerNotificationItem copyWith({bool? read}) => PartnerNotificationItem(
    id: id,
    type: type,
    title: title,
    message: message,
    timeLabel: timeLabel,
    read: read ?? this.read,
  );
}
