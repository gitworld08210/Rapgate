import 'dart:async';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../utils/height_calculator.dart';

/// Service that uses ML Kit Pose Detection to estimate a person's height
/// from a camera image. Processes frames in real-time and provides
/// positioning feedback and height estimation.
class HeightMeasurementService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  /// Number of consistent readings required before finalizing a measurement.
  static const int requiredConsistentReadings = 5;

  /// Maximum allowed variance between readings (in cm) to be considered consistent.
  static const double maxVarianceCm = 3.0;

  /// Default distance from camera to subject in centimeters.
  static const double defaultDistanceCm = 300.0;

  final List<double> _heightReadings = [];
  final List<HeightMeasurementFrame> _recentFrames = [];

  bool _isProcessing = false;

  PoseDetector get poseDetector => _poseDetector;

  /// Process a camera image and return the measurement frame result.
  ///
  /// Returns null if the frame could not be processed (e.g., already processing).
  Future<HeightMeasurementFrame?> processFrame(
    InputImage inputImage, {
    double cameraDistanceCm = defaultDistanceCm,
    double cameraFovDegrees = HeightCalculator.defaultCameraFovDegrees,
  }) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        return HeightMeasurementFrame(
          feedback: HeightMeasurementFeedback.noPersonDetected,
          landmarks: null,
          estimatedHeightCm: null,
          qualityScore: 0.0,
        );
      }

      final pose = poses.first;
      final landmarks = _extractHeightLandmarks(pose);

      if (landmarks == null) {
        return HeightMeasurementFrame(
          feedback: HeightMeasurementFeedback.noPersonDetected,
          landmarks: null,
          estimatedHeightCm: null,
          qualityScore: 0.0,
        );
      }

      final imageSize = inputImage.metadata?.size;
      final imageHeight = imageSize?.height ?? 1280.0;
      final imageWidth = imageSize?.width ?? 720.0;

      // Get positioning feedback
      final feedback = HeightCalculator.getPositioningFeedback(
        headY: landmarks.headY,
        feetY: landmarks.feetY,
        imageHeight: imageHeight,
        imageWidth: imageWidth,
        headX: landmarks.headX,
      );

      double? estimatedHeight;
      double qualityScore = 0.0;

      if (feedback.isReady) {
        // Estimate height using the pinhole camera model
        estimatedHeight = HeightCalculator.estimateHeightFromPose(
          headY: landmarks.headY,
          feetY: landmarks.feetY,
          imageHeight: imageHeight,
          imageWidth: imageWidth,
          cameraDistanceCm: cameraDistanceCm,
          cameraFovDegrees: cameraFovDegrees,
        );

        qualityScore = HeightCalculator.calculateQualityScore(
          pixelHeight: (landmarks.feetY - landmarks.headY).abs(),
          imageHeight: imageHeight,
          leftAnkleY: landmarks.leftAnkleY,
          rightAnkleY: landmarks.rightAnkleY,
          headY: landmarks.headY,
        );

        if (estimatedHeight != null) {
          _heightReadings.add(estimatedHeight);
          // Keep only the last 10 readings
          if (_heightReadings.length > 10) {
            _heightReadings.removeAt(0);
          }
        }
      }

      final frame = HeightMeasurementFrame(
        feedback: feedback,
        landmarks: landmarks,
        estimatedHeightCm: estimatedHeight,
        qualityScore: qualityScore,
      );

      _recentFrames.add(frame);
      if (_recentFrames.length > 20) {
        _recentFrames.removeAt(0);
      }

      return frame;
    } catch (e) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Check if we have enough consistent readings for a final measurement.
  bool get hasConsistentMeasurement {
    if (_heightReadings.length < requiredConsistentReadings) return false;

    final recent = _heightReadings.sublist(
      _heightReadings.length - requiredConsistentReadings,
    );

    final avg = recent.reduce((a, b) => a + b) / recent.length;
    final maxDeviation = recent
        .map((r) => (r - avg).abs())
        .reduce((a, b) => a > b ? a : b);

    return maxDeviation <= maxVarianceCm;
  }

  /// Get the final averaged height measurement.
  ///
  /// Returns null if there are not enough consistent readings.
  double? get finalMeasurement {
    if (!hasConsistentMeasurement) return null;

    final recent = _heightReadings.sublist(
      _heightReadings.length - requiredConsistentReadings,
    );

    return recent.reduce((a, b) => a + b) / recent.length;
  }

  /// Extract height-relevant landmarks from a detected pose.
  HeightLandmarks? _extractHeightLandmarks(Pose pose) {
    // Get head landmark (use nose as reference, add offset for top of head)
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    // Get ankle landmarks for feet
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Get shoulder landmarks for posture check
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    // Get hip landmarks for body midpoint
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    // Require at minimum: head reference and at least one ankle
    if (nose == null || (leftAnkle == null && rightAnkle == null)) {
      return null;
    }

    // Calculate head top: nose + estimated offset (forehead to top of head)
    // The top of head is approximately 20% of face height above the nose
    double headTopY = nose.y;
    if (leftEye != null && rightEye != null) {
      // Distance from eyes to nose gives approximate face proportion
      final eyeToNose = (nose.y - ((leftEye.y + rightEye.y) / 2)).abs();
      // Top of head is approximately 2.5x this distance above the eyes
      headTopY = nose.y - (eyeToNose * 3.5);
    } else {
      // Fallback: offset by a fixed pixel amount (scaled by detected body size)
      if (leftAnkle != null || rightAnkle != null) {
        final ankleY = leftAnkle?.y ?? rightAnkle!.y;
        final bodyPixelHeight = ankleY - nose.y;
        headTopY = nose.y - (bodyPixelHeight * 0.08); // Head is ~8% of body height above nose
      }
    }

    // Calculate feet position (midpoint of ankles, or single ankle)
    double feetY;
    double leftAnkleYPos;
    double rightAnkleYPos;
    if (leftAnkle != null && rightAnkle != null) {
      feetY = (leftAnkle.y + rightAnkle.y) / 2.0;
      leftAnkleYPos = leftAnkle.y;
      rightAnkleYPos = rightAnkle.y;
    } else if (leftAnkle != null) {
      feetY = leftAnkle.y;
      leftAnkleYPos = leftAnkle.y;
      rightAnkleYPos = leftAnkle.y;
    } else {
      feetY = rightAnkle!.y;
      leftAnkleYPos = rightAnkle.y;
      rightAnkleYPos = rightAnkle.y;
    }

    return HeightLandmarks(
      headX: nose.x,
      headY: headTopY,
      noseY: nose.y,
      feetY: feetY,
      leftAnkleY: leftAnkleYPos,
      rightAnkleY: rightAnkleYPos,
      leftAnkleX: leftAnkle?.x,
      rightAnkleX: rightAnkle?.x,
      leftShoulderX: leftShoulder?.x,
      leftShoulderY: leftShoulder?.y,
      rightShoulderX: rightShoulder?.x,
      rightShoulderY: rightShoulder?.y,
      leftHipX: leftHip?.x,
      leftHipY: leftHip?.y,
      rightHipX: rightHip?.x,
      rightHipY: rightHip?.y,
    );
  }

  /// Reset all collected readings.
  void reset() {
    _heightReadings.clear();
    _recentFrames.clear();
  }

  /// Dispose of the pose detector resources.
  void dispose() {
    _poseDetector.close();
  }
}

