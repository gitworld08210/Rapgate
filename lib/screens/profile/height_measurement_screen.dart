import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../services/height_measurement_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/height_calculator.dart';
import '../../widgets/height_guide_overlay.dart';
import '../../widgets/pose_overlay_painter.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';

/// A premium guided height measurement screen using camera-based pose detection.
///
/// Multi-step flow:
/// 1. Instructions with animated guide + distance calibration
/// 2. Camera preview with real-time pose overlay and feedback
/// 3. Processing/analysis with premium animation
/// 4. Result display with glassmorphism card and save button
///
/// Includes manual entry fallback.
class HeightMeasurementScreen extends StatefulWidget {
  const HeightMeasurementScreen({super.key});

  @override
  State<HeightMeasurementScreen> createState() =>
      _HeightMeasurementScreenState();
}

class _HeightMeasurementScreenState extends State<HeightMeasurementScreen>
    with TickerProviderStateMixin {
  // Step management
  int _currentStep = 0; // 0: instructions, 1: camera, 2: processing, 3: result
  final PageController _pageController = PageController();

  // Camera
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;

  // Measurement service
  final HeightMeasurementService _measurementService =
      HeightMeasurementService();
  HeightMeasurementFrame? _lastFrame;
  double? _finalHeight;

  // Manual entry
  final TextEditingController _manualHeightController = TextEditingController();

  // Distance calibration (user-adjustable, default 300cm)
  double _calibrationDistanceCm = 300.0;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _processingController;
  late AnimationController _resultController;
  late AnimationController _confettiController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _processingAnimation;
  late Animation<double> _resultAnimation;

  // Confetti particles
  final List<_ConfettiParticle> _confettiParticles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _processingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _processingController, curve: Curves.linear),
    );

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _resultAnimation = CurvedAnimation(
      parent: _resultController,
      curve: Curves.elasticOut,
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Prefer back camera for height measurement (better distance)
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      // Start image stream for pose detection
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _currentStep != 1) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final frame = await _measurementService.processFrame(
        inputImage,
        cameraDistanceCm: _calibrationDistanceCm,
      );
      if (!mounted) {
        _isDetecting = false;
        return;
      }

      setState(() => _lastFrame = frame);

      // Check if we have a consistent measurement
      if (_measurementService.hasConsistentMeasurement) {
        HapticFeedback.heavyImpact();
        _onMeasurementComplete();
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }

    _isDetecting = false;
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

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

  void _onMeasurementComplete() async {
    // Stop camera stream
    await _cameraController?.stopImageStream();

    // Move to processing step
    _goToStep(2);

    // Simulate processing time for premium feel
    await Future.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    final height = _measurementService.finalMeasurement;
    setState(() {
      _finalHeight = height != null ? double.parse(height.toStringAsFixed(1)) : null;
    });

    // Move to result step
    _goToStep(3);
    _resultController.forward();
    _startConfetti();
    HapticFeedback.mediumImpact();
  }

  void _startConfetti() {
    _confettiParticles.clear();
    for (int i = 0; i < 50; i++) {
      _confettiParticles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.3,
        speedX: (_random.nextDouble() - 0.5) * 0.02,
        speedY: 0.005 + _random.nextDouble() * 0.01,
        rotation: _random.nextDouble() * 360,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        color: [
          AppColors.limeBright,
          AppColors.lime,
          AppColors.limeDeep,
          AppColors.green,
          AppColors.white,
        ][_random.nextInt(5)],
        size: 4 + _random.nextDouble() * 6,
      ));
    }
    _confettiController.forward();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _retryMeasurement() {
    _measurementService.reset();
    setState(() {
      _lastFrame = null;
      _finalHeight = null;
    });
    _resultController.reset();
    _confettiController.reset();
    _goToStep(1);
    _cameraController?.startImageStream(_processCameraImage);
  }

  void _saveHeight() {
    final height = _finalHeight;
    if (height != null) {
      Navigator.pop(context, height);
    }
  }

  void _saveManualHeight() {
    final height = double.tryParse(_manualHeightController.text);
    if (height != null && height > 50 && height < 250) {
      Navigator.pop(context, height);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _measurementService.dispose();
    _pulseController.dispose();
    _processingController.dispose();
    _resultController.dispose();
    _confettiController.dispose();
    _pageController.dispose();
    _manualHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Step indicator
            _buildStepIndicator(context),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildInstructionsStep(context),
                  _buildCameraStep(context),
                  _buildProcessingStep(context),
                  _buildResultStep(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCard
                  : AppColors.grey100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Height Measurement',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Manual entry shortcut
          if (_currentStep == 0)
            TextButton.icon(
              onPressed: () => _showManualEntrySheet(context),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Manual'),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive
                    ? AppColors.limeBright
                    : (isDark ? AppColors.darkBorder : AppColors.grey200),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.limeBright.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Step 1: Instructions ───────────────────────────────────────────

  Widget _buildInstructionsStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Animated illustration
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppColors.darkCard,
                            AppColors.darkSurface,
                          ]
                        : [
                            AppColors.limeSoft,
                            AppColors.limeWash,
                          ],
                  ),
                  border: Border.all(
                    color: AppColors.limeBright
                        .withOpacity(0.3 + 0.2 * _pulseAnimation.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.limeBright
                          .withOpacity(0.1 + 0.1 * _pulseAnimation.value),
                      blurRadius: 20 + 10 * _pulseAnimation.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Person silhouette
                    Icon(
                      Icons.accessibility_new_rounded,
                      size: 120,
                      color: AppColors.limeBright
                          .withOpacity(0.4 + 0.2 * _pulseAnimation.value),
                    ),
                    // Measurement arrows
                    Positioned(
                      left: 30,
                      top: 40,
                      bottom: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.arrow_upward_rounded,
                              size: 18, color: AppColors.limeBright),
                          Container(
                            width: 2,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.limeBright,
                                  AppColors.limeBright.withOpacity(0.3),
                                  AppColors.limeBright,
                                ],
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_downward_rounded,
                              size: 18, color: AppColors.limeBright),
                        ],
                      ),
                    ),
                    // Distance indicator
                    Positioned(
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          '2-3m away',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          Text(
            'How it works',
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 24),

          // Instructions list
          _instructionItem(
            context,
            '1',
            'Position yourself',
            'Stand 2-3 meters from the camera with your full body visible',
            Icons.straighten_rounded,
          ),
          const SizedBox(height: 16),
          _instructionItem(
            context,
            '2',
            'Stand straight',
            'Keep your arms relaxed at your sides, look straight ahead',
            Icons.accessibility_new_rounded,
          ),
          const SizedBox(height: 16),
          _instructionItem(
            context,
            '3',
            'Hold still',
            'We will take multiple readings for accuracy',
            Icons.timer_rounded,
          ),

          const SizedBox(height: 32),

          // Tips
          SoftCard(
            color: isDark ? AppColors.darkCard : AppColors.limeWash,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.limeBright.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.limeBright,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For best results, wear flat shoes and stand against a plain background.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Distance calibration step
          SoftCard(
            color: isDark ? AppColors.darkCard : AppColors.grey100,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.straighten_rounded,
                      size: 18,
                      color: AppColors.limeBright,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Distance from Camera',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Adjust the slider to match your actual distance from the phone camera. Accuracy depends on this value.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '1.5m',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.grey500,
                          ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _calibrationDistanceCm,
                        min: 150.0,
                        max: 500.0,
                        divisions: 14,
                        activeColor: AppColors.limeBright,
                        inactiveColor: isDark
                            ? AppColors.darkBorder
                            : AppColors.grey200,
                        label: '${(_calibrationDistanceCm / 100).toStringAsFixed(1)}m',
                        onChanged: (value) {
                          setState(() => _calibrationDistanceCm = value);
                        },
                      ),
                    ),
                    Text(
                      '5m',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.grey500,
                          ),
                    ),
                  ],
                ),
                Center(
                  child: Text(
                    '${(_calibrationDistanceCm / 100).toStringAsFixed(1)} meters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.limeBright,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.warning.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This tool provides an estimate only and is not a clinical measurement. Results may vary depending on camera position, lighting, and distance accuracy.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey500,
                          fontSize: 11,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Start button
          PillButton(
            label: 'Start Measurement',
            icon: Icons.camera_alt_rounded,
            variant: PillVariant.lime,
            onPressed: () {
              HapticFeedback.mediumImpact();
              _initCamera();
              _goToStep(1);
            },
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => _showManualEntrySheet(context),
            child: Text(
              'Or enter height manually',
              style: TextStyle(
                color: AppColors.grey500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionItem(BuildContext context, String number, String title,
      String subtitle, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.limeBright.withOpacity(0.15)
                : AppColors.limeSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.limeBright),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Camera ─────────────────────────────────────────────────

  Widget _buildCameraStep(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.limeBright),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: CameraPreview(_cameraController!),
        ),

        // Pose overlay
        if (_lastFrame?.landmarks != null)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return CustomPaint(
                painter: PoseOverlayPainter(
                  landmarks: _lastFrame!.landmarks,
                  feedback: _lastFrame!.feedback,
                  animationValue: _pulseAnimation.value,
                  imageSize: Size(
                    _cameraController!.value.previewSize?.width ?? 720,
                    _cameraController!.value.previewSize?.height ?? 1280,
                  ),
                  isFrontCamera: _cameraController!.description.lensDirection ==
                      CameraLensDirection.front,
                ),
              );
            },
          ),

        // Guide overlay
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            return HeightGuideOverlay(
              feedback:
                  _lastFrame?.feedback ?? HeightMeasurementFeedback.noPersonDetected,
              animationValue: _pulseAnimation.value,
              showSilhouette: _lastFrame?.landmarks == null,
            );
          },
        ),

        // Quality indicator
        if (_lastFrame != null && _lastFrame!.feedback.isReady)
          Positioned(
            top: 16,
            right: 16,
            child: _buildQualityBadge(context),
          ),
      ],
    );
  }

  Widget _buildQualityBadge(BuildContext context) {
    final quality = _lastFrame?.qualityScore ?? 0.0;
    final readingCount = _measurementService.hasConsistentMeasurement
        ? HeightMeasurementService.requiredConsistentReadings
        : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.limeBright.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_cellular_alt_rounded,
            size: 14,
            color: quality > 0.7
                ? AppColors.success
                : quality > 0.4
                    ? AppColors.warning
                    : AppColors.danger,
          ),
          const SizedBox(width: 6),
          Text(
            '${(quality * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Processing ─────────────────────────────────────────────

  Widget _buildProcessingStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium processing animation
          AnimatedBuilder(
            animation: _processingAnimation,
            builder: (context, _) {
              return SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
                    Transform.rotate(
                      angle: _processingAnimation.value * 2 * pi,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.limeBright.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.limeBright,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.limeBright.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inner rotating ring (opposite direction)
                    Transform.rotate(
                      angle: -_processingAnimation.value * 2 * pi * 1.5,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.lime.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Center icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.limeSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.straighten_rounded,
                        color: AppColors.limeBright,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          Text(
            'Analyzing your measurements...',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          Text(
            'Processing pose data for accuracy',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ─── Step 4: Result ─────────────────────────────────────────────────

  Widget _buildResultStep(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_finalHeight == null) {
      return _buildMeasurementFailed(context);
    }

    return Stack(
      children: [
        // Confetti
        if (_confettiParticles.isNotEmpty)
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  particles: _confettiParticles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),

        // Content
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Success icon
              ScaleTransition(
                scale: _resultAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.limeBright,
                        AppColors.limeDeep,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.limeGlow,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.ink,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Measurement Complete!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),

              const SizedBox(height: 32),

              // Glassmorphism result card
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                AppColors.darkCard.withOpacity(0.8),
                                AppColors.darkSurface.withOpacity(0.6),
                              ]
                            : [
                                Colors.white.withOpacity(0.85),
                                Colors.white.withOpacity(0.65),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.limeBright.withOpacity(0.2)
                            : Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.limeBright.withOpacity(0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Height',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ScaleTransition(
                              scale: _resultAnimation,
                              child: Text(
                                _finalHeight!.toStringAsFixed(1),
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                      color: AppColors.limeBright,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'cm',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppColors.grey500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Feet/inches conversion
                        Text(
                          _cmToFeetInches(_finalHeight!),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.grey500,
                              ),
                        ),
                        const SizedBox(height: 20),
                        // Accuracy disclaimer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkBorder.withOpacity(0.5)
                                : AppColors.grey100,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppColors.grey500,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Estimate only - not a clinical measurement',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.grey500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Save button
              PillButton(
                label: 'Save Height',
                icon: Icons.check_rounded,
                variant: PillVariant.lime,
                onPressed: _saveHeight,
              ),

              const SizedBox(height: 12),

              // Retry button
              PillButton(
                label: 'Measure Again',
                icon: Icons.refresh_rounded,
                variant: PillVariant.outline,
                onPressed: _retryMeasurement,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => _showManualEntrySheet(context),
                child: Text(
                  'Enter manually instead',
                  style: TextStyle(
                    color: AppColors.grey500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementFailed(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.warning,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Could not determine height',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'The measurement was not accurate enough. Try again with better lighting and positioning.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PillButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            variant: PillVariant.lime,
            onPressed: _retryMeasurement,
          ),
          const SizedBox(height: 12),
          PillButton(
            label: 'Enter Manually',
            icon: Icons.edit_rounded,
            variant: PillVariant.outline,
            onPressed: () => _showManualEntrySheet(context),
          ),
        ],
      ),
    );
  }

  void _showManualEntrySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          top: 20,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.straighten_rounded,
              size: 32,
              color: AppColors.limeBright,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter Your Height',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _manualHeightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Height',
                prefixIcon: Icon(Icons.height),
                suffixText: 'cm',
                hintText: 'e.g., 175.5',
              ),
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Save',
              icon: Icons.check_rounded,
              variant: PillVariant.lime,
              onPressed: () {
                Navigator.pop(sheetContext);
                _saveManualHeight();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _cmToFeetInches(double cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    return "$feet' $inches\"";
  }
}

// ─── Confetti ─────────────────────────────────────────────────────────────

class _ConfettiParticle {
  double x;
  double y;
  double speedX;
  double speedY;
  double rotation;
  double rotationSpeed;
  Color color;
  double size;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.size,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = (particle.x + particle.speedX * progress * 60) * size.width;
      final y =
          (particle.y + particle.speedY * progress * 60) * size.height;
      final rotation = particle.rotation + particle.rotationSpeed * progress;

      if (y > size.height || y < 0) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - progress * 0.8)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation * pi / 180);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.6,
          ),
          Radius.circular(1),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
