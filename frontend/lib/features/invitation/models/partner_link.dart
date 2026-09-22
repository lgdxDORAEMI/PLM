class PartnerLink {
  const PartnerLink({
    required this.linked,
    this.partnerDisplayName,
    this.myDisplayName,
  });

  factory PartnerLink.fromJson(Map<String, dynamic> json) => PartnerLink(
    linked: json['status'] == 'linked',
    partnerDisplayName: json['partner_display_name'] as String?,
    myDisplayName: json['my_display_name'] as String?,
  );

  final bool linked;
  final String? partnerDisplayName;
  final String? myDisplayName;
}
