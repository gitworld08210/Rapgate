import 'dart:math';

/// Pure math utility for camera-based height estimation.
///
/// Uses the pinhole camera model to estimate a person's real height
/// from their pixel height in an image, given the camera's field of view
/// and the distance from the camera to the subject.
class HeightCalculator {
  HeightCalculator._();

  /// Default horizontal field of view for a typical smartphone rear camera (degrees).
  static const double defaultCameraFovDegrees = 70.0;

  /// Minimum acceptable pixel ratio (person height vs image height) for a valid reading.
  static const double minPixelRatio = 0.3;

  /// Maximum acceptable pixel ratio (person should not fill the entire frame).
  static const double maxPixelRatio = 0.95;

  /// Estimates real height (in cm) from detected pose landmarks.
  ///
  /// [headY] - Y coordinate of the top-of-head landmark (nose with offset) in pixels.
  /// [feetY] - Y coordinate of the feet (midpoint of ankles) in pixels.
  /// [imageHeight] - Total height of the camera image in pixels.
  /// [imageWidth] - Total width of the camera image in pixels.
  /// [cameraDistanceCm] - Distance from camera to subject in centimeters.
  /// [cameraFovDegrees] - Horizontal field of view of the camera in degrees.
  ///
  /// Returns estimated height in centimeters, or null if the measurement is invalid.
  static double? estimateHeightFromPose({
    required double headY,
    required double feetY,
    required double imageHeight,
    required double imageWidth,
    required double cameraDistanceCm,
    double cameraFovDegrees = defaultCameraFovDegrees,
  }) {
    if (imageHeight <= 0 || imageWidth <= 0 || cameraDistanceCm <= 0) {
      return null;
    }

    // Calculate pixel height of the person in the image
    final pixelHeight = (feetY - headY).abs();
    if (pixelHeight <= 0) return null;

    // Validate pixel ratio - person should be reasonably visible
    final pixelRatio = pixelHeight / imageHeight;
    if (pixelRatio < minPixelRatio || pixelRatio > maxPixelRatio) {
      return null;
    }

    // Pinhole camera model:
    // realHeight / distance = pixelHeight / focalLengthPixels
    // focalLengthPixels = (imageWidth / 2) / tan(fov/2)
    final fovRadians = cameraFovDegrees * pi / 180.0;
    final focalLengthPixels = (imageWidth / 2.0) / tan(fovRadians / 2.0);

    // Calculate the vertical FOV focal length (using image height for vertical axis)
    final aspectRatio = imageHeight / imageWidth;
    final verticalFovRadians = 2.0 * atan(aspectRatio * tan(fovRadians / 2.0));
    final verticalFocalLength = (imageHeight / 2.0) / tan(verticalFovRadians / 2.0);

    // Estimate real height using the vertical focal length
    final realHeightCm = (pixelHeight * cameraDistanceCm) / verticalFocalLength;

    // Sanity check: human height should be between 50cm and 250cm
    if (realHeightCm < 50.0 || realHeightCm > 250.0) {
      return null;
    }

    return realHeightCm;
  }

  /// Simplified height estimation using proportional method.
  ///
  /// Uses the ratio of the person's pixel height to the image frame height,
  /// combined with the known distance and camera FOV to estimate real height.
  /// This is more forgiving of slight inaccuracies in landmark detection.
  static double? estimateHeightProportional({
    required double pixelHeight,
    required double imageHeight,
    required double cameraDistanceCm,
    double cameraFovDegrees = defaultCameraFovDegrees,
  }) {
    if (imageHeight <= 0 || pixelHeight <= 0 || cameraDistanceCm <= 0) {
      return null;
    }

    final pixelRatio = pixelHeight / imageHeight;
    if (pixelRatio < minPixelRatio || pixelRatio > maxPixelRatio) {
      return null;
    }

    // Calculate the real-world height of the visible vertical frame at the subject's distance
    final fovRadians = cameraFovDegrees * pi / 180.0;
    // For vertical: adjust by aspect ratio (assuming portrait mode with 9:16 or similar)
    final aspectRatio = 16.0 / 9.0; // Standard portrait aspect ratio
    final verticalFovRadians = 2.0 * atan(aspectRatio * tan(fovRadians / 2.0));

    // Total visible height at the distance
    final totalVisibleHeightCm = 2.0 * cameraDistanceCm * tan(verticalFovRadians / 2.0);

    // Person's real height is proportional to their pixel coverage
    final realHeightCm = totalVisibleHeightCm * pixelRatio;

    if (realHeightCm < 50.0 || realHeightCm > 250.0) {
      return null;
    }

    return realHeightCm;
  }

