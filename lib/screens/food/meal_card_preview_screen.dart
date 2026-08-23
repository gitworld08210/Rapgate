import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../../services/share_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/meal_share_card.dart';
import '../../widgets/pill_button.dart';

/// Full-screen preview of the shareable meal card with Share and Save actions.
class MealCardPreviewScreen extends StatefulWidget {
  const MealCardPreviewScreen({
    super.key,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.healthScore,
    this.imageUrl,
    this.localImagePath,
    this.mealTypeLabel,
  });

  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double healthScore;
  final String? imageUrl;
  final String? localImagePath;
  final String? mealTypeLabel;

  @override
  State<MealCardPreviewScreen> createState() => _MealCardPreviewScreenState();
}

class _MealCardPreviewScreenState extends State<MealCardPreviewScreen> {
  final _shareService = ShareService.instance;
  bool _sharing = false;
  bool _saving = false;

  Future<void> _handleShare() async {
    setState(() => _sharing = true);
    try {
      final imageBytes = await _shareService.captureCardAsImage();
      if (imageBytes == null) {
        _showError('Could not generate image');
        return;
      }
      final caption =
          '${widget.foodName} - ${widget.calories.toStringAsFixed(0)} kcal 🔥\n'
          'P: ${widget.protein.toStringAsFixed(0)}g | '
          'C: ${widget.carbs.toStringAsFixed(0)}g | '
          'F: ${widget.fat.toStringAsFixed(0)}g\n'
          'Tracked with RepGate 💪';
      await _shareService.shareToSocial(imageBytes, caption);
    } catch (e) {
      _showError('Share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      final imageBytes = await _shareService.captureCardAsImage();
      if (imageBytes == null) {
        _showError('Could not generate image');
        return;
      }
      final success = await _shareService.saveToGallery(imageBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Saved to gallery ✅' : 'Could not save to gallery',
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Top bar ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.grey700.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Share Your Meal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // balance the close button
                ],
              ),
            ),

            // ---------- Card preview ----------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Screenshot(
                    controller: _shareService.controller,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: MealShareCard(
                        foodName: widget.foodName,
                        calories: widget.calories,
                        protein: widget.protein,
                        carbs: widget.carbs,
                        fat: widget.fat,
                        healthScore: widget.healthScore,
                        imageUrl: widget.imageUrl,
                        localImagePath: widget.localImagePath,
                        mealTypeLabel: widget.mealTypeLabel,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---------- Action buttons ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: PillButton(
                      label: 'Save',
                      icon: Icons.download_rounded,
                      variant: PillVariant.outline,
                      loading: _saving,
                      onPressed: _saving || _sharing ? null : _handleSave,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      variant: PillVariant.lime,
                      loading: _sharing,
                      onPressed: _sharing || _saving ? null : _handleShare,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
