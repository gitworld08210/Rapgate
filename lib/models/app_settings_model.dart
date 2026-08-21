/// Server-managed app settings (UPI details, fine amount, etc.).
///
/// The single-row `app_settings` table is the source of truth.
/// [AppConstants] values serve as fallbacks when the fetch fails.
class AppSettings {
  const AppSettings({
    required this.upiId,
    required this.upiPayeeName,
    required this.fineAmountPaise,
    this.updatedAt,
  });

  final String upiId;
  final String upiPayeeName;
  final int fineAmountPaise;
  final DateTime? updatedAt;

  double get amountInRupees => fineAmountPaise / 100;

  String get amountLabel => '\u20B9${amountInRupees.toStringAsFixed(0)}';

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      upiId: map['upi_id'] as String? ?? '',
      upiPayeeName: map['upi_payee_name'] as String? ?? '',
      fineAmountPaise: (map['fine_amount_paise'] as num?)?.toInt() ?? 5000,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }
}