  /// Calculates the quality score of a measurement (0.0 to 1.0).
  ///
  /// Considers: pixel ratio, symmetry of ankles, head position stability.
  static double calculateQualityScore({
    required double pixelHeight,
    required double imageHeight,
    required double leftAnkleY,
    required double rightAnkleY,
    required double headY,
  }) {
    double score = 0.0;

    // Pixel ratio score - best when person fills 50-80% of frame
    final ratio = pixelHeight / imageHeight;
    if (ratio >= 0.5 && ratio <= 0.8) {
      score += 0.4;
    } else if (ratio >= 0.4 && ratio <= 0.9) {
      score += 0.25;
    } else {
      score += 0.1;
    }

    // Ankle symmetry score - both ankles should be at similar Y position
    final ankleYDiff = (leftAnkleY - rightAnkleY).abs();
    final ankleSymmetry = 1.0 - (ankleYDiff / imageHeight).clamp(0.0, 1.0);
    score += 0.3 * ankleSymmetry;

    // Head position score - head should be in upper portion of frame
    final headRatio = headY / imageHeight;
    if (headRatio >= 0.05 && headRatio <= 0.3) {
      score += 0.3;
    } else if (headRatio >= 0.0 && headRatio <= 0.4) {
      score += 0.2;
    } else {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Returns positioning feedback based on detected landmarks.
  static HeightMeasurementFeedback getPositioningFeedback({
    required double? headY,
    required double? feetY,
    required double imageHeight,
    required double imageWidth,
    required double? headX,
  }) {
    if (headY == null || feetY == null) {
      return HeightMeasurementFeedback.noPersonDetected;
    }

    final pixelHeight = (feetY - headY).abs();
    final pixelRatio = pixelHeight / imageHeight;

    // Check if person is too close (fills too much of the frame)
    if (pixelRatio > maxPixelRatio) {
      return HeightMeasurementFeedback.tooClose;
    }

    // Check if person is too far
    if (pixelRatio < minPixelRatio) {
      return HeightMeasurementFeedback.tooFar;
    }

    // Check horizontal centering
    if (headX != null) {
      final centerOffset = (headX - imageWidth / 2).abs() / imageWidth;
      if (centerOffset > 0.25) {
        return HeightMeasurementFeedback.moveToCenter;
      }
    }

    // Check if head is cut off (too high in frame)
    if (headY < imageHeight * 0.03) {
      return HeightMeasurementFeedback.moveBack;
    }

    // Check if feet are cut off (too low in frame)
    if (feetY > imageHeight * 0.97) {
      return HeightMeasurementFeedback.moveBack;
    }

    return HeightMeasurementFeedback.perfect;
  }

  /// Applies a correction factor based on the camera height relative to the subject.
  ///
  /// If the camera is not at the subject's midpoint, perspective distortion
  /// occurs. This applies a correction to compensate.
  static double applyCameraHeightCorrection({
    required double rawHeightCm,
    required double cameraHeightCm,
    required double cameraDistanceCm,
  }) {
    // If camera is at floor level (tripod/propped), there is a slight
    // perspective foreshortening for the upper body.
    // Correction factor based on the angle of elevation to the subject's midpoint.
    final subjectMidpointCm = rawHeightCm / 2.0;
    final heightDifference = subjectMidpointCm - cameraHeightCm;
    final angleRad = atan2(heightDifference, cameraDistanceCm);

    // Small correction - cos(angle) accounts for the perspective
    final correctionFactor = 1.0 / cos(angleRad);
    return rawHeightCm * correctionFactor;
  }
}

/// Feedback states for height measurement positioning.
enum HeightMeasurementFeedback {
  noPersonDetected,
  tooClose,
  tooFar,
  moveToCenter,
  moveBack,
  standStraight,
  perfect,
}

extension HeightMeasurementFeedbackExtension on HeightMeasurementFeedback {
  String get message {
    switch (this) {
      case HeightMeasurementFeedback.noPersonDetected:
        return 'Stand in front of the camera';
      case HeightMeasurementFeedback.tooClose:
        return 'Move back from the camera';
      case HeightMeasurementFeedback.tooFar:
        return 'Step closer to the camera';
      case HeightMeasurementFeedback.moveToCenter:
        return 'Move to the center of the frame';
      case HeightMeasurementFeedback.moveBack:
        return 'Step back so your full body is visible';
      case HeightMeasurementFeedback.standStraight:
        return 'Stand up straight';
      case HeightMeasurementFeedback.perfect:
        return 'Perfect! Hold still...';
    }
  }

  bool get isReady => this == HeightMeasurementFeedback.perfect;
}
