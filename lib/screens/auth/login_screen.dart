import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/pill_button.dart';
import 'phone_auth_screen.dart';

/// Welcome / auth screen styled after the reference hero onboarding:
/// large soft-green hero, bold headline, black pill CTA.
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
          ? _EmailAuthForm(onBack: () => setState(() => _showForm = false))
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
        Positioned(
          top: 70,
          right: -30,
          child: Opacity(
            opacity: 0.9,
            child: Text('🥑', style: TextStyle(fontSize: 130)),
          ),
        ),
        Positioned(
          top: 210,
          left: -20,
          child: Opacity(
            opacity: 0.85,
            child: Text('🥦', style: TextStyle(fontSize: 100)),
          ),
        ),
        Positioned(
          top: 130,
          left: 130,
          child: Opacity(
            opacity: 0.95,
            child: Text('💪', style: TextStyle(fontSize: 86)),
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
                    _FeatureChip(emoji: '🔒', label: 'App lock'),
                    _FeatureChip(emoji: '💧', label: 'Hydration'),
                    _FeatureChip(emoji: '📈', label: 'Progress'),
                  ],
                ),

                const Spacer(flex: 2),

                // ---------- CTAs ----------
                PillButton(
                  label: 'Get Started',
                  icon: Icons.bolt_rounded,
                  onPressed: () => setState(() => _showForm = true),
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Continue with Phone',
                  icon: Icons.phone_rounded,
                  variant: PillVariant.outline,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showForm = true),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: const [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Login',
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

/// Email sign-in / sign-up form.
class _EmailAuthForm extends StatefulWidget {
  const _EmailAuthForm({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<_EmailAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isLogin = true;
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
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      if (_isLogin) {
        await auth.signInWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.registerWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // AuthWrapper reacts to the auth state change from here.
    } catch (e) {
      if (mounted) {
        final message = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Something went wrong';
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    try {
      await context.read<AuthService>().sendPasswordResetEmail(
            _email.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : 'Something went wrong';
      setState(() => _error = message);
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

            Text(
              _isLogin ? 'Welcome back' : 'Create account',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin
                  ? 'Sign in to pick up where you left off.'
                  : 'Start tracking and earning your screen time.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.grey500,
                  ),
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
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.grey500,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (!_isLogin && v.length < 6) {
                        return 'Use at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            if (_isLogin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
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
              label: _isLogin ? 'Sign In' : 'Create Account',
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),

            const SizedBox(height: 14),

            Center(
              child: GestureDetector(
                onTap: () => setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                }),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: _isLogin
                            ? "Don't have an account? "
                            : 'Already have an account? ',
                      ),
                      TextSpan(
                        text: _isLogin ? 'Sign Up' : 'Sign In',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('OR',
                      style: Theme.of(context).textTheme.labelSmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 20),

            PillButton(
              label: 'Continue with Phone',
              icon: Icons.phone_rounded,
              variant: PillVariant.outline,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
