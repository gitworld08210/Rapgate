import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory AccountabilityLinkModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AccountabilityLinkModel(
      linkedContactUid: data['linkedContactUid'] as String?,
      contactPhone: data['contactPhone'] as String?,
      contactName: data['contactName'] as String?,
      notifyOnMiss: data['notifyOnMiss'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'linkedContactUid': linkedContactUid,
        'contactPhone': contactPhone,
        'contactName': contactName,
        'notifyOnMiss': notifyOnMiss,
      };

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
