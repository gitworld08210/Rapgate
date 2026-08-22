import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../models/height_measurement_model.dart';

/// Reference object dimensions used for pixel-to-cm calibration.
class ReferenceObject {
  final String type;
  final String label;
  final double heightCm;
  final double widthCm;

  const ReferenceObject({
    required this.type,
    required this.label,
    required this.heightCm,
    required this.widthCm,
  });

  /// A4 paper in portrait orientation: 29.7 cm height, 21 cm width
  static const a4Paper = ReferenceObject(
    type: 'a4_paper',
    label: 'A4 Paper',
    heightCm: 29.7,
    widthCm: 21.0,
  );

  /// Standard credit card: 8.56 cm width, 5.398 cm height
  static const creditCard = ReferenceObject(
    type: 'credit_card',
    label: 'Credit Card',
    heightCm: 5.398,
    widthCm: 8.56,
  );

  static List<ReferenceObject> get all => [a4Paper, creditCard];
}

/// Service for measuring user height using ML Kit pose detection
/// and reference object calibration.
class HeightMeasurementService {
  final SupabaseClient _db = supabase;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  PoseDetector get poseDetector => _poseDetector;

  /// Check if ARCore is available on this device.
  /// Returns false since we do not have the ARCore plugin installed.
  Future<bool> isARCoreAvailable() async {
    return false;
  }

  /// Check if LiDAR/ToF sensor is available on this device.
  /// Returns false since most Android phones lack ToF sensors and
  /// we do not have a dedicated plugin for it.
  Future<bool> isLiDARAvailable() async {
    return false;
  }

  /// Calculate height from pose landmarks using reference object calibration.
  ///
  /// [pose] - detected pose with full body visible
  /// [referenceObjectPixelHeight] - height of the reference object in pixels as detected in frame
  /// [referenceObject] - the reference object used for calibration
  ///
  /// Returns height in centimeters or null if landmarks are insufficient.
  double? calculateHeightFromPose({
    required Pose pose,
    required double referenceObjectPixelHeight,
    required ReferenceObject referenceObject,
  }) {
    // Get key landmarks for height measurement
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (nose == null) return null;
    if (leftAnkle == null && rightAnkle == null) return null;

    // Use the lower ankle (higher Y value in image coordinates)
    double ankleY;
    if (leftAnkle != null && rightAnkle != null) {
      ankleY = max(leftAnkle.y, rightAnkle.y);
    } else {
      ankleY = (leftAnkle ?? rightAnkle)!.y;
    }

    // Estimate top of head: nose + offset above nose
    // The top of the head is approximately 10-12% of total body height above
    // the nose. We estimate by using the eye-to-nose distance to project upward.
    double topOfHeadY;
    if (leftEye != null && rightEye != null) {
      final eyeY = (leftEye.y + rightEye.y) / 2;
      final noseToEyeDist = (nose.y - eyeY).abs();
      // Top of head is about 2x the nose-to-eye distance above the eyes
      topOfHeadY = eyeY - (noseToEyeDist * 2.0);
    } else {
      // Fallback: estimate top of head as 8% above nose relative to body
      final bodyPixelHeight = (ankleY - nose.y).abs();
      topOfHeadY = nose.y - (bodyPixelHeight * 0.08);
    }

    // Body pixel height from ankle to estimated top of head
    final bodyPixelHeight = (ankleY - topOfHeadY).abs();

    if (bodyPixelHeight <= 0 || referenceObjectPixelHeight <= 0) return null;

    // Calculate pixel-to-cm ratio from reference object
    final pixelToCmRatio = referenceObject.heightCm / referenceObjectPixelHeight;

    // Convert body pixel height to cm
    final heightCm = bodyPixelHeight * pixelToCmRatio;

    // Sanity check: human height should be between 50cm and 250cm
    if (heightCm < 50 || heightCm > 250) return null;

    return heightCm;
  }

  /// Check if a pose has enough landmarks for height measurement.
  bool isPoseValidForHeight(Pose pose) {
    final hasAnkle = pose.landmarks[PoseLandmarkType.leftAnkle] != null ||
        pose.landmarks[PoseLandmarkType.rightAnkle] != null;
    final hasHead = pose.landmarks[PoseLandmarkType.nose] != null;
    return hasAnkle && hasHead;
  }

  /// Get the pixel distance between ankles and head in a pose.
  /// Used for UI overlay display.
  ({double ankleY, double headY})? getBodyBounds(Pose pose) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (nose == null) return null;
    if (leftAnkle == null && rightAnkle == null) return null;

    double ankleY;
    if (leftAnkle != null && rightAnkle != null) {
      ankleY = max(leftAnkle.y, rightAnkle.y);
    } else {
      ankleY = (leftAnkle ?? rightAnkle)!.y;
    }

    double topOfHeadY;
    if (leftEye != null && rightEye != null) {
      final eyeY = (leftEye.y + rightEye.y) / 2;
      final noseToEyeDist = (nose.y - eyeY).abs();
      topOfHeadY = eyeY - (noseToEyeDist * 2.0);
    } else {
      final bodyPixelHeight = (ankleY - nose.y).abs();
      topOfHeadY = nose.y - (bodyPixelHeight * 0.08);
    }

    return (ankleY: ankleY, headY: topOfHeadY);
  }

  /// Save measured height to the user's profile in Supabase.
  Future<void> saveHeight(double heightCm) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _db.from('users').update({
      'height': heightCm.roundToDouble(),
    }).eq('id', userId);
  }

  /// Send height measurement report via email using edge function.
  Future<void> sendHeightReportEmail({
    required HeightMeasurementResult result,
  }) async {
    try {
      final response = await _db.functions.invoke(
        'send-height-report-email',
        body: {
          'measurements': result.measurements.map((m) => m.toMap()).toList(),
          'median': result.median,
          'average': result.average,
          'is_accuracy_mode': result.isAccuracyMode,
        },
      );

      if (response.status >= 400) {
        final raw = response.data;
        final data =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        throw Exception(
            data['error']?.toString() ?? 'Could not send the email.');
      }
    } on FunctionException catch (error) {
      if (error.status == 401) {
        throw Exception('Your session has expired. Please sign in again.');
      }
      throw Exception('Could not send the email. Please retry.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
          'Could not reach the server. Check your internet and try again.');
    }
  }

  void dispose() {
    _poseDetector.close();
  }
}
