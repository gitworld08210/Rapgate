import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';

/// Welcome / auth screen.
///
/// - **Login**: email + password (no OTP).
/// - **Sign up**: email + password + name, then a one-time email code to
///   verify the address before the account is created.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { hero, login, signup }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.hero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_mode) {
        _Mode.hero => _buildHero(),
        _Mode.login => _LoginForm(
            onBack: () => setState(() => _mode = _Mode.hero),
            onGoSignup: () => setState(() => _mode = _Mode.signup),
          ),
        _Mode.signup => _SignupForm(
            onBack: () => setState(() => _mode = _Mode.hero),
            onGoLogin: () => setState(() => _mode = _Mode.login),
          ),
      },
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
                  label: 'Get Started',
                  icon: Icons.bolt_rounded,
                  onPressed: () => setState(() => _mode = _Mode.signup),
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = _Mode.login),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: const [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Shared error banner.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.pastelPink,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 17, color: AppColors.danger),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== LOGIN (email + password) ====================

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.onBack, required this.onGoSignup});
  final VoidCallback onBack;
  final VoidCallback onGoSignup;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().login(
            email: _email.text.trim(),
            password: _password.text,
          );
      // AuthWrapper reacts to the auth state change.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _forgot() async {
    if (!AuthService.looksLikeEmail(_email.text)) {
      setState(() => _error = 'Enter your email first, then tap reset.');
      return;
    }
    try {
      await context.read<AuthService>().sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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
                onTap: widget.onBack,
              ),
            ),
            const SizedBox(height: 32),
            Text('Welcome back', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text(
              'Log in with your email and password.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.grey500),
            ),
            const SizedBox(height: 34),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.grey500,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password is required' : null,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
            ),
            if (_error != null) _ErrorBanner(_error!),
            const SizedBox(height: 20),
            PillButton(
              label: 'Log In',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: widget.onGoSignup,
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    children: const [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign up',
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SIGNUP (details → email OTP) ====================

class _SignupForm extends StatefulWidget {
  const _SignupForm({required this.onBack, required this.onGoLogin});
  final VoidCallback onBack;
  final VoidCallback onGoLogin;

  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  final _detailsKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
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
    if (!(_detailsKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendSignupOtp(_email.text.trim());
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

  Future<void> _verifyAndCreate() async {
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
      await context.read<AuthService>().verifySignupOtp(
            email: _email.text.trim(),
            code: code,
            password: _password.text,
            name: _name.text.trim(),
          );
      // AuthWrapper reacts to the auth state change (signed in on success).
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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
                onTap: _codeSent
                    ? () => setState(() {
                          _codeSent = false;
                          _code.clear();
                          _error = null;
                        })
                    : widget.onBack,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _codeSent ? 'Confirm your email' : 'Create account',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to ${_email.text.trim()}. Enter it to finish signing up. It expires in 10 minutes.'
                  : 'Start tracking and earning your screen time.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.grey500),
            ),
            const SizedBox(height: 34),
            if (!_codeSent)
              Form(
                key: _detailsKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Your name',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _sendCode(),
                      decoration: InputDecoration(
                        hintText: 'Password (min 6 characters)',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: AppColors.grey500,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Use at least 6 characters';
                        return null;
                      },
                    ),
                  ],
                ),
              )
            else
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofocus: true,
                maxLength: 6,
                onFieldSubmitted: (_) => _verifyAndCreate(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(letterSpacing: 10),
                ),
              ),
            if (_error != null) _ErrorBanner(_error!),
            const SizedBox(height: 22),
            PillButton(
              label: _codeSent ? 'Verify & create account' : 'Continue',
              loading: _loading,
              onPressed: _loading ? null : (_codeSent ? _verifyAndCreate : _sendCode),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _resendIn > 0 || _loading ? null : _sendCode,
                  child: Text(_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: widget.onGoLogin,
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: const [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log in',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