/// Detected landmarks relevant to height measurement.
class HeightLandmarks {
  final double headX;
  final double headY;
  final double noseY;
  final double feetY;
  final double leftAnkleY;
  final double rightAnkleY;
  final double? leftAnkleX;
  final double? rightAnkleX;
  final double? leftShoulderX;
  final double? leftShoulderY;
  final double? rightShoulderX;
  final double? rightShoulderY;
  final double? leftHipX;
  final double? leftHipY;
  final double? rightHipX;
  final double? rightHipY;

  const HeightLandmarks({
    required this.headX,
    required this.headY,
    required this.noseY,
    required this.feetY,
    required this.leftAnkleY,
    required this.rightAnkleY,
    this.leftAnkleX,
    this.rightAnkleX,
    this.leftShoulderX,
    this.leftShoulderY,
    this.rightShoulderX,
    this.rightShoulderY,
    this.leftHipX,
    this.leftHipY,
    this.rightHipX,
    this.rightHipY,
  });
}

/// Result of processing a single camera frame for height measurement.
class HeightMeasurementFrame {
  final HeightMeasurementFeedback feedback;
  final HeightLandmarks? landmarks;
  final double? estimatedHeightCm;
  final double qualityScore;

  const HeightMeasurementFrame({
    required this.feedback,
    required this.landmarks,
    required this.estimatedHeightCm,
    required this.qualityScore,
  });
}
