import 'dart:math';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';
import '../utils/constants.dart';

/// Handles push-up detection logic (on-device) and server verification via
/// Supabase Edge Functions.
class PushupService {
  final SupabaseClient _db = supabase;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  String? _currentSessionId;
  int _localRepCount = 0;
  bool _isInDownPosition = false;
  int _framesWithFaceVisible = 0;
  int _totalFrames = 0;
  final List<Map<String, dynamic>> _landmarkBatch = [];
  final List<double> _motionReadings = [];

  String? get currentSessionId => _currentSessionId;
  int get localRepCount => _localRepCount;
  double get faceVisibilityRatio =>
      _totalFrames > 0 ? _framesWithFaceVisible / _totalFrames : 0.0;

  PoseDetector get poseDetector => _poseDetector;

  /// Start a new push-up session (calls the `start-pushup-session` function)
  Future<({String sessionId, int requiredReps})> startSession() async {
    try {
      final response = await _db.functions.invoke('start-pushup-session');
      if (response.status >= 400) {
        throw Exception((response.data as Map?)?['error'] ?? 'Failed to start session');
      }

      final data = response.data as Map<String, dynamic>;
      _currentSessionId = data['sessionId'] as String;
      final requiredReps = data['requiredReps'] as int;

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
  PushupFrameResult processFrame(Pose pose) {
    _totalFrames++;

    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
    final isFaceVisible = nose != null && leftEye != null && rightEye != null;
    if (isFaceVisible) _framesWithFaceVisible++;

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

    double? avgElbowAngle;
    if (leftElbowAngle != null && rightElbowAngle != null) {
      avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;
    } else {
      avgElbowAngle = leftElbowAngle ?? rightElbowAngle;
    }

    bool repCompleted = false;
    if (avgElbowAngle != null) {
      // No tolerance margin here on purpose. The previous +/-20 fudge meant the
      // preview counted reps the server would later reject, so the user saw
      // progress that never materialised into a verified session.
      if (!_isInDownPosition &&
          avgElbowAngle <= AppConstants.minElbowAngleFlexed) {
        _isInDownPosition = true;
      } else if (_isInDownPosition &&
          avgElbowAngle >= AppConstants.maxElbowAngleExtended) {
        _isInDownPosition = false;
        _localRepCount++;
        repCompleted = true;
      }
    }

    // Only the three fields the server actually reads are sent.
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

  static const int _maxMotionReadings = 600;

  void addMotionReading(double magnitude) {
    _motionReadings.add(magnitude);
    if (_motionReadings.length > _maxMotionReadings) {
      _motionReadings.removeAt(0);
    }
  }

  /// Submit batch to the `submit-pushup-frame-batch` function for verification.
  Future<({int validatedReps, bool sessionComplete})> submitBatch() async {
    if (_currentSessionId == null) {
      throw Exception('No active session');
    }

    try {
      final response = await _db.functions.invoke(
        'submit-pushup-frame-batch',
        body: {
          'sessionId': _currentSessionId,
          'poseLandmarkBatch': _landmarkBatch,
          'frameMeta': {
            'faceVisible':
                faceVisibilityRatio >= AppConstants.faceVisibilityThreshold,
            'cameraFacing': 'front',
            'motionVariance': _calculateMotionVariance(),
            'totalFrames': _totalFrames,
            'framesWithFace': _framesWithFaceVisible,
          },
        },
      );

      if (response.status >= 400) {
        throw Exception((response.data as Map?)?['error'] ?? 'Batch rejected');
      }

      final data = response.data as Map<String, dynamic>;
      final validatedReps = data['currentValidatedReps'] as int;
      final sessionComplete = data['sessionComplete'] as bool;

      _landmarkBatch.clear();

      return (validatedReps: validatedReps, sessionComplete: sessionComplete);
    } catch (e) {
      throw Exception('Failed to submit push-up batch: $e');
    }
  }

  double _calculateAngle(Point3D a, Point3D b, Point3D c) {
    final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
    var angle = radians * 180 / pi;
    if (angle < 0) angle += 360;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  double _calculateMotionVariance() {
    if (_motionReadings.length < 10) return 0.0;
    final mean =
        _motionReadings.reduce((a, b) => a + b) / _motionReadings.length;
    return _motionReadings
            .map((x) => pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        _motionReadings.length;
  }

  void resetSession() {
    _currentSessionId = null;
    _localRepCount = 0;
    _isInDownPosition = false;
    _framesWithFaceVisible = 0;
    _totalFrames = 0;
    _landmarkBatch.clear();
    _motionReadings.clear();
  }

  void dispose() {
    _poseDetector.close();
  }
}

extension PoseLandmarkExtension on PoseLandmark {
  Point3D toPoint() => Point3D(x: x, y: y, z: z);
}

class Point3D {
  final double x, y, z;
  Point3D({required this.x, required this.y, this.z = 0});
}

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
