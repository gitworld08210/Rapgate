import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/coach_message_model.dart';
import '../../providers/health_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/coach_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// Full conversational AI Health & Diet Coach screen powered by Gemini.
class RepGateCoachScreen extends StatefulWidget {
  const RepGateCoachScreen({
    super.key,
    this.initialQuery,
  });

  final String? initialQuery;

  @override
  State<RepGateCoachScreen> createState() => _RepGateCoachScreenState();
}

class _RepGateCoachScreenState extends State<RepGateCoachScreen> {
  final CoachService _coachService = CoachService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<CoachMessage> _messages = [];
  bool _isLoading = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      _bootstrapConversation();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Builds context from UserProvider and HealthProvider
  UserHealthContext _buildCurrentContext() {
    final user = context.read<UserProvider>().userModel;
    final health = context.read<HealthProvider>();
    final foodStreak = context.read<UserProvider>().streaks?.currentFoodLogStreak ?? 0;
    final pushupStreak = context.read<UserProvider>().streaks?.currentPushupStreak ?? 0;
    final streak = foodStreak > 0 ? foodStreak : pushupStreak;

    final meals = <Map<String, dynamic>>[];
    for (final log in health.todayFoodLogs) {
      for (final item in log.detectedItems) {
        meals.add({
          'name': item.name,
          'calories': item.calories,
          'protein': item.protein,
          'carbs': item.carbs,
          'fat': item.fat,
          'mealType': log.mealType.name,
        });
      }
    }

    return UserHealthContext(
      userName: user?.name ?? 'Athlete',
      userAge: user?.age ?? 25,
      userWeight: user?.weight ?? 70.0,
      userHeight: user?.height ?? 170.0,
      userGender: user?.gender ?? 'male',
      calorieTarget: user?.dailyCalorieTarget ?? 2000.0,
      proteinTarget: user?.dailyProteinTarget ?? 100.0,
      carbsTarget: user?.dailyCarbsTarget ?? 250.0,
      fatTarget: user?.dailyFatTarget ?? 55.0,
      waterTargetMl: AppConstants.dailyWaterTargetMl,
      pushupTarget: user?.pushupTarget ?? 10,
      consumedCalories: health.todayTotalCalories,
      consumedProtein: health.todayTotalProtein,
      consumedCarbs: health.todayTotalCarbs,
      consumedFat: health.todayTotalFat,
      consumedWaterMl: health.todayWaterIntakeMl,
      streakDays: streak > 0 ? streak : 1,
      loggedMeals: meals,
    );
  }

