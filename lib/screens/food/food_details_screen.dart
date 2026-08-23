import 'dart:io';
import 'package:flutter/material.dart';

import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';

/// Food Details — hero image, editable items, macro tiles, health score.
/// Mirrors the third screen in the reference set.
class FoodDetailsScreen extends StatefulWidget {
  const FoodDetailsScreen({
    super.key,
    required this.items,
    required this.mealType,
    this.imageUrl,
    this.localImagePath,
    this.onConfirm,
    this.readOnly = false,
    this.gramBasis,
  });

  final List<FoodItem> items;
  final MealType mealType;
  final String? imageUrl;
  final String? localImagePath;
  final Future<void> Function(List<FoodItem>, MealType)? onConfirm;
  final bool readOnly;

  /// How many grams the supplied nutrition refers to, when it comes from a
  /// packaged-food table rather than a plated portion (e.g. 100 for per-100 g
  /// values). Nobody eats a whole pack, so this switches the portion control
  /// from abstract "servings" to real grams in 50 g steps.
  final int? gramBasis;

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  late List<FoodItem> _items;
  late MealType _mealType;
  double _servings = 1.0;
  bool _saving = false;

  /// Packaged-food portions are chosen in grams. 50 g is the default because a
  /// per-100 g table would otherwise log double what a person actually eats.
  static const int _gramStep = 50;
  int _grams = _gramStep;

  bool get _gramMode => widget.gramBasis != null && widget.gramBasis! > 0;

  /// Scales the stated nutrition to the portion the user selected.
  double get _portionFactor =>
      _gramMode ? _grams / widget.gramBasis! : _servings;

