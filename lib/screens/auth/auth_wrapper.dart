import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
import '../../utils/app_theme.dart';
import '../profile/onboarding_screen.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in — check if profile is complete
          final userProvider = Provider.of<UserProvider>(context);
          final healthProvider =
              Provider.of<HealthProvider>(context, listen: false);

          // Initialize health data streams
          healthProvider.initializeForUser(snapshot.data!.id);

          if (userProvider.isLoading) {
            return const _LoadingProfileScreen();
          }

          // Show error with retry if profile loading failed
          if (userProvider.error != null && !userProvider.isProfileComplete) {
            return _ProfileErrorScreen(
              error: userProvider.error!,
              onRetry: () {
                userProvider.updateAuth(authService);
              },
              onSignOut: () async {
                await authService.signOut();
              },
            );
          }

          if (!userProvider.isProfileComplete) {
            return const OnboardingScreen();
          }

          return const HomeScreen();
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}

/// Loading screen with timeout message
class _LoadingProfileScreen extends StatefulWidget {
  const _LoadingProfileScreen();

  @override
  State<_LoadingProfileScreen> createState() => _LoadingProfileScreenState();
}

class _LoadingProfileScreenState extends State<_LoadingProfileScreen> {
  bool _showSlowMessage = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showSlowMessage = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading your profile...'),
            if (_showSlowMessage) ...[
              const SizedBox(height: 12),
              Text(
                'This is taking longer than usual.\nCheck your internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  final authService = context.read<AuthService>();
                  final userProvider = context.read<UserProvider>();
                  userProvider.updateAuth(authService);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error screen with retry and sign-out options
class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  final String error;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    // Detect session expiry errors
    final isSessionError = error.contains('session') ||
        error.contains('JWT') ||
        error.contains('401') ||
        error.contains('expired');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSessionError
                    ? Icons.lock_clock_rounded
                    : Icons.cloud_off_rounded,
                size: 64,
                color: AppColors.grey300,
              ),
              const SizedBox(height: 24),
              Text(
                isSessionError
                    ? 'Your session has expired'
                    : 'Could not load profile',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isSessionError
                    ? 'Please sign in again to continue.'
                    : 'Check your internet connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.grey500,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!isSessionError)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(isSessionError ? 'Sign in again' : 'Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
