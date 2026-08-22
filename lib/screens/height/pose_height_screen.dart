import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';

import '../../models/height_measurement_model.dart';
import '../../services/height_measurement_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import 'height_result_screen.dart';

/// Camera-based height measurement screen.
/// Uses ML Kit pose detection with a reference object for calibration.
///
/// When [returnResult] is true, the screen pops a [HeightMeasurement] back
/// to the caller instead of navigating to [HeightResultScreen]. This is used
/// by accuracy mode to collect individual measurements.
class PoseHeightScreen extends StatefulWidget {
  const PoseHeightScreen({super.key, this.returnResult = false});

  /// If true, pops a [HeightMeasurement] result via Navigator.pop
  /// instead of pushing to the results screen.
  final bool returnResult;

  @override
  State<PoseHeightScreen> createState() => _PoseHeightScreenState();
}

class _PoseHeightScreenState extends State<PoseHeightScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _initializing = true;
  bool _detecting = false;
  bool _measuring = false;
  String? _error;

  ReferenceObject _selectedReference = ReferenceObject.a4Paper;
  double _referencePixelHeight = 0;
  bool _referenceCalibrated = false;
  bool _showCalibrationGuide = true;

  double? _lastMeasuredHeight;
  bool _poseValid = false;
  final List<double> _heightReadings = [];

  static const int _minInferenceIntervalMs = 100;
  int _lastInferenceMs = 0;

  /// Tracks consecutive frame processing errors for user feedback.
  int _consecutiveErrors = 0;
  static const int _errorThreshold = 10;
  bool _hasProcessingError = false;

  HeightMeasurementService get _service =>
      context.read<HeightMeasurementService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.stopImageStream().catchError((_) {});
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _camera?.stopImageStream().catchError((_) {});
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _camera = controller;
        _initializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initializing = false;
        });
      }
    }
  }

  Future<void> _startMeasuring() async {
    if (_camera == null) return;

    setState(() {
      _measuring = true;
      _showCalibrationGuide = false;
      _heightReadings.clear();
    });

    await _camera!.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_detecting || !_measuring) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastInferenceMs < _minInferenceIntervalMs) return;
    _lastInferenceMs = nowMs;

    _detecting = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final poses = await _service.poseDetector.processImage(inputImage);
      if (poses.isEmpty) {
        if (mounted) setState(() => _poseValid = false);
        return;
      }

      final pose = poses.first;
      final isValid = _service.isPoseValidForHeight(pose);

      if (mounted) setState(() => _poseValid = isValid);

      if (isValid && _referenceCalibrated) {
        final height = _service.calculateHeightFromPose(
          pose: pose,
          referenceObjectPixelHeight: _referencePixelHeight,
          referenceObject: _selectedReference,
        );

        if (height != null && mounted) {
          setState(() {
            _lastMeasuredHeight = height;
            _consecutiveErrors = 0;
            _hasProcessingError = false;
          });
          _heightReadings.add(height);
        }
      }
    } catch (_) {
      _consecutiveErrors++;
      if (_consecutiveErrors >= _errorThreshold && mounted) {
        setState(() => _hasProcessingError = true);
      }
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

  void _confirmMeasurement() {
    if (_heightReadings.isEmpty && _lastMeasuredHeight == null) return;

    // Use the median of collected readings for best accuracy
    double finalHeight;
    if (_heightReadings.length >= 3) {
      final sorted = List<double>.from(_heightReadings)..sort();
      final mid = sorted.length ~/ 2;
      finalHeight = sorted[mid];
    } else {
      finalHeight = _lastMeasuredHeight ?? _heightReadings.last;
    }

    _camera?.stopImageStream().catchError((_) {});

    final measurement = HeightMeasurement(
      method: 'pose_reference',
      valueCm: finalHeight,
      referenceObjectType: _selectedReference.type,
    );

    // In returnResult mode, pop the measurement back to the caller
    // (used by accuracy mode to collect individual measurements).
    if (widget.returnResult) {
      Navigator.pop(context, measurement);
      return;
    }

    final result =
        HeightMeasurementResult.fromMeasurements([measurement]);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HeightResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
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

          // Scrim gradient
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Error state
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

          // Loading state
          if (_initializing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.limeBright),
                  SizedBox(height: 18),
                  Text('Opening camera...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    iconSize: 20,
                    background: Colors.white.withOpacity(0.2),
                    iconColor: Colors.white,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Pose status indicator
                  if (_measuring)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_poseValid
                                ? AppColors.limeBright
                                : AppColors.danger)
                            .withOpacity(0.9),
                        borderRadius: AppRadius.chip,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _poseValid
                                ? Icons.accessibility_new_rounded
                                : Icons.person_off_rounded,
                            size: 15,
                            color:
                                _poseValid ? AppColors.ink : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _poseValid ? 'Full body OK' : 'Show full body',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  _poseValid ? AppColors.ink : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Calibration guide overlay
          if (_showCalibrationGuide && !_initializing && _error == null)
            _buildCalibrationGuide(),

          // Processing error banner (shown after repeated frame failures)
          if (_measuring && _hasProcessingError)
            Positioned(
              left: 24,
              right: 24,
              top: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.9),
                  borderRadius: AppRadius.chip,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Detection issues detected. Try better lighting or reposition.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Measurement display
          if (_measuring && _lastMeasuredHeight != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Text(
                      '${_lastMeasuredHeight!.toStringAsFixed(1)} cm',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: AppColors.limeBright,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_heightReadings.length} readings collected',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom action area
          if (!_initializing && _error == null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_measuring && _lastMeasuredHeight != null)
                    PillButton(
                      label: 'Confirm Measurement',
                      variant: PillVariant.lime,
                      icon: Icons.check_rounded,
                      onPressed: _confirmMeasurement,
                    )
                  else if (!_measuring && _referenceCalibrated)
                    PillButton(
                      label: 'Start Measuring',
                      variant: PillVariant.lime,
                      icon: Icons.straighten_rounded,
                      onPressed: _startMeasuring,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalibrationGuide() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.straighten_rounded,
              color: AppColors.limeBright,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Setup Instructions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Place your phone on a surface or ask someone to hold it\n'
              '2. Place the reference object (A4 paper or credit card) at your feet on the ground\n'
              '3. Stand straight with your full body visible in the camera\n'
              '4. The reference object should be clearly visible near your feet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),

            // Reference object selector
            Row(
              children: [
                Expanded(
                  child: _ReferenceChip(
                    label: 'A4 Paper',
                    subtitle: '29.7 cm',
                    selected: _selectedReference == ReferenceObject.a4Paper,
                    onTap: () => setState(
                        () => _selectedReference = ReferenceObject.a4Paper),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ReferenceChip(
                    label: 'Credit Card',
                    subtitle: '8.56 cm',
                    selected:
                        _selectedReference == ReferenceObject.creditCard,
                    onTap: () => setState(
                        () => _selectedReference = ReferenceObject.creditCard),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reference object pixel height input
            const Text(
              'Estimated reference height in frame (pixels):',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _referencePixelHeight.clamp(20, 500),
                    min: 20,
                    max: 500,
                    activeColor: AppColors.limeBright,
                    inactiveColor: AppColors.grey700,
                    onChanged: (val) {
                      setState(() {
                        _referencePixelHeight = val;
                        _referenceCalibrated = val > 30;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_referencePixelHeight.toInt()} px',
                    style: const TextStyle(
                      color: AppColors.limeBright,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            PillButton(
              label: 'Ready - Start Measuring',
              variant: PillVariant.lime,
              onPressed: _referenceCalibrated
                  ? () {
                      setState(() => _showCalibrationGuide = false);
                      _startMeasuring();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.limeBright.withOpacity(0.15)
              : AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.limeBright : AppColors.darkBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.limeBright : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? AppColors.limeBright.withOpacity(0.7)
                    : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
