class PartnerLink {
  const PartnerLink({required this.linked, this.partnerDisplayName});

  factory PartnerLink.fromJson(Map<String, dynamic> json) => PartnerLink(
    linked: json['status'] == 'linked',
    partnerDisplayName: json['partner_display_name'] as String?,
  );

  final bool linked;
  final String? partnerDisplayName;
}
