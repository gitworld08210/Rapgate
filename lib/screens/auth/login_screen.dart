import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';

/// Welcome / auth screen styled after Cal AI:
/// modern soft gradient hero, clean typography, passwordless Email OTP flow.
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
          ? _EmailOtpAuthForm(onBack: () => setState(() => _showForm = false))
          : _buildHero(),
    );
  }

  Widget _buildHero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ---------- Soft green gradient hero ----------
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.limeSoft,
                AppColors.limeWash,
                AppColors.white,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Decorative produce
        const Positioned(
          top: 70,
          right: -30,
          child: Opacity(
            opacity: 0.9,
            child: Text('🥑', style: TextStyle(fontSize: 130)),
          ),
        ),
        const Positioned(
          top: 210,
          left: -20,
          child: Opacity(
            opacity: 0.85,
            child: Text('🥦', style: TextStyle(fontSize: 100)),
          ),
        ),
        const Positioned(
          top: 130,
          left: 130,
          child: Opacity(
            opacity: 0.95,
            child: Text('🔥', style: TextStyle(fontSize: 86)),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 5),

                // ---------- Headline ----------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        'Track smarter.\nEat better.\nHit your goals.',
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
                  'Instant AI food scanning, natural language calorie tracking, '
                  'and personalized macro targets in your pocket.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.grey700,
                      ),
                ),

                const SizedBox(height: 30),

                // ---------- Feature chips ----------
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _FeatureChip(emoji: '📸', label: 'AI food scan'),
                    _FeatureChip(emoji: '💬', label: 'Describe & track'),
                    _FeatureChip(emoji: '🔥', label: 'Calorie deficit'),
                    _FeatureChip(emoji: '💧', label: 'Hydration'),
                  ],
                ),

                const Spacer(flex: 2),

                // ---------- CTAs ----------
                PillButton(
                  label: 'Get Started with Email',
                  icon: Icons.mail_outline_rounded,
                  onPressed: () => setState(() => _showForm = true),
                ),

                const SizedBox(height: 12),

                PillButton(
                  label: '⚡ Instant Guest / Demo Mode',
                  variant: PillVariant.outline,
                  onPressed: () async {
                    try {
                      await context.read<AuthService>().signInAsGuest();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Guest mode error: $e')),
                      );
                    }
                  },
                ),

                const SizedBox(height: 16),

                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showForm = true),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: const [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login with Email OTP',
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
        color: AppColors.white.withOpacity(0.75),
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

/// Email OTP authentication form (Passwordless with Resend delivery via Supabase).
class _EmailOtpAuthForm extends StatefulWidget {
  const _EmailOtpAuthForm({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_EmailOtpAuthForm> createState() => _EmailOtpAuthFormState();
}

class _EmailOtpAuthFormState extends State<_EmailOtpAuthForm> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  bool _usePassword = false;
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  int _countdown = 0;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  /// Send 6-digit OTP code to the email via Supabase Auth + Resend
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.sendEmailOTP(email: email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('6-digit code sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Verify 6-digit OTP code
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.verifyEmailOTP(
        email: _emailController.text.trim(),
        token: otp,
      );
      // AuthWrapper automatically reacts to authenticated state!
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Fallback password sign-in / registration
  Future<void> _submitPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      if (_isSignUpMode) {
        await auth.registerWithEmail(email: email, password: password);
      } else {
        await auth.signInWithEmail(email: email, password: password);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
                onTap: _otpSent ? () => setState(() => _otpSent = false) : widget.onBack,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              _otpSent
                  ? 'Enter Verification Code'
                  : (_usePassword
                      ? (_isSignUpMode ? 'Create Account' : 'Sign In with Password')
                      : 'Sign In / Register'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent
                  ? 'We sent a 6-digit code to ${_emailController.text.trim()}'
                  : (_usePassword
                      ? (_isSignUpMode
                          ? 'Enter your email & password to create an account.'
                          : 'Enter your email & password to sign in.')
                      : 'We will send a one-time verification code to your email.'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.grey500,
                  ),
            ),

            const SizedBox(height: 34),

            if (!_otpSent) ...[
              // Step 1: Email Address Input
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Enter your email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                ),
              ),

              if (_usePassword) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Step 2: 6-Digit OTP Code Input
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: const InputDecoration(
                  hintText: '• • • • • •',
                  counterText: '',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_countdown > 0)
                    Text('Resend code in ${_countdown}s',
                        style: Theme.of(context).textTheme.bodySmall)
                  else
                    TextButton.icon(
                      onPressed: _loading ? null : _sendOtp,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Resend Code'),
                    ),
                ],
              ),
            ],

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

            // Action Button
            PillButton(
              label: _otpSent
                  ? 'Verify & Continue'
                  : (_usePassword
                      ? (_isSignUpMode ? 'Create Account' : 'Sign In')
                      : 'Send Verification Code'),
              loading: _loading,
              onPressed: _loading
                  ? null
                  : (_otpSent
                      ? _verifyOtp
                      : (_usePassword ? _submitPassword : _sendOtp)),
            ),

            const SizedBox(height: 16),

            if (!_otpSent && _usePassword)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isSignUpMode = !_isSignUpMode;
                    _error = null;
                  }),
                  child: Text(
                    _isSignUpMode
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Create one",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),

            if (!_otpSent)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _usePassword = !_usePassword;
                    _error = null;
                  }),
                  child: Text(
                    _usePassword ? 'Switch to Email OTP Login' : 'Sign in with Password instead',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await context.read<AuthService>().signInAsGuest();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Guest mode error: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.bolt_rounded, color: AppColors.limeDeep, size: 20),
                label: const Text(
                  'Skip Login & Continue as Guest',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: AppColors.grey300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
