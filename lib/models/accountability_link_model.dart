/// Opt-in accountability partner who gets notified when a streak breaks.
class AccountabilityLinkModel {
  const AccountabilityLinkModel({
    this.linkedContactUid,
    this.contactPhone,
    this.contactName,
    this.notifyOnMiss = false,
  });

  final String? linkedContactUid;
  final String? contactPhone;
  final String? contactName;
  final bool notifyOnMiss;

  bool get isConfigured =>
      notifyOnMiss &&
      ((contactPhone?.isNotEmpty ?? false) ||
          (linkedContactUid?.isNotEmpty ?? false));

  factory AccountabilityLinkModel.fromMap(Map<String, dynamic> data) {
    return AccountabilityLinkModel(
      linkedContactUid: data['linked_contact_uid'] as String?,
      contactPhone: data['contact_phone'] as String?,
      contactName: data['contact_name'] as String?,
      notifyOnMiss: data['notify_on_miss'] as bool? ?? false,
    );
  }

  AccountabilityLinkModel copyWith({
    String? linkedContactUid,
    String? contactPhone,
    String? contactName,
    bool? notifyOnMiss,
  }) {
    return AccountabilityLinkModel(
      linkedContactUid: linkedContactUid ?? this.linkedContactUid,
      contactPhone: contactPhone ?? this.contactPhone,
      contactName: contactName ?? this.contactName,
      notifyOnMiss: notifyOnMiss ?? this.notifyOnMiss,
    );
  }
}