  /// Bootstraps chat with initial greeting & handles initialQuery if passed
  void _bootstrapConversation() {
    final ctx = _buildCurrentContext();
    final name = ctx.userName.isNotEmpty ? ctx.userName : 'Dost';
    final pDeficit = ctx.proteinDeficit;

    final greeting = StringBuffer();
    greeting.writeln('Namaste $name! Main aapka **RepGate Coach** hoon 🤖');
    greeting.writeln('\nMaine aapka aaj ka live health snapshot review kiya hai:');
    greeting.writeln('• 🥗 **Calories:** ${ctx.consumedCalories.toInt()} / ${ctx.calorieTarget.toInt()} kcal');
    greeting.writeln('• 🥩 **Protein:** ${ctx.consumedProtein.toInt()} / ${ctx.proteinTarget.toInt()} g ${pDeficit > 0 ? "(*${pDeficit.toStringAsFixed(0)}g deficit*)" : "(*Target reached! 🎉*)"}');
    greeting.writeln('• 💧 **Water:** ${ctx.consumedWaterMl} / ${ctx.waterTargetMl} ml');
    greeting.writeln('• 🔥 **Streak:** ${ctx.streakDays} Days');

    if (pDeficit > 0) {
      greeting.writeln('\nBhai aaj aapko **${pDeficit.toStringAsFixed(0)}g protein** aur lena hai. Neeche diye quick buttons se puchein ya apna sawal type karein!');
    } else {
      greeting.writeln('\nShabash! Aaj ka protein goal complete ho chuka hai. Healthy hydration aur recovery maintain karein.');
    }

    setState(() {
      _messages.add(
        CoachMessage(
          id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
          text: greeting.toString(),
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: [
            '📊 Aaj ka progress report do',
            '💪 Protein target kaise pura karu?',
            '🥗 Aaj ka diet plan do',
            '⚠️ Kya galat khaya maine?',
          ],
        ),
      );
    });

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialQuery!.trim());
      });
    }
  }

  Future<void> _handleSendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();

    final userMsg = CoachMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: query,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    _scrollToBottom();

    final ctx = _buildCurrentContext();

    try {
      final response = await _coachService.sendMessage(
        userMessage: query,
        context: ctx,
        chatHistory: _messages,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            CoachMessage(
              id: 'coach_${DateTime.now().millisecondsSinceEpoch}',
              text: response.text,
              isUser: false,
              timestamp: DateTime.now(),
              suggestions: response.suggestions,
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            CoachMessage(
              id: 'err_${DateTime.now().millisecondsSinceEpoch}',
              text: 'Maaf kijiye, response process karne me thoda issue aaya. Kripya dobara try karein.',
              isUser: false,
              timestamp: DateTime.now(),
              suggestions: ['📊 Aaj ka progress report do', '💪 Protein target kaise pura karu?'],
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _bootstrapConversation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final health = context.watch<HealthProvider>();
    final user = context.watch<UserProvider>().userModel;
    final pTarget = user?.dailyProteinTarget ?? 100.0;
    final pConsumed = health.todayTotalProtein;
    final pDeficit = (pTarget - pConsumed).clamp(0.0, pTarget);
    final cTarget = user?.dailyCalorieTarget ?? 2000.0;
    final cConsumed = health.todayTotalCalories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 20)),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.limeBright,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RepGate Coach',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Gemini AI Health & Diet Coach',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.refresh, color: AppColors.ink, size: 22),
            onPressed: _clearChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Live Snapshot Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.grey200, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _metricPill(
                    icon: '🔥',
                    label: '${cConsumed.toInt()}/${cTarget.toInt()} kcal',
                    isAlert: cConsumed > cTarget,
                  ),
                  const SizedBox(width: 8),
                  _metricPill(
                    icon: '🥩',
                    label: pDeficit > 0
                        ? '${pConsumed.toInt()}g (${pDeficit.toStringAsFixed(0)}g baki)'
                        : '${pConsumed.toInt()}g (Done!)',
                    isAlert: pDeficit > 0,
                    highlightColor: pDeficit <= 0 ? AppColors.limeDeep : null,
                  ),
                  const SizedBox(width: 8),
                  _metricPill(
                    icon: '💧',
                    label: '${health.todayWaterIntakeMl} ml',
                  ),
                  const SizedBox(width: 8),
                  _metricPill(
                    icon: '⚡',
                    label: 'Day Streak',
                  ),
                ],
              ),
            ),
          ),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble();
                }
                final msg = _messages[index];
                return _buildMessageItem(msg);
              },
            ),
          ),

          // Quick Suggestion Chips Bar
          _buildQuickSuggestionsBar(),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _metricPill({
    required String icon,
    required String label,
    bool isAlert = false,
    Color? highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlightColor?.withOpacity(0.15) ??
            (isAlert ? const Color(0xFFFFF3E0) : AppColors.grey100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlightColor ??
              (isAlert ? AppColors.burned.withOpacity(0.4) : AppColors.grey200),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlightColor ?? (isAlert ? AppColors.burned : AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(CoachMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.white,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // Coach Message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'RepGate Coach',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.copy_rounded, size: 14, color: AppColors.grey500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.grey200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                msg.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            if (msg.suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.suggestions.map((s) {
                  return ActionChip(
                    backgroundColor: AppColors.white,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.grey300),
                    label: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    onPressed: () => _handleSendMessage(s),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.ink),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'RepGate Coach soch raha hai... ⚡',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestionsBar() {
    final chips = [
      '📊 Aaj ka progress report',
      '💪 Protein target kaise pura karu?',
      '🥗 Aaj ka diet plan do',
      '⚠️ Kya galat khaya maine?',
      '💧 Water intake check',
      '⚡ Push-up workout unlock',
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final text = chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: AppColors.limeWash,
              side: const BorderSide(color: AppColors.lime, width: 0.8),
              label: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              onPressed: () => _handleSendMessage(text),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.grey200, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _handleSendMessage,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Pucho health, diet ya protein ke bare me...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.grey500),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _handleSendMessage(_textController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.arrow_upward_rounded, color: AppColors.limeBright, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
