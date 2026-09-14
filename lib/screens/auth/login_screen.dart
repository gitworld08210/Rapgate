import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';

/// Welcome / auth screen. Passwordless **email OTP** only: enter an email,
/// receive a 6-digit code (delivered via Azure), verify it. Phone auth removed.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showForm
          ? _EmailOtpForm(onBack: () => setState(() => _showForm = false))
          : _buildHero(),
    );
  }

  Widget _buildHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.limeSoft, AppColors.limeWash, AppColors.white],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        const Positioned(
          top: 70,
          right: -30,
          child: Opacity(opacity: 0.9, child: Text('🥑', style: TextStyle(fontSize: 130))),
        ),
        const Positioned(
          top: 210,
          left: -20,
          child: Opacity(opacity: 0.85, child: Text('🥦', style: TextStyle(fontSize: 100))),
        ),
        const Positioned(
          top: 130,
          left: 130,
          child: Opacity(opacity: 0.95, child: Text('💪', style: TextStyle(fontSize: 86))),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Eat well.\nEarn your\nscreen time.',
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 38, height: 1.12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.limeBright, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Track your nutrition with AI food scanning — and unlock '
                  'your distracting apps only after camera-verified push-ups.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.grey700),
                ),
                const SizedBox(height: 30),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeatureChip(emoji: '📸', label: 'AI food scan'),
                    _FeatureChip(emoji: '🔒', label: 'App lock'),
                    _FeatureChip(emoji: '💧', label: 'Hydration'),
                    _FeatureChip(emoji: '📈', label: 'Progress'),
                  ],
                ),
                const Spacer(flex: 2),
                PillButton(
                  label: 'Continue with Email',
                  icon: Icons.mail_outline_rounded,
                  onPressed: () => setState(() => _showForm = true),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'No passwords. We email you a one-time code.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.emoji, required this.label});

  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.75),
        borderRadius: AppRadius.chip,
        border: Border.all(color: AppColors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-step passwordless email flow: enter email → enter the 6-digit code.
class _EmailOtpForm extends StatefulWidget {
  const _EmailOtpForm({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_EmailOtpForm> createState() => _EmailOtpFormState();
}

class _EmailOtpFormState extends State<_EmailOtpForm> {
  final _emailKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendEmailOtp(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _loading = false;
      });
      _startResendCountdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().verifyEmailOtp(
            email: _email.text.trim(),
            code: code,
          );
      // AuthWrapper reacts to the auth state change from here; nothing else to do.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _editEmail() {
    setState(() {
      _codeSent = false;
      _code.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                iconSize: 16,
                bordered: true,
                onTap: _codeSent ? _editEmail : widget.onBack,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _codeSent ? 'Enter your code' : 'Sign in',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to ${_email.text.trim()}. It expires in 10 minutes.'
                  : "Enter your email and we'll send you a one-time sign-in code.",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppColors.grey500),
            ),
            const SizedBox(height: 34),
            if (!_codeSent)
              Form(
                key: _emailKey,
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  onFieldSubmitted: (_) => _sendCode(),
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!AuthService.looksLikeEmail(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
              )
            else
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                maxLength: 6,
                onFieldSubmitted: (_) => _verifyCode(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(letterSpacing: 10),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.pastelPink,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 17, color: AppColors.danger),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            PillButton(
              label: _codeSent ? 'Verify & continue' : 'Send code',
              loading: _loading,
              onPressed: _loading ? null : (_codeSent ? _verifyCode : _sendCode),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _resendIn > 0 || _loading ? null : _sendCode,
                  child: Text(
                    _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : _editEmail,
                  child: const Text('Use a different email'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
