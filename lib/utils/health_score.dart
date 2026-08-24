import 'constants.dart';

/// Composite 0-10 daily health score across nutrition, hydration and activity.
///
/// Pure function with no widget dependencies, usable from any screen or test.
double computeHealthScore({
  required double calories,
  required double calorieTarget,
  required double protein,
  required double proteinTarget,
  required int waterMl,
  required bool pushupsDone,
}) {
  double score = 0;

  // Calories within +/-15% of target = full marks (3 pts)
  if (calorieTarget > 0) {
    final ratio = calories / calorieTarget;
    if (ratio >= 0.85 && ratio <= 1.15) {
      score += 3;
    } else if (ratio >= 0.6 && ratio <= 1.4) {
      score += 1.5;
    } else if (calories > 0) {
      score += 0.5;
    }
  }

  // Protein (3 pts)
  if (proteinTarget > 0) {
    score += (protein / proteinTarget).clamp(0.0, 1.0) * 3;
  }

  // Hydration (2 pts)
  score += (waterMl / AppConstants.dailyWaterTargetMl).clamp(0.0, 1.0) * 2;

  // Push-ups verified (2 pts)
  if (pushupsDone) score += 2;

  return score.clamp(0, 10);
}
