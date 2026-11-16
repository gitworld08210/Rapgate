import 'dart:io';
import 'package:flutter/material.dart';

import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';

enum DesiPortionUnit { standard, smallKatori, mediumKatori, largeBowl, handful }
enum RotiBreadType { none, dryPhulka, gheeRoti, stuffedParatha, naanTandoori }
enum MilkFatType { toned, cowMilk, buffaloMilk }

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

  DesiPortionUnit _portionUnit = DesiPortionUnit.standard;
  RotiBreadType _rotiType = RotiBreadType.none;
  MilkFatType _milkType = MilkFatType.toned;
  int _sugarTeaspoons = 0;

  double get _portionUnitMultiplier => switch (_portionUnit) {
        DesiPortionUnit.standard => 1.0,
        DesiPortionUnit.smallKatori => 0.7,
        DesiPortionUnit.mediumKatori => 1.0,
        DesiPortionUnit.largeBowl => 1.6,
        DesiPortionUnit.handful => 0.5,
      };

  /// Scales the stated nutrition to the portion the user selected.
  double get _portionFactor =>
      _gramMode ? _grams / widget.gramBasis! : (_servings * _portionUnitMultiplier);

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

  IndianCookingStyle _cookingStyle = IndianCookingStyle.homeStyle;

  double get _extraFatGrams =>
      (switch (_cookingStyle) {
        IndianCookingStyle.lowOil => 0.0,
        IndianCookingStyle.homeStyle => 5.0,
        IndianCookingStyle.dhabaStyle => 14.0,
      }) +
      (switch (_rotiType) {
        RotiBreadType.none => 0.0,
        RotiBreadType.dryPhulka => -3.5,
        RotiBreadType.gheeRoti => 0.0,
        RotiBreadType.stuffedParatha => 8.0,
        RotiBreadType.naanTandoori => 5.0,
      }) +
      (switch (_milkType) {
        MilkFatType.toned => 0.0,
        MilkFatType.cowMilk => 2.0,
        MilkFatType.buffaloMilk => 6.0,
      });

  double get _extraCarbGrams =>
      (_sugarTeaspoons * 5.0) +
      (switch (_rotiType) {
        RotiBreadType.stuffedParatha => 12.0,
        RotiBreadType.naanTandoori => 18.0,
        _ => 0.0,
      });

  double get _extraProteinGrams => switch (_rotiType) {
        RotiBreadType.stuffedParatha => 2.5,
        _ => 0.0,
      };

  double get _extraCalories =>
      (_extraFatGrams * 9.0) +
      (_extraCarbGrams * 4.0) +
      (_extraProteinGrams * 4.0);

  double get _calories =>
      ((_items.fold<double>(0, (s, i) => s + i.calories) + _extraCalories) *
          _portionFactor).clamp(0.0, 10000.0);
  double get _protein =>
      ((_items.fold<double>(0, (s, i) => s + i.protein) + _extraProteinGrams) *
          _portionFactor).clamp(0.0, 1000.0);
  double get _carbs =>
      ((_items.fold<double>(0, (s, i) => s + i.carbs) + _extraCarbGrams) *
          _portionFactor).clamp(0.0, 1000.0);
  double get _fat =>
      ((_items.fold<double>(0, (s, i) => s + i.fat) + _extraFatGrams) *
          _portionFactor).clamp(0.0, 1000.0);

  double get _avgConfidence => _items.isEmpty
      ? 0
      : _items.fold<double>(0, (s, i) => s + i.confidence) / _items.length;

  void _showItemDialog({int? index}) {
    final isNew = index == null;
    final item = isNew
        ? FoodItem(name: '', calories: 0, protein: 0, carbs: 0, fat: 0, confidence: 1.0)
        : _items[index];

    final nameCtrl = TextEditingController(text: item.name);
    final calCtrl = TextEditingController(
        text: item.calories > 0 ? item.calories.toStringAsFixed(0) : '');
    final proteinCtrl = TextEditingController(
        text: item.protein > 0 ? item.protein.toStringAsFixed(0) : '');
    final carbsCtrl = TextEditingController(
        text: item.carbs > 0 ? item.carbs.toStringAsFixed(0) : '');
    final fatCtrl = TextEditingController(
        text: item.fat > 0 ? item.fat.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Add Food Item' : 'Edit Food Item',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Food Name (e.g. Roti, Apple)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories (kcal)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fat (g)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final cal = double.tryParse(calCtrl.text) ?? 0;
              final p = double.tryParse(proteinCtrl.text) ?? 0;
              final c = double.tryParse(carbsCtrl.text) ?? 0;
              final f = double.tryParse(fatCtrl.text) ?? 0;

              final updated = FoodItem(
                name: name,
                calories: cal,
                protein: p,
                carbs: c,
                fat: f,
                confidence: item.confidence > 0 ? item.confidence : 1.0,
              );

              setState(() {
                if (isNew) {
                  _items.add(updated);
                } else {
                  _items[index] = updated;
                }
              });
              Navigator.pop(ctx);
            },
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

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
      // Persist the nutrition for the portion and cooking style the user actually selected.
      final scaled = _items.asMap().entries.map((entry) {
        final i = entry.value;
        final isFirst = entry.key == 0;
        final itemExtraFat = isFirst ? _extraFatGrams : 0.0;
        final itemExtraCarb = isFirst ? _extraCarbGrams : 0.0;
        final itemExtraProtein = isFirst ? _extraProteinGrams : 0.0;
        final itemExtraCal = (itemExtraFat * 9.0) + (itemExtraCarb * 4.0) + (itemExtraProtein * 4.0);

        String name = (_gramMode && _items.length == 1)
            ? _portionLabelledName(i.name)
            : i.name;

        if (_cookingStyle == IndianCookingStyle.dhabaStyle && isFirst) {
          name = '$name (Restaurant Butter)';
        } else if (_cookingStyle == IndianCookingStyle.lowOil && isFirst) {
          name = '$name (Low Oil Diet)';
        }

        return FoodItem(
          name: name,
          calories: (i.calories + itemExtraCal) * _portionFactor,
          protein: (i.protein + itemExtraProtein) * _portionFactor,
          carbs: (i.carbs + itemExtraCarb) * _portionFactor,
          fat: (i.fat + itemExtraFat) * _portionFactor,
          confidence: i.confidence,
        );
      }).toList();

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
    final isDark = AppColors.isDark(context);
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
                                        : _items.length == 1
                                            ? _items.first.name
                                            : 'Meal (${_items.length} items)',
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
                                      color: isDark ? AppColors.darkSurface : AppColors.limeSoft,
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
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppColors.limeBright : AppColors.ink,
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
                                color: isDark ? AppColors.darkSurface : AppColors.limeSoft,
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

                      // ---------- Protein Density & Macro Truth Meter ----------
                      _buildMacroTruthCard(),

                      const SizedBox(height: AppSpacing.lg),

                      // ---------- Calorie Burn Equivalent Calculator ----------
                      _buildBurnEquivalentCard(),

                      const SizedBox(height: AppSpacing.lg),

                      // ---------- Indian Cooking Style & Tadka Slider ----------
                      if (!widget.readOnly) ...[
                        _buildIndianCookingStyleCard(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildRotiCustomizerCard(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildDairyChaiCustomizerCard(),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // ---------- Servings & Desi Portions ----------
                      if (!widget.readOnly)
                        SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                              : 'Adjust portion scale or select serving unit',
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
                              if (!_gramMode) ...[
                                const Divider(height: 20, color: AppColors.grey200),
                                _buildDesiPortionUnitSelector(),
                              ],
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
                      if (_items.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Items in meal (${_items.length})',
                                style: Theme.of(context).textTheme.titleSmall),
                            if (!widget.readOnly)
                              TextButton.icon(
                                onPressed: () => _showItemDialog(),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Item',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SoftCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < _items.length; i++) ...[
                                if (i > 0) const Divider(height: 18),
                                InkWell(
                                  onTap: widget.readOnly
                                      ? null
                                      : () => _showItemDialog(index: i),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(_items[i].name,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall),
                                                ),
                                                if (!widget.readOnly) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                      Icons.edit_outlined,
                                                      size: 13,
                                                      color: AppColors.grey500),
                                                ],
                                              ],
                                            ),
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
                          color: isDark ? const Color(0xFF3E2723) : AppColors.pastelOrange,
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
                                    ?.copyWith(color: isDark ? const Color(0xFFFFCC80) : AppColors.grey700),
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
        child: Icon(icon, size: 18, color: AppColors.textPrimary(context)),
      ),
    );
  }

  Widget _buildBurnEquivalentCard() {
    if (_calories <= 0) return const SizedBox.shrink();

    // Rates: Brisk walk = 4.5 kcal/min, Jogging = 10 kcal/min, Push-ups = 0.5 kcal/rep, Cycling = 8 kcal/min
    final walkMins = (_calories / 4.5).round();
    final walkKm = (walkMins * 0.08).toStringAsFixed(1);
    final jogMins = (_calories / 10.0).round();
    final pushups = (_calories / 0.5).round();
    final cycleMins = (_calories / 8.0).round();

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Calorie Burn Equivalent',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${_calories.toStringAsFixed(0)} kcal',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.burned,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _burnTile(
                icon: Icons.directions_walk_rounded,
                value: '$walkMins m',
                label: 'Walk ($walkKm km)',
                tint: const Color(0xFF00C853),
              ),
              const SizedBox(width: 8),
              _burnTile(
                icon: Icons.directions_run_rounded,
                value: '$jogMins m',
                label: 'Jogging',
                tint: const Color(0xFFFF9100),
              ),
              const SizedBox(width: 8),
              _burnTile(
                icon: Icons.fitness_center_rounded,
                value: '$pushups',
                label: 'Push-ups',
                tint: const Color(0xFFE040FB),
              ),
              const SizedBox(width: 8),
              _burnTile(
                icon: Icons.directions_bike_rounded,
                value: '$cycleMins m',
                label: 'Cycling',
                tint: const Color(0xFF00B0FF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _burnTile({
    required IconData icon,
    required String value,
    required String label,
    required Color tint,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: tint.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: tint),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndianCookingStyleCard() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🇮🇳', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cooking Style & Oil Adjustment',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: switch (_cookingStyle) {
                    IndianCookingStyle.lowOil => AppColors.limeSoft,
                    IndianCookingStyle.homeStyle => AppColors.pastelOrange,
                    IndianCookingStyle.dhabaStyle => const Color(0xFFFFECE5),
                  },
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  switch (_cookingStyle) {
                    IndianCookingStyle.lowOil => '0g extra oil',
                    IndianCookingStyle.homeStyle => '+5g oil/ghee (+45 kcal)',
                    IndianCookingStyle.dhabaStyle => '+14g butter (+126 kcal)',
                  },
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: switch (_cookingStyle) {
                      IndianCookingStyle.lowOil => AppColors.limeDeep,
                      IndianCookingStyle.homeStyle => AppColors.ink,
                      IndianCookingStyle.dhabaStyle => AppColors.burned,
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Adjusts fat & calories based on real home cooking vs restaurant preparations',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _cookingOption(
                label: 'Diet / Low Oil',
                subtitle: 'Steamed / Air-fried',
                icon: Icons.eco_rounded,
                style: IndianCookingStyle.lowOil,
              ),
              const SizedBox(width: 8),
              _cookingOption(
                label: 'Home Style',
                subtitle: 'Standard Tadka',
                icon: Icons.home_rounded,
                style: IndianCookingStyle.homeStyle,
              ),
              const SizedBox(width: 8),
              _cookingOption(
                label: 'Restaurant Rich',
                subtitle: 'Heavy Butter/Ghee',
                icon: Icons.restaurant_rounded,
                style: IndianCookingStyle.dhabaStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTruthCard() {
    final proteinCal = _protein * 4;
    final ratio = _calories > 0 ? (proteinCal / _calories) * 100 : 0.0;
    final isHighProtein = ratio >= 28;
    final isModerate = ratio >= 15 && ratio < 28;
    final hasGlycemicWarning = _carbs > 55 && _protein < 10 && _fat < 10;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isHighProtein
                      ? AppColors.limeSoft
                      : (isModerate ? AppColors.pastelBlue : AppColors.pastelOrange),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isHighProtein ? '🥩' : (isModerate ? '🥗' : '🍚'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protein Density: ${ratio.toStringAsFixed(0)}% of total energy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      isHighProtein
                          ? 'High protein density — optimal for muscle protein synthesis'
                          : (isModerate
                              ? 'Balanced macro profile'
                              : 'Carbohydrate dominant meal'),
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasGlycemicWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.isDark(context) ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.burned.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚡', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'High Glycemic Proportion: Rapid carb digestion with low protein. Pairing with a fiber salad or curd helps stabilize post-meal glucose.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.burned,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesiPortionUnitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'Quick Serving Size:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _portionUnitChip(
                label: 'Standard (1.0x)',
                unit: DesiPortionUnit.standard,
              ),
              const SizedBox(width: 6),
              _portionUnitChip(
                label: 'Small Katori ~100ml (0.7x)',
                unit: DesiPortionUnit.smallKatori,
              ),
              const SizedBox(width: 6),
              _portionUnitChip(
                label: 'Medium Katori ~150ml (1.0x)',
                unit: DesiPortionUnit.mediumKatori,
              ),
              const SizedBox(width: 6),
              _portionUnitChip(
                label: 'Large Bowl ~250ml (1.6x)',
                unit: DesiPortionUnit.largeBowl,
              ),
              const SizedBox(width: 6),
              _portionUnitChip(
                label: 'Handful Portion (0.5x)',
                unit: DesiPortionUnit.handful,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _portionUnitChip({
    required String label,
    required DesiPortionUnit unit,
  }) {
    final selected = _portionUnit == unit;
    return GestureDetector(
      onTap: () => setState(() => _portionUnit = unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.subtleFill(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.buttonPrimaryFg(context) : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildRotiCustomizerCard() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🫓', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Flatbread & Roti Customizer',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Calibrate fat and calories based on dough and ghee application',
            style: TextStyle(fontSize: 11, color: AppColors.grey500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _rotiOptionChip('As Detected', RotiBreadType.none),
              _rotiOptionChip('Dry Phulka (-30 kcal)', RotiBreadType.dryPhulka),
              _rotiOptionChip('Standard Ghee Roti', RotiBreadType.gheeRoti),
              _rotiOptionChip('Stuffed Paratha (+120 kcal)', RotiBreadType.stuffedParatha),
              _rotiOptionChip('Restaurant Naan (+130 kcal)', RotiBreadType.naanTandoori),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rotiOptionChip(String label, RotiBreadType type) {
    final selected = _rotiType == type;
    return GestureDetector(
      onTap: () => setState(() => _rotiType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.subtleFill(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.buttonPrimaryFg(context) : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDairyChaiCustomizerCard() {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🥛', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dairy & Tea Customizer',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Account for milk fat percentage and added sugar spoons',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 12),
          Text('Milk Fat Type:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
          const SizedBox(height: 6),
          Row(
            children: [
              _milkOptionChip('Toned (3% Fat)', MilkFatType.toned),
              const SizedBox(width: 6),
              _milkOptionChip('Cow Milk (+20 kcal)', MilkFatType.cowMilk),
              const SizedBox(width: 6),
              _milkOptionChip('Buffalo Milk (+65 kcal)', MilkFatType.buffaloMilk),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Added Sugar:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
              const SizedBox(width: 10),
              _sugarChip(0, '0 tsp'),
              const SizedBox(width: 6),
              _sugarChip(1, '1 tsp (+20 kcal)'),
              const SizedBox(width: 6),
              _sugarChip(2, '2 tsp (+40 kcal)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _milkOptionChip(String label, MilkFatType type) {
    final selected = _milkType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _milkType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.subtleFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.border(context),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.buttonPrimaryFg(context) : AppColors.textPrimary(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sugarChip(int spoons, String label) {
    final selected = _sugarTeaspoons == spoons;
    return GestureDetector(
      onTap: () => setState(() => _sugarTeaspoons = spoons),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.subtleFill(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.buttonPrimaryBg(context) : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.buttonPrimaryFg(context) : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _cookingOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required IndianCookingStyle style,
  }) {
    final selected = _cookingStyle == style;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cookingStyle = style),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.grey100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.ink : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.limeBright : AppColors.grey700,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.white : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? AppColors.grey300 : AppColors.grey500,
                ),
              ),
            ],
          ),
        ),
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
