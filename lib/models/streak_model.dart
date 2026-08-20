import 'package:cloud_firestore/cloud_firestore.dart';

class StreakModel {
  final int currentPushupStreak;
  final int longestPushupStreak;
  final int currentFoodLogStreak;
  final DateTime? lastPushupDate;
  final DateTime? lastFoodLogDate;

  StreakModel({
    this.currentPushupStreak = 0,
    this.longestPushupStreak = 0,
    this.currentFoodLogStreak = 0,
    this.lastPushupDate,
    this.lastFoodLogDate,
  });

  factory StreakModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StreakModel(
      currentPushupStreak: data['currentPushupStreak'] ?? 0,
      longestPushupStreak: data['longestPushupStreak'] ?? 0,
      currentFoodLogStreak: data['currentFoodLogStreak'] ?? 0,
      lastPushupDate: (data['lastPushupDate'] as Timestamp?)?.toDate(),
      lastFoodLogDate: (data['lastFoodLogDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'currentPushupStreak': currentPushupStreak,
      'longestPushupStreak': longestPushupStreak,
      'currentFoodLogStreak': currentFoodLogStreak,
      'lastPushupDate': lastPushupDate != null
          ? Timestamp.fromDate(lastPushupDate!)
          : null,
      'lastFoodLogDate': lastFoodLogDate != null
          ? Timestamp.fromDate(lastFoodLogDate!)
          : null,
    };
  }
}
