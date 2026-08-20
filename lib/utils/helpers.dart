import 'dart:math';
import 'package:intl/intl.dart';

/// Calculates the angle between three points (in degrees)
/// Used for elbow angle calculation in push-up detection
double calculateAngle(
  ({double x, double y}) pointA,
  ({double x, double y}) pointB, // vertex
  ({double x, double y}) pointC,
) {
  final radians = atan2(pointC.y - pointB.y, pointC.x - pointB.x) -
      atan2(pointA.y - pointB.y, pointA.x - pointB.x);
  var angle = radians * 180 / pi;
  if (angle < 0) angle += 360;
  if (angle > 180) angle = 360 - angle;
  return angle;
}

/// Format calories display
String formatCalories(double calories) {
  if (calories >= 1000) {
    return '${(calories / 1000).toStringAsFixed(1)}k';
  }
  return calories.toStringAsFixed(0);
}

/// Format weight display
String formatWeight(double weightKg) {
  return '${weightKg.toStringAsFixed(1)} kg';
}

/// Format water display
String formatWaterMl(int ml) {
  if (ml >= 1000) {
    return '${(ml / 1000).toStringAsFixed(1)} L';
  }
  return '$ml ml';
}

/// Format date for display
String formatDate(DateTime date) {
  return DateFormat('dd MMM yyyy').format(date);
}

/// Format time for display
String formatTime(DateTime time) {
  return DateFormat('hh:mm a').format(time);
}

/// Format date and time
String formatDateTime(DateTime dateTime) {
  return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
}

/// Check if a date is today
bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

/// Check if a date is yesterday
bool isYesterday(DateTime date) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day;
}

/// Calculate BMI
double calculateBMI(double weightKg, double heightCm) {
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

/// Get BMI category
String getBMICategory(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25.0) return 'Normal';
  if (bmi < 30.0) return 'Overweight';
  return 'Obese';
}

/// Calculate daily calorie target based on user profile
/// Uses Mifflin-St Jeor equation
double calculateDailyCalorieTarget({
  required double weightKg,
  required double heightCm,
  required int age,
  required String gender,
  double activityMultiplier = 1.375, // lightly active default
}) {
  double bmr;
  if (gender.toLowerCase() == 'male') {
    bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
  } else {
    bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
  }
  return bmr * activityMultiplier;
}

/// Calculate daily protein target (1.6g per kg body weight for active)
double calculateDailyProteinTarget(double weightKg) {
  return weightKg * 1.6;
}

/// Generate a streak message
String getStreakMessage(int streak) {
  if (streak == 0) return 'Start your streak today! 💪';
  if (streak < 3) return '$streak day streak! Keep going! 🔥';
  if (streak < 7) return '$streak day streak! You\'re on fire! 🔥🔥';
  if (streak < 14) return '$streak day streak! Unstoppable! 🔥🔥🔥';
  if (streak < 30) return '$streak day streak! Legend! 🏆';
  return '$streak day streak! You\'re a machine! 💎🏆';
}

/// Validate motion variance (anti-cheat)
bool isMotionVarianceValid(List<double> accelerometerReadings) {
  if (accelerometerReadings.length < 10) return false;
  final mean =
      accelerometerReadings.reduce((a, b) => a + b) / accelerometerReadings.length;
  final variance = accelerometerReadings
          .map((x) => pow(x - mean, 2))
          .reduce((a, b) => a + b) /
      accelerometerReadings.length;
  return variance > 0.01; // threshold from constants
}
