enum PartnerRequestStatus { requested, confirmed, completed }

class PartnerRequestData {
  const PartnerRequestData({
    required this.id,
    required this.requester,
    required this.reason,
    required this.tasks,
    required this.supportingInfo,
    this.status = PartnerRequestStatus.requested,
  });

  final String id;
  final String requester;
  final String reason;
  final List<String> tasks;
  final String supportingInfo;
  final PartnerRequestStatus status;

  PartnerRequestData copyWith({PartnerRequestStatus? status}) =>
      PartnerRequestData(
        id: id,
        requester: requester,
        reason: reason,
        tasks: tasks,
        supportingInfo: supportingInfo,
        status: status ?? this.status,
      );
}
