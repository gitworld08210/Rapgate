import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/coach_message_model.dart';
import '../../services/auth_service.dart';
import '../../services/health_coach_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/coach_widgets.dart';

/// AI nutrition coach chat.
///
/// The coach answers against the user's own logged intake, which the Edge
/// Function assembles server-side. Nothing about the user's diet is sent from
/// the device, so the answers cannot be steered by a tampered client.
class HealthCoachScreen extends StatefulWidget {
  const HealthCoachScreen({super.key});

  @override
  State<HealthCoachScreen> createState() => _HealthCoachScreenState();
}

class _HealthCoachScreenState extends State<HealthCoachScreen> {
  late final HealthCoachService _service = context.read<HealthCoachService>();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  final List<CoachMessage> _messages = [];
  bool _loadingHistory = true;
  bool _sending = false;
  bool _hasText = false;

  static const _starters = [
    (
      label: 'How am I doing today?',
      icon: Icons.insights_rounded,
    ),
    (
      label: 'Help me hit my protein goal',
      icon: Icons.egg_alt_rounded,
    ),
    (
      label: 'What should I eat for dinner?',
      icon: Icons.dinner_dining_rounded,
    ),
    (
      label: 'High-protein Indian snacks',
      icon: Icons.local_dining_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final uid = context.read<AuthService>().uid;
    if (uid == null) {
      setState(() => _loadingHistory = false);
      return;
    }
    try {
      final history = await _service.loadHistory(uid);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history);
        _loadingHistory = false;
      });
      _scrollToEnd(animate: false);
    } catch (_) {
      // A history read failure must not block a new conversation.
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _scrollToEnd({bool animate = true}) {
    // Deferred to the next frame so the freshly inserted bubble is laid out and
    // maxScrollExtent already includes it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    final auth = context.read<AuthService>();
    final sessionValid = await auth.ensureValidSession();
    if (!sessionValid) {
      if (mounted) {
        _showError('Your session has expired. Please sign in again.');
      }
      return;
    }

    HapticFeedback.lightImpact();
    _controller.clear();

    setState(() {
      _sending = true;
      _messages
        ..add(CoachMessage(role: CoachRole.user, text: text))
        // A pending coach bubble holds the typing indicator in the position the
        // real reply will occupy, so the list does not jump when it arrives.
        ..add(CoachMessage(
          role: CoachRole.model,
          text: '',
          isPending: true,
        ));
    });
    _scrollToEnd();

    try {
      final reply = await _service.send(
        message: text,
        // Exclude the two bubbles just added: the pending placeholder is not a
        // real turn, and the server appends the current message itself.
        history: _messages.sublist(0, _messages.length - 2),
      );
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = CoachMessage(
          role: CoachRole.model,
          text: reply.reply,
          suggestions: reply.suggestions,
        );
        _sending = false;
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // Drop the placeholder and mark the user's turn as retryable so their
        // text is never silently lost.
        _messages.removeLast();
        final last = _messages.length - 1;
        if (last >= 0 && _messages[last].isUser) {
          _messages[last] = _messages[last].copyWith(hasFailed: true);
        }
        _sending = false;
      });
      _showError(
        error is CoachException
            ? error.message
            : 'Could not reach the coach. Please try again.',
      );
    }
  }

  Future<void> _retryLast() async {
    final index = _messages.lastIndexWhere((m) => m.isUser && m.hasFailed);
    if (index < 0) return;
    final text = _messages[index].text;
    setState(() => _messages.removeRange(index, _messages.length));
    await _send(text);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
          'This deletes your chat history with the coach. Your food logs and '
          'progress are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid = context.read<AuthService>().uid;
    if (uid == null) return;
    setState(() => _messages.clear());
    try {
      await _service.clearHistory(uid);
    } catch (_) {
      _showError('Could not clear the history on the server.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(isDark),
            Expanded(
              child: _loadingHistory
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    )
                  : _messages.isEmpty
                      ? _emptyState(isDark)
                      : _messageList(),
            ),
            _inputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.grey200,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            color: isDark ? AppColors.white : AppColors.ink,
          ),
          const CoachAvatar(size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RepGate Coach',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _sending ? 'Thinking…' : 'Knows your food log',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
              color: AppColors.grey500,
              tooltip: 'Clear conversation',
            ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final message = _messages[i];
        final bubble = CoachBubble(
          message: message,
          onRetry: message.hasFailed ? _retryLast : null,
          onSuggestionTap: (suggestion) => _send(
            'Tell me more about ${suggestion.name}',
          ),
        );
        // Only animate the newest pair; re-animating on every rebuild would
        // make the whole list shimmer while scrolling.
        return i >= _messages.length - 2
            ? MessageEntrance(child: bubble)
            : bubble;
      },
    );
  }

  Widget _emptyState(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CoachAvatar(size: 64),
          const SizedBox(height: 20),
          Text(
            'Ask me anything about your diet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'I can see what you logged today and how your week is going, '
            'so the advice fits your actual numbers.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey500,
                ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _starters
                .map((starter) => StarterPromptChip(
                      label: starter.label,
                      icon: starter.icon,
                      onTap: () => _send(starter.label),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.grey100,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.grey500),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'General guidance only, not medical advice.',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 26,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.grey200,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _inputFocus,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 14.5, height: 1.4),
                decoration: const InputDecoration(
                  hintText: 'Ask your coach…',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // The send button only becomes solid once there is something to send,
          // which keeps the primary action honest instead of always-lit.
          AnimatedScale(
            scale: _hasText && !_sending ? 1 : 0.9,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTap: _hasText && !_sending ? _send : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _hasText && !_sending
                      ? (isDark ? AppColors.limeBright : AppColors.ink)
                      : (isDark ? AppColors.darkCard : AppColors.grey200),
                  shape: BoxShape.circle,
                  boxShadow: _hasText && !_sending
                      ? AppShadows.medium
                      : null,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.grey500,
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        size: 21,
                        color: _hasText
                            ? (isDark ? AppColors.ink : AppColors.white)
                            : AppColors.grey500,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
