import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/constants.dart';

/// Handles push-up detection logic (on-device) and server verification
class PushupService {
  // Region-pinned — see AppConstants.functionsRegion.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion);

  // Pose detector instance
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  // Session state
  String? _currentSessionId;
  int _localRepCount = 0; // local tracking only, server is source of truth
  bool _isInDownPosition = false;
  int _framesWithFaceVisible = 0;
  int _totalFrames = 0;
  final List<Map<String, dynamic>> _landmarkBatch = [];
  final List<double> _motionReadings = [];

  // Getters
  String? get currentSessionId => _currentSessionId;
  int get localRepCount => _localRepCount;
  double get faceVisibilityRatio =>
      _totalFrames > 0 ? _framesWithFaceVisible / _totalFrames : 0.0;

  PoseDetector get poseDetector => _poseDetector;

  /// Start a new push-up session (calls Cloud Function)
  Future<({String sessionId, int requiredReps})> startSession() async {
    try {
      final result = await _functions
          .httpsCallable(AppConstants.cfStartPushupSession)
          .call({});

      final data = result.data as Map<String, dynamic>;
      _currentSessionId = data['sessionId'] as String;
      final requiredReps = data['requiredReps'] as int;

      // Reset local state
      _localRepCount = 0;
      _isInDownPosition = false;
      _framesWithFaceVisible = 0;
      _totalFrames = 0;
      _landmarkBatch.clear();
      _motionReadings.clear();

      return (sessionId: _currentSessionId!, requiredReps: requiredReps);
    } catch (e) {
      throw Exception('Failed to start push-up session: $e');
    }
  }

  /// Process a single frame's pose data
  /// Returns the current local rep count (for UI feedback only)
  PushupFrameResult processFrame(Pose pose) {
    // NOTE: Anti-cheat thresholds (minElbowAngleFlexed, faceVisibilityThreshold)
    // are intentionally server-verified. Do not weaken client-side checks without
    // updating functions/src/config.ts.
    _totalFrames++;

    // Check face visibility
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
    final isFaceVisible = nose != null && leftEye != null && rightEye != null;
    if (isFaceVisible) _framesWithFaceVisible++;

    // Calculate elbow angles (both arms)
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    double? leftElbowAngle;
    double? rightElbowAngle;

    if (leftShoulder != null && leftElbow != null && leftWrist != null) {
      leftElbowAngle = _calculateAngle(
        leftShoulder.toPoint(),
        leftElbow.toPoint(),
        leftWrist.toPoint(),
      );
    }

    if (rightShoulder != null && rightElbow != null && rightWrist != null) {
      rightElbowAngle = _calculateAngle(
        rightShoulder.toPoint(),
        rightElbow.toPoint(),
        rightWrist.toPoint(),
      );
    }

    // Use average of both elbows (or whichever is available)
    double? avgElbowAngle;
    if (leftElbowAngle != null && rightElbowAngle != null) {
      avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;
    } else {
      avgElbowAngle = leftElbowAngle ?? rightElbowAngle;
    }

    // Rep counting logic: extended → flexed → extended = 1 rep
    bool repCompleted = false;
    if (avgElbowAngle != null) {
      if (!_isInDownPosition &&
          avgElbowAngle <= AppConstants.minElbowAngleFlexed + 20) {
        // Entered down position (arms bent)
        _isInDownPosition = true;
      } else if (_isInDownPosition &&
          avgElbowAngle >= AppConstants.maxElbowAngleExtended - 20) {
        // Returned to up position = 1 rep complete
        _isInDownPosition = false;
        _localRepCount++;
        repCompleted = true;
      }
    }

    // Add to the landmark batch for server verification.
    //
    // Only the three fields the server actually reads are sent. Earlier this
    // also included leftElbowAngle/rightElbowAngle/noseY/leftShoulderY, which
    // more than doubled the upload size for data the verifier ignored.
    _landmarkBatch.add({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'avgElbowAngle': avgElbowAngle,
      'faceVisible': isFaceVisible,
    });

    return PushupFrameResult(
      localRepCount: _localRepCount,
      elbowAngle: avgElbowAngle,
      isFaceVisible: isFaceVisible,
      isInDownPosition: _isInDownPosition,
      repCompleted: repCompleted,
    );
  }

  /// Maximum accelerometer samples retained for the variance check.
  ///
  /// Variance is a distribution statistic — a few hundred samples characterise
  /// it just as well as tens of thousands, and this keeps memory flat over a
  /// long session instead of growing for the whole workout.
  static const int _maxMotionReadings = 600;

  /// Add an accelerometer reading for the motion-variance check.
  void addMotionReading(double magnitude) {
    _motionReadings.add(magnitude);
    if (_motionReadings.length > _maxMotionReadings) {
      _motionReadings.removeAt(0);
    }
  }

  /// Submit batch to server for verification
  /// Call this periodically or at end of session
  Future<({int validatedReps, bool sessionComplete})> submitBatch() async {
    if (_currentSessionId == null) {
      throw Exception('No active session');
    }

    try {
      final result = await _functions
          .httpsCallable(AppConstants.cfSubmitPushupFrameBatch)
          .call({
        'sessionId': _currentSessionId,
        'poseLandmarkBatch': _landmarkBatch,
        'frameMeta': {
          'faceVisible': faceVisibilityRatio >= AppConstants.faceVisibilityThreshold,
          'cameraFacing': 'front',
          'motionVariance': _calculateMotionVariance(),
          'totalFrames': _totalFrames,
          'framesWithFace': _framesWithFaceVisible,
        },
      });

      final data = result.data as Map<String, dynamic>;
      final validatedReps = data['currentValidatedReps'] as int;
      final sessionComplete = data['sessionComplete'] as bool;

      // Clear batch after successful submission
      _landmarkBatch.clear();

      return (validatedReps: validatedReps, sessionComplete: sessionComplete);
    } catch (e) {
      throw Exception('Failed to submit push-up batch: $e');
    }
  }

  /// Calculate angle between three points
  double _calculateAngle(Point3D a, Point3D b, Point3D c) {
    final radians = atan2(c.y - b.y, c.x - b.x) -
        atan2(a.y - b.y, a.x - b.x);
    var angle = radians * 180 / pi;
    if (angle < 0) angle += 360;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  /// Calculate motion variance from accelerometer readings
  double _calculateMotionVariance() {
    if (_motionReadings.length < 10) return 0.0;
    final mean =
        _motionReadings.reduce((a, b) => a + b) / _motionReadings.length;
    return _motionReadings
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        _motionReadings.length;
  }

  /// Reset/cancel current session
  void resetSession() {
    _currentSessionId = null;
    _localRepCount = 0;
    _isInDownPosition = false;
    _framesWithFaceVisible = 0;
    _totalFrames = 0;
    _landmarkBatch.clear();
    _motionReadings.clear();
  }

  /// Dispose pose detector
  void dispose() {
    _poseDetector.close();
  }
}

/// Extension to convert PoseLandmark to Point3D
extension PoseLandmarkExtension on PoseLandmark {
  Point3D toPoint() => Point3D(x: x, y: y, z: z);
}

/// 3D point for angle calculations
class Point3D {
  final double x, y, z;
  Point3D({required this.x, required this.y, this.z = 0});
}

/// Result of processing a single frame
class PushupFrameResult {
  final int localRepCount;
  final double? elbowAngle;
  final bool isFaceVisible;
  final bool isInDownPosition;
  final bool repCompleted;

  PushupFrameResult({
    required this.localRepCount,
    this.elbowAngle,
    required this.isFaceVisible,
    required this.isInDownPosition,
    required this.repCompleted,
  });
}
