import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../services/pushup_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/pill_button.dart';

/// Live push-up session: front camera + on-device ML Kit pose detection,
/// with periodic server-side verification batches.
class PushupSessionScreen extends StatefulWidget {
  const PushupSessionScreen({super.key});

  @override
  State<PushupSessionScreen> createState() => _PushupSessionScreenState();
}

class _PushupSessionScreenState extends State<PushupSessionScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  StreamSubscription<AccelerometerEvent>? _accel;

  bool _initializing = true;
  bool _sessionStarted = false;
  bool _detecting = false;
  bool _finishing = false;
  String? _error;

  int _requiredReps = AppConstants.defaultPushupTarget;
  int _reps = 0;
  int _serverReps = 0;
  double? _elbowAngle;
  bool _faceVisible = false;
  bool _isDown = false;

  Timer? _batchTimer;
  int _countdown = 3;
  Timer? _countdownTimer;

  /// Pose inference is capped at ~15 fps rather than running on every camera
  /// frame (~30 fps). ML Kit inference is the dominant CPU and battery cost in
  /// a session, and 15 fps is ample resolution for rep counting: the minimum
  /// accepted rep takes 800 ms, which is still ~12 samples.
  static const int _minInferenceIntervalMs = 66;
  int _lastInferenceMs = 0;

  PushupService get _service => context.read<PushupService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batchTimer?.cancel();
    _countdownTimer?.cancel();
    _accel?.cancel();
    _camera?.stopImageStream().catchError((_) {});
    _camera?.dispose();
    _service.resetSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-session invalidates it (anti-cheat).
    if (state == AppLifecycleState.paused && _sessionStarted && !_finishing) {
      _abort('Session cancelled — you left the app');
    }
  }

  Future<void> _bootstrap() async {
    try {
      // 1) Ask the server for a session + adaptive target
      final session = await _service.startSession();
      _requiredReps = session.requiredReps;

      // 2) Open the FRONT camera (mandatory)
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => throw Exception(
            'Front camera required for verification but none was found'),
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _camera = controller;
        _initializing = false;
      });

      _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initializing = false;
        });
      }
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        _beginDetection();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _beginDetection() async {
    setState(() {
      _sessionStarted = true;
      _countdown = 0;
    });

    // Motion variance sampling (rejects a propped-up phone + video loop)
    _accel = accelerometerEventStream().listen((e) {
      final magnitude =
          math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      _service.addMotionReading(magnitude);
    });

    // Periodic server verification
    _batchTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _submitBatch();
    });

    await _camera?.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_detecting || !_sessionStarted || _finishing) return;

    // Drop frames that arrive faster than the inference cap.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastInferenceMs < _minInferenceIntervalMs) return;
    _lastInferenceMs = nowMs;

    _detecting = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final poses = await _service.poseDetector.processImage(inputImage);
      if (poses.isEmpty) return;

      final result = _service.processFrame(poses.first);

      if (mounted) {
        setState(() {
          _reps = result.localRepCount;
          _elbowAngle = result.elbowAngle;
          _faceVisible = result.isFaceVisible;
          _isDown = result.isInDownPosition;
        });
      }

      // Enough local reps — get the final server ruling
      if (_reps >= _requiredReps && !_finishing) {
        _finish();
      }
    } catch (_) {
      // Dropped frames are expected; keep the stream alive.
    } finally {
      _detecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
      camera.description.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _submitBatch() async {
    if (!_sessionStarted || _finishing) return;
    try {
      final result = await _service.submitBatch();
      if (mounted) setState(() => _serverReps = result.validatedReps);
    } catch (_) {
      // Transient failures are fine — the batch is retried on the next tick.
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    _batchTimer?.cancel();

    try {
      await _camera?.stopImageStream();
    } catch (_) {}

    try {
      final result = await _service.submitBatch();
      if (!mounted) return;

      if (result.sessionComplete) {
        _showResult(success: true, reps: result.validatedReps);
      } else {
        setState(() {
          _serverReps = result.validatedReps;
          _finishing = false;
        });
        // Server wants more verified reps — resume detection.
        await _camera?.startImageStream(_onFrame);
        _batchTimer = Timer.periodic(
            const Duration(seconds: 10), (_) => _submitBatch());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Server verified ${result.validatedReps}/$_requiredReps — keep going with full range of motion',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _finishing = false);
        _showResult(success: false, reps: _serverReps, error: e.toString());
      }
    }
  }

  void _abort(String reason) {
    _batchTimer?.cancel();
    _service.resetSession();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  void _showResult({
    required bool success,
    required int reps,
    String? error,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: success ? AppColors.limeSoft : AppColors.pastelPink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.lock_open_rounded : Icons.error_outline_rounded,
                size: 34,
                color: success ? AppColors.limeDeep : AppColors.danger,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              success ? 'Verified! 🎉' : 'Not verified',
              style: Theme.of(sheetContext).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              success
                  ? '$reps push-ups confirmed. Your apps are unlocked for the next 24 hours.'
                  : error ??
                      'The server could not verify the full range of motion. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 26),
            PillButton(
              label: success ? 'Done' : 'Try again',
              variant: success ? PillVariant.lime : PillVariant.dark,
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Note: the rep target comes from `_requiredReps`, which the *server*
    // returned when the session started — never from the local user profile.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---------- Camera ----------
          if (_camera != null && !_initializing)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _camera!.value.previewSize?.height ?? 720,
                height: _camera!.value.previewSize?.width ?? 1280,
                child: CameraPreview(_camera!),
              ),
            )
          else
            const ColoredBox(color: Colors.black),

          // ---------- Scrim ----------
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ---------- Error state ----------
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_rounded,
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 18),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    PillButton(
                      label: 'Go back',
                      variant: PillVariant.lime,
                      expand: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

          // ---------- Loading ----------
          if (_initializing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.limeBright),
                  SizedBox(height: 18),
                  Text('Preparing session…',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

          // ---------- Countdown ----------
          if (_countdown > 0 && !_initializing && _error == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 110,
                      fontWeight: FontWeight.w800,
                      color: AppColors.limeBright,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Get into push-up position',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // ---------- Top bar ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    iconSize: 20,
                    background: Colors.white.withOpacity(0.2),
                    iconColor: Colors.white,
                    onTap: () => _confirmExit(),
                  ),
                  const Spacer(),
                  // Face-visibility indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_faceVisible
                              ? AppColors.limeBright
                              : AppColors.danger)
                          .withOpacity(0.9),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _faceVisible
                              ? Icons.face_rounded
                              : Icons.face_retouching_off_rounded,
                          size: 15,
                          color: _faceVisible
                              ? AppColors.ink
                              : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _faceVisible ? 'Face OK' : 'Show your face',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _faceVisible
                                ? AppColors.ink
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------- Rep counter ----------
          if (_sessionStarted)
            Positioned(
              left: 0,
              right: 0,
              bottom: 150,
              child: Column(
                children: [
                  // Down/up state pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Text(
                      _isDown ? 'PUSH UP ⬆️' : 'GO DOWN ⬇️',
                      style: const TextStyle(
                        color: AppColors.limeBright,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_reps',
                        style: const TextStyle(
                          fontSize: 88,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      Text(
                        ' / $_requiredReps',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _serverReps > 0
                        ? 'Server verified: $_serverReps'
                        : 'Awaiting server verification…',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_elbowAngle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Elbow ${_elbowAngle!.toStringAsFixed(0)}°',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // ---------- Progress bar ----------
          if (_sessionStarted)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(color: Colors.white.withOpacity(0.2)),
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 300),
                        widthFactor:
                            (_reps / _requiredReps).clamp(0.0, 1.0),
                        child: Container(color: AppColors.limeBright),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ---------- Finish early ----------
          if (_sessionStarted && !_finishing)
            Positioned(
              left: 24,
              right: 24,
              bottom: 34,
              child: PillButton(
                label: 'Submit for verification',
                variant: PillVariant.lime,
                onPressed: _reps > 0 ? _finish : null,
              ),
            ),

          // ---------- Verifying overlay ----------
          if (_finishing)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.limeBright),
                    SizedBox(height: 20),
                    Text(
                      'Verifying with server…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Recounting reps independently',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Cancel session?'),
        content: const Text(
            'Your progress in this session will be discarded and apps stay locked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _service.resetSession();
              Navigator.pop(context);
            },
            child: const Text('Cancel session',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
