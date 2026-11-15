import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/food_service.dart';
import '../../models/food_log_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/macro_widgets.dart';
import '../../widgets/meal_widgets.dart';
import 'food_scanner_screen.dart';
import 'food_details_screen.dart';

class FoodLogScreen extends StatefulWidget {
  const FoodLogScreen({super.key, this.initialMeal});

  final MealType? initialMeal;

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  final _searchController = TextEditingController();
  int _categoryIndex = 0;

  static const _categories = [
    (label: 'All', emoji: '🍽️'),
    (label: 'Vegan', emoji: '🥬'),
    (label: 'Carb', emoji: '🍝'),
    (label: 'Protein', emoji: '🍗'),
    (label: 'Snacks', emoji: '🍿'),
    (label: 'Drink', emoji: '🥤'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final user = context.watch<UserProvider>().userModel;
    final double target = user?.dailyCalorieTarget ?? 2000;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ---------- Header ----------
            Padding(
              padding: AppSpacing.page,
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        iconSize: 16,
                        bordered: true,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  Expanded(
                    child: Text('Food Log',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---------- Search + AI assistant pill ----------
            Padding(
              padding: AppSpacing.page,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Describe your food…',
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 20, color: AppColors.grey500),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onSubmitted: _describeFood,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _describeFood(_searchController.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: AppRadius.chip,
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Assistant',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(Icons.auto_awesome,
                              size: 14, color: AppColors.limeBright),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ---------- Quick Indian Food Suggestions ----------
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _quickIndianChip('2 Roti + Dal Tadka'),
                  _quickIndianChip('Paneer Bhurji + 2 Paratha'),
                  _quickIndianChip('1 Cup Masala Chai'),
                  _quickIndianChip('Chicken Biryani'),
                  _quickIndianChip('1 Glass Sattu Drink'),
                  _quickIndianChip('3 Boiled Eggs'),
                  _quickIndianChip('1 Bowl Curd Rice'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Daily summary ----------
            Padding(
              padding: AppSpacing.page,
              child: SoftCard(
                color: AppColors.limeSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Today’s intake',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    health.todayTotalCalories
                                        .toStringAsFixed(0),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge,
                                  ),
                                  Text(
                                    ' / ${target.toStringAsFixed(0)} kcal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.local_fire_department_rounded,
                              color: AppColors.burned, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SoftProgressBar(
                      progress:
                          target <= 0 ? 0 : health.todayTotalCalories / target,
                      height: 9,
                      showBubble: true,
                    ),
                    const SizedBox(height: 18),
                    MacroRow(
                      carbs: health.todayTotalCarbs,
                      protein: health.todayTotalProtein,
                      fat: health.todayTotalFat,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Categories ----------
            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(title: 'Categories', actionLabel: 'See all'),
            ),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) => CategoryChip(
                  label: _categories[i].label,
                  emoji: _categories[i].emoji,
                  selected: i == _categoryIndex,
                  onTap: () => setState(() => _categoryIndex = i),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ---------- Quick add actions ----------
            Padding(
              padding: AppSpacing.page,
              child: Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      icon: Icons.center_focus_strong_rounded,
                      label: 'Scan food',
                      tint: AppColors.limeDeep,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodScannerScreen(
                            mealType: widget.initialMeal ?? MealType.lunch,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionCard(
                      icon: Icons.mic_rounded,
                      label: 'Voice log',
                      tint: AppColors.burned,
                      onTap: _openVoiceLoggerDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionCard(
                      icon: Icons.edit_note_rounded,
                      label: 'Manual entry',
                      tint: AppColors.protein,
                      onTap: _manualEntry,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ---------- Logged meals ----------
            Padding(
              padding: AppSpacing.page,
              child: SectionHeader(title: 'Logged today'),
            ),

            if (health.todayFoodLogs.isEmpty)
              Padding(
                padding: AppSpacing.page,
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      const Text('🍽️', style: TextStyle(fontSize: 42)),
                      const SizedBox(height: 12),
                      Text('Nothing logged yet',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Scan a meal to get started',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...MealType.values.map((meal) {
                final logs = health.todayFoodLogs
                    .where((l) => l.mealType == meal)
                    .toList();
                if (logs.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: AppSpacing.md),
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              switch (meal) {
                                MealType.breakfast => 'Breakfast',
                                MealType.lunch => 'Lunch',
                                MealType.dinner => 'Dinner',
                                MealType.snack => 'Snacks',
                              },
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              '${logs.fold<double>(0, (s, l) => s + l.totalCalories).toStringAsFixed(0)} kcal',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final log in logs)
                          for (final item in log.detectedItems)
                            MealLogRow(
                              name: item.name,
                              kcal: item.calories,
                              imageUrl: log.imageUrl,
                              subtitle:
                                  '${item.calories.toStringAsFixed(0)} Cal · P ${item.protein.toStringAsFixed(0)}g',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FoodDetailsScreen(
                                    items: log.detectedItems,
                                    mealType: log.mealType,
                                    imageUrl: log.imageUrl,
                                    readOnly: true,
                                  ),
                                ),
                              ),
                              onRemove: () => _deleteLog(log.id),
                            ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _quickIndianChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          _searchController.text = text;
          _describeFood(text);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.grey300.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppColors.limeDeep),
              const SizedBox(width: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  void _openVoiceLoggerDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.mic_rounded, color: AppColors.burned, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voice & Natural Language Logger',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Describe meal in plain English (e.g. 2 rotis with dal)',
                          style: TextStyle(fontSize: 12, color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Speak or type: "2 rotis, bowl of dal tadka, 100g paneer"',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey500),
                  filled: true,
                  fillColor: AppColors.grey100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.record_voice_over_rounded, color: AppColors.grey700),
                ),
                onSubmitted: (text) {
                  Navigator.pop(ctx);
                  _describeFood(text);
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Quick Examples:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _voicePromptChip(ctx, controller, '2 Rotis + Dal Tadka + Rice'),
                  _voicePromptChip(ctx, controller, 'Paneer Bhurji + 2 Parathas'),
                  _voicePromptChip(ctx, controller, 'Chicken Biryani Plate'),
                  _voicePromptChip(ctx, controller, 'Masala Chai + 2 Boiled Eggs'),
                ],
              ),
              const SizedBox(height: 18),
              PillButton(
                label: 'Analyze & Log Meal ⚡',
                variant: PillVariant.dark,
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(ctx);
                    _describeFood(text);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _voicePromptChip(BuildContext ctx, TextEditingController ctrl, String query) {
    return GestureDetector(
      onTap: () {
        ctrl.text = query;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey300),
        ),
        child: Text(
          query,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink),
        ),
      ),
    );
  }

  Future<void> _deleteLog(String logId) async {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return;
    await context.read<FirestoreService>().deleteFoodLog(uid, logId);
  }

  /// Text-described food → routed through the real Gemini AI estimation path.
  Future<void> _describeFood(String text) async {
    final query = text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Describe what you ate, e.g. "2 rotis and dal"')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('AI is calculating nutrition…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final foodService = context.read<FoodService>();
      final result = await foodService.estimateNutritionFromText(
        textQuery: query,
        mealType: widget.initialMeal ?? MealType.lunch,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final items = result.detectedItems.isNotEmpty
          ? result.detectedItems
          : [FoodItem(name: query, calories: 0, protein: 0, carbs: 0, fat: 0)];

      final auth = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();
      final uid = auth.uid;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodDetailsScreen(
            items: items,
            mealType: widget.initialMeal ?? MealType.lunch,
            onConfirm: (confirmedItems, meal) async {
              if (uid == null) return;
              await firestore.addFoodLog(
                uid,
                FoodLogModel(
                  id: '',
                  detectedItems: confirmedItems,
                  mealType: meal,
                  loggedAt: DateTime.now(),
                  source: FoodLogSource.aiScan,
                ),
              );
            },
          ),
        ),
      );
      _searchController.clear();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI estimation failed: $e. Using manual mode.')),
      );
      _manualEntry(prefillName: query);
    }
  }

  void _manualEntry({String? prefillName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailsScreen(
          items: [
            FoodItem(
              name: prefillName ?? 'New item',
              calories: 0,
              protein: 0,
              carbs: 0,
              fat: 0,
            ),
          ],
          mealType: widget.initialMeal ?? MealType.snack,
          onConfirm: (items, meal) async {
            final uid = context.read<AuthService>().uid;
            if (uid == null) return;
            await context.read<FirestoreService>().addFoodLog(
                  uid,
                  FoodLogModel(
                    id: '',
                    detectedItems: items,
                    mealType: meal,
                    loggedAt: DateTime.now(),
                    source: FoodLogSource.manual,
                  ),
                );
          },
        ),
      ),
    );
  }
}
