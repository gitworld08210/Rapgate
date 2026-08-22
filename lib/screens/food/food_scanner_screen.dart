import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/food_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/scanner_overlay.dart';
import '../../widgets/pill_button.dart';
import 'food_details_screen.dart';

enum ScanMode { food, barcode, label, library }

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key, this.mealType = MealType.lunch});

  final MealType mealType;

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> {
  CameraController? _camera;
  bool _cameraReady = false;
  bool _busy = false;
  bool _flashOn = false;
  ScanMode _mode = ScanMode.food;
  MealType _mealType = MealType.lunch;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available on this device');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_camera == null || !_cameraReady || _busy) return;
    setState(() => _busy = true);

    try {
      final shot = await _camera!.takePicture();
      await _analyze(shot);
    } catch (e) {
      _showError('Capture failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromLibrary() async {
    final foodService = context.read<FoodService>();
    setState(() => _busy = true);
    try {
      final picked = await foodService.pickFromGallery();
      if (picked != null) await _analyze(picked);
    } catch (e) {
      _showError('Could not open library: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze(XFile image) async {
    final foodService = context.read<FoodService>();
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null) return;

    try {
      final base64 = await foodService.imageToBase64(image);

      // Server does the vision inference and returns nutrition estimates
      final result = await foodService.scanFoodImage(
        imageBase64: base64,
        mealType: _mealType,
      );

      // Upload the photo for the user's own record
      String? imageUrl;
      try {
        imageUrl = await foodService.uploadFoodImage(uid, image);
      } catch (_) {
        // Non-fatal: keep the scan even if upload fails
      }

      if (!mounted) return;

      // TODO: Architecture note - The Cloud Function `scanFoodImage` already
      // persists the food log to Firestore server-side (source: "ai_scan").
      // The onConfirm callback here should NOT write another log, as that
      // would create a duplicate entry. It only handles navigation/UI
      // confirmation.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDetailsScreen(
            items: result.detectedItems,
            imageUrl: imageUrl,
            localImagePath: image.path,
            mealType: _mealType,
            onConfirm: (items, meal) async {
              // Server already wrote the food log during scanFoodImage.
              // No client-side write needed for AI scan source.
              // FoodDetailsScreen handles its own Navigator.pop after this.
            },
          ),
        ),
      );
    } catch (e) {
      _showError('Scan failed: $e');
    }
  }

  Future<void> _onBarcode(String code) async {
    final foodService = context.read<FoodService>();
    setState(() => _busy = true);
    try {
      final item = await foodService.searchByBarcode(code);
      if (!mounted) return;
      if (item == null) {
        _showError('Product not found for barcode $code');
        return;
      }
      final auth = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();
      final uid = auth.uid;
      if (uid == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDetailsScreen(
            items: [item],
            mealType: _mealType,
            onConfirm: (items, meal) async {
              await firestore.addFoodLog(
                uid,
                FoodLogModel(
                  id: '',
                  detectedItems: items,
                  mealType: meal,
                  loggedAt: DateTime.now(),
                  source: FoodLogSource.barcode,
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggleFlash() async {
    if (_camera == null) return;
    setState(() => _flashOn = !_flashOn);
    await _camera!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---------- Camera preview / barcode scanner ----------
          if (_mode == ScanMode.barcode)
            MobileScanner(
              onDetect: (capture) {
                if (capture.barcodes.isEmpty || _busy) return;
                final code = capture.barcodes.first.rawValue;
                if (code != null) _onBarcode(code);
              },
            )
          else if (_cameraReady && _camera != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _camera!.value.previewSize?.height ?? 1080,
                height: _camera!.value.previewSize?.width ?? 1920,
                child: CameraPreview(_camera!),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : const CircularProgressIndicator(
                        color: AppColors.limeBright),
              ),
            ),

          // ---------- Dim vignette ----------
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.75),
                  ],
                  stops: const [0.0, 0.22, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ---------- Top bar ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 17,
                    background: Colors.white.withOpacity(0.2),
                    iconColor: Colors.white,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    'Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  CircleIconButton(
                    icon: _flashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    iconSize: 19,
                    background: Colors.white.withOpacity(0.2),
                    iconColor: Colors.white,
                    onTap: _toggleFlash,
                  ),
                ],
              ),
            ),
          ),

          // ---------- Viewfinder ----------
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: ScannerFrame(
                size: MediaQuery.of(context).size.width * 0.74,
                animate: !_busy,
              ),
            ),
          ),

          // ---------- Meal type selector ----------
          Positioned(
            left: 0,
            right: 0,
            bottom: 210,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: MealType.values.map((m) {
                    final selected = m == _mealType;
                    return GestureDetector(
                      onTap: () => setState(() => _mealType = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.limeBright
                              : Colors.transparent,
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          switch (m) {
                            MealType.breakfast => 'Breakfast',
                            MealType.lunch => 'Lunch',
                            MealType.dinner => 'Dinner',
                            MealType.snack => 'Snack',
                          },
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color:
                                selected ? AppColors.ink : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // ---------- Mode chips ----------
          Positioned(
            left: 0,
            right: 0,
            bottom: 132,
            child: ScanModeChips(
              selectedIndex: _mode.index,
              onChanged: (i) {
                final selected = ScanMode.values[i];
                if (selected == ScanMode.library) {
                  _pickFromLibrary();
                } else {
                  setState(() => _mode = selected);
                }
              },
              modes: const [
                (label: 'Scan Food', icon: Icons.restaurant_rounded),
                (label: 'Barcode', icon: Icons.qr_code_scanner_rounded),
                (label: 'Food Label', icon: Icons.receipt_long_rounded),
                (label: 'Library', icon: Icons.photo_library_rounded),
              ],
            ),
          ),

          // ---------- Shutter row ----------
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleIconButton(
                  icon: Icons.photo_library_outlined,
                  size: 46,
                  iconSize: 20,
                  background: Colors.white.withOpacity(0.2),
                  iconColor: Colors.white,
                  onTap: _pickFromLibrary,
                ),
                const SizedBox(width: 34),
                ShutterButton(
                  busy: _busy,
                  onTap: _mode == ScanMode.barcode ? null : _capture,
                ),
                const SizedBox(width: 34),
                CircleIconButton(
                  icon: Icons.edit_note_rounded,
                  size: 46,
                  iconSize: 21,
                  background: Colors.white.withOpacity(0.2),
                  iconColor: Colors.white,
                  onTap: () {
                    Navigator.pop(context);
                    // Manual entry lives on the food log screen
                  },
                ),
              ],
            ),
          ),

          // ---------- Analyzing overlay ----------
          if (_busy)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.limeBright, size: 30),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Analyzing your food…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'AI is estimating nutrition values',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