  /// The lookup names a packaged item "<product> (per 100 g)" so the basis is
  /// visible before a portion is chosen. Once the user picks grams, restate the
  /// name with the real portion so the diary entry is not misread as per-100 g.
  String _portionLabelledName(String name) {
    if (!_gramMode) return name;
    final stripped =
        name.replaceFirst(RegExp(r'\s*\(per\s*\d+\s*g\)\s*$', caseSensitive: false), '');
    return '$stripped ($_grams g)';
  }

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _mealType = widget.mealType;
  }

  double get _calories =>
      _items.fold<double>(0, (s, i) => s + i.calories) * _portionFactor;
  double get _protein =>
      _items.fold<double>(0, (s, i) => s + i.protein) * _portionFactor;
  double get _carbs =>
      _items.fold<double>(0, (s, i) => s + i.carbs) * _portionFactor;
  double get _fat =>
      _items.fold<double>(0, (s, i) => s + i.fat) * _portionFactor;

  double get _avgConfidence => _items.isEmpty
      ? 0
      : _items.fold<double>(0, (s, i) => s + i.confidence) / _items.length;

  /// Heuristic 0–10 quality score from macro balance.
  double get _healthScore {
    if (_calories <= 0) return 0;
    final proteinCals = _protein * 4;
    final fatCals = _fat * 9;
    final proteinRatio = proteinCals / _calories;
    final fatRatio = fatCals / _calories;

    double s = 5;
    if (proteinRatio >= 0.25) {
      s += 3;
    } else if (proteinRatio >= 0.15) {
      s += 2;
    } else if (proteinRatio >= 0.10) {
      s += 1;
    }
    if (fatRatio > 0.45) {
      s -= 2.5;
    } else if (fatRatio > 0.35) {
      s -= 1;
    }
    if (_calories > 900) s -= 1;
    return s.clamp(0, 10);
  }

  Future<void> _save() async {
    if (widget.onConfirm == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      // Persist the nutrition for the portion the user actually selected.
      final scaled = _items
          .map((i) => FoodItem(
                name: _portionLabelledName(i.name),
                calories: i.calories * _portionFactor,
                protein: i.protein * _portionFactor,
                carbs: i.carbs * _portionFactor,
                fat: i.fat * _portionFactor,
                confidence: i.confidence,
              ))
          .toList();

      await widget.onConfirm!(scaled, _mealType);
      if (!mounted) return;
      Navigator.pop(context); // details
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your log ✅')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // ---------- Hero image ----------
              SizedBox(
                height: 320,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _heroImage(),
                    // Bottom fade so the sheet blends in
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).scaffoldBackgroundColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------- Content ----------
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: AppSpacing.page,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SoftCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _items.isEmpty
                                        ? 'Unrecognised item'
                                        : _items.first.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                if (_avgConfidence > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.limeSoft,
                                      borderRadius: AppRadius.chip,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.auto_awesome,
                                            size: 12,
                                            color: AppColors.limeDeep),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(_avgConfidence * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Total calories row
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.limeSoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Total ${_calories.toStringAsFixed(0)} Kcal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const Spacer(),
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            MacroRow(
                              carbs: _carbs,
                              protein: _protein,
                              fat: _fat,
                            ),
                            const SizedBox(height: 20),

                            HealthScoreBar(score: _healthScore),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ---------- Servings ----------
                      if (!widget.readOnly)
                        SoftCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_gramMode ? 'Portion' : 'Servings',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 2),
                                    Text(
                                      _gramMode
                                          ? 'How much you actually ate ($_gramStep g steps)'
                                          : 'Adjust the portion size',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              _stepper(),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppSpacing.lg),

                      // ---------- Meal type ----------
                      if (!widget.readOnly) ...[
                        Text('Add to',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: MealType.values.map((m) {
                            final selected = m == _mealType;
                            return GestureDetector(
                              onTap: () => setState(() => _mealType = m),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.ink
                                      : AppColors.grey100,
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AppColors.white
                                        : AppColors.grey500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],

                      // ---------- Detected items breakdown ----------
                      if (_items.length > 1) ...[
                        SectionHeader(title: 'Detected items'),
                        SoftCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                if (i > 0) const Divider(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(_items[i].name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall),
                                          const SizedBox(height: 2),
                                          Text(
                                            'P ${_items[i].protein.toStringAsFixed(0)}g · '
                                            'C ${_items[i].carbs.toStringAsFixed(0)}g · '
                                            'F ${_items[i].fat.toStringAsFixed(0)}g',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${_items[i].calories.toStringAsFixed(0)} kcal',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    if (!widget.readOnly) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _items.removeAt(i)),
                                        child: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: AppColors.grey500),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // ---------- AI disclaimer ----------
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.pastelOrange,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 17, color: AppColors.burned),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Nutrition values are AI-estimated, not medical advice.',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.grey700),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ---------- Top nav ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 17,
                    onTap: () => Navigator.pop(context),
                  ),
                  Text(
                    'Food Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  CircleIconButton(
                    icon: Icons.favorite_border_rounded,
                    iconSize: 19,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // ---------- Sticky actions ----------
          if (!widget.readOnly)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: PillButton(
                        label: 'Edit Details',
                        variant: PillVariant.outline,
                        onPressed: _showEditSheet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PillButton(
                        label: 'Add Food',
                        loading: _saving,
                        onPressed: _items.isEmpty ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heroImage() {
    if (widget.localImagePath != null) {
      return Image.file(File(widget.localImagePath!), fit: BoxFit.cover);
    }
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return Image.network(
        widget.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.limeSoft,
        alignment: Alignment.center,
        child: const Text('🥗', style: TextStyle(fontSize: 90)),
      );

  Widget _stepper() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        children: [
          _stepBtn(Icons.remove_rounded, () {
            if (_gramMode) {
              // Never below one step: a 0 g portion is not a meal.
              if (_grams > _gramStep) setState(() => _grams -= _gramStep);
            } else if (_servings > 0.5) {
              setState(() => _servings -= 0.5);
            }
          }),
          SizedBox(
            width: _gramMode ? 62 : 40,
            child: Text(
              _gramMode
                  ? '$_grams g'
                  : _servings.toStringAsFixed(_servings % 1 == 0 ? 0 : 1),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _stepBtn(Icons.add_rounded, () {
            if (_gramMode) {
              if (_grams < 1000) setState(() => _grams += _gramStep);
            } else if (_servings < 10) {
              setState(() => _servings += 0.5);
            }
          }),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditItemsSheet(
        items: _items,
        onSave: (updated) => setState(() => _items = updated),
      ),
    );
  }
}

/// Lets the user correct AI estimates before saving.
class _EditItemsSheet extends StatefulWidget {
  const _EditItemsSheet({required this.items, required this.onSave});

  final List<FoodItem> items;
  final ValueChanged<List<FoodItem>> onSave;

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

class _EditItemsSheetState extends State<_EditItemsSheet> {
  late List<TextEditingController> _name;
  late List<TextEditingController> _cal;
  late List<TextEditingController> _pro;
  late List<TextEditingController> _car;
  late List<TextEditingController> _fat;

  @override
  void initState() {
    super.initState();
    _name = widget.items
        .map((i) => TextEditingController(text: i.name))
        .toList();
    _cal = widget.items
        .map((i) => TextEditingController(text: i.calories.toStringAsFixed(0)))
        .toList();
    _pro = widget.items
        .map((i) => TextEditingController(text: i.protein.toStringAsFixed(0)))
        .toList();
    _car = widget.items
        .map((i) => TextEditingController(text: i.carbs.toStringAsFixed(0)))
        .toList();
    _fat = widget.items
        .map((i) => TextEditingController(text: i.fat.toStringAsFixed(0)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in [..._name, ..._cal, ..._pro, ..._car, ..._fat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final updated = <FoodItem>[];
    for (var i = 0; i < widget.items.length; i++) {
      updated.add(FoodItem(
        name: _name[i].text.trim().isEmpty ? 'Item' : _name[i].text.trim(),
        calories: double.tryParse(_cal[i].text) ?? 0,
        protein: double.tryParse(_pro[i].text) ?? 0,
        carbs: double.tryParse(_car[i].text) ?? 0,
        fat: double.tryParse(_fat[i].text) ?? 0,
        confidence: 1.0, // user-corrected = full confidence
      ));
    }
    widget.onSave(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Edit nutrition',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Correct anything the AI got wrong',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < widget.items.length; i++) ...[
              if (i > 0) const SizedBox(height: 20),
              TextField(
                controller: _name[i],
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_cal[i], 'Kcal')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_pro[i], 'Protein')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_car[i], 'Carbs')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField(_fat[i], 'Fat')),
                ],
              ),
            ],
            const SizedBox(height: 26),
            PillButton(label: 'Save changes', onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}
