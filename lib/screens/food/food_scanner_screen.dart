import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/food_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/dataset_service.dart';
import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/scanner_overlay.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/scan_progress_overlay.dart';
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
  MobileScannerController? _barcodeController;
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
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || _mode == ScanMode.barcode) {
        await controller.dispose();
        return;
      }
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
    // MobileScanner owns and disposes its controller when its widget leaves
    // the tree, so disposing it here as well would double-close its streams.
    super.dispose();
  }

  Future<void> _changeMode(ScanMode selected) async {
    if (selected == ScanMode.library) {
      await _pickFromLibrary();
      return;
    }
    if (selected == _mode || _busy) return;

    if (selected == ScanMode.barcode) {
      final camera = _camera;
      setState(() {
        _camera = null;
        _cameraReady = false;
        _flashOn = false;
      });
      await camera?.dispose();
      if (!mounted) return;

      final scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        detectionTimeoutMs: 500,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.itf,
          BarcodeFormat.code128,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.qrCode,
        ],
      );
      setState(() {
        _barcodeController = scanner;
        _mode = ScanMode.barcode;
      });
      return;
    }

    if (_mode == ScanMode.barcode) {
      try {
        await _barcodeController?.stop();
      } catch (_) {
        // The widget may already have stopped it during a lifecycle change.
      }
      if (!mounted) return;
      setState(() {
        _mode = selected;
        _barcodeController = null;
        _flashOn = false;
      });
      await _initCamera();
      return;
    }

    setState(() => _mode = selected);
  }

  Future<void> _capture() async {
    if (_camera == null || !_cameraReady || _busy) return;

    try {
      final shot = await _camera!.takePicture();
      await _analyze(shot);
    } catch (e) {
      _showError('Capture failed: $e');
    }
  }

  Future<void> _pickFromLibrary() async {
    final foodService = context.read<FoodService>();
    try {
      final picked = await foodService.pickFromGallery();
      if (picked != null) await _analyze(picked);
    } catch (e) {
      _showError('Could not open library: $e');
    }
  }

  Future<void> _analyze(XFile image) async {
    final foodService = context.read<FoodService>();
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() => _busy = true);

    try {
      final base64 = await foodService.imageToBase64(image);

      // Server does the vision inference and returns nutrition estimates
      final result = await foodService.scanFoodImage(
        imageBase64: base64,
        mealType: _mealType,
        scanKind: _mode == ScanMode.label ? 'nutrition_label' : 'food',
      );

      if (result.detectedItems.isEmpty) {
        _showError(
          _mode == ScanMode.label
              ? 'Label not readable. Keep it flat, well lit, and fill the frame.'
              : 'No food recognized. Try again in better light and keep the food inside the frame.',
        );
        return;
      }

      // Upload the photo for the user's own record
      String? imageUrl;
      try {
        imageUrl = await foodService.uploadFoodImage(uid, image);
      } catch (_) {
        // Non-fatal: keep the scan even if upload fails
      }

      // Fire-and-forget: upload to Cloudinary for future model training
      DatasetService.uploadForTraining(
        imageFile: image,
        userId: uid,
        mealType: _mealType,
        detectedItems: result.detectedItems,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDetailsScreen(
            items: result.detectedItems,
            imageUrl: imageUrl,
            localImagePath: image.path,
            mealType: _mealType,
            onConfirm: (items, meal) async {
              await firestore.addFoodLog(
                uid,
                FoodLogModel(
                  id: '',
                  imageUrl: imageUrl,
                  detectedItems: items,
                  mealType: meal,
                  loggedAt: DateTime.now(),
                  source: FoodLogSource.aiScan,
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      _showError('Scan failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onBarcode(String code) async {
    if (_busy) return;
    final foodService = context.read<FoodService>();
    setState(() => _busy = true);
    try {
      final result = await foodService.searchByBarcode(code);
      if (!mounted) return;
      final item = result.item;
      if (item == null) {
        _showError(result.error ?? 'Product not found.');
        return;
      }

      final auth = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();
      final uid = auth.uid;
      if (uid == null) return;

      try {
        await _barcodeController?.stop();
      } catch (_) {
        // Lookup succeeded; navigation can continue even if already stopped.
      }
      if (!mounted) return;

      await Navigator.push(
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

      if (mounted && _mode == ScanMode.barcode) {
        try {
          await _barcodeController?.start();
        } catch (_) {
          _showError(
              'Could not restart barcode camera. Switch modes and try again.');
        }
      }
    } catch (_) {
      _showError('Could not check this product. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleFlash() async {
    if (_mode == ScanMode.barcode) {
      try {
        await _barcodeController?.toggleTorch();
        if (mounted) setState(() => _flashOn = !_flashOn);
      } catch (_) {
        _showError('Flash is not available for this camera.');
      }
      return;
    }
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
              controller: _barcodeController,
              errorBuilder: (context, error, child) => Container(
                color: Colors.black,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(32),
                child: const Text(
                  'Barcode camera could not start. Check camera permission and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              onDetect: (capture) {
                if (_busy) return;
                for (final barcode in capture.barcodes) {
                  final code = barcode.rawValue?.trim();
                  if (code != null && code.isNotEmpty) {
                    _onBarcode(code);
                    break;
                  }
                }
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
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
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
                    background: Colors.white.withValues(alpha: 0.2),
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
                    background: Colors.white.withValues(alpha: 0.2),
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
                  color: Colors.black.withValues(alpha: 0.45),
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
                            color: selected ? AppColors.ink : Colors.white70,
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
              onChanged: (i) => _changeMode(ScanMode.values[i]),
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
                  background: Colors.white.withValues(alpha: 0.2),
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
                  background: Colors.white.withValues(alpha: 0.2),
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
            ScanProgressOverlay(barcodeLookup: _mode == ScanMode.barcode),
        ],
      ),
    );
  }
}
