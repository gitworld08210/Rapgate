import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/health_provider.dart';
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
          healthProvider.initializeForUser(snapshot.data!.uid);

          if (userProvider.isLoading) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading your profile...'),
                  ],
                ),
              ),
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
