import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/supabase_client.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/pushup_service.dart';
import 'services/food_service.dart';
import 'services/health_coach_service.dart';
import 'services/fine_service.dart';
import 'services/app_settings_service.dart';
import 'services/notification_service.dart';
import 'services/platform_channel_service.dart';
import 'providers/user_provider.dart';
import 'providers/health_provider.dart';
import 'screens/auth/auth_wrapper.dart';
import 'utils/app_theme.dart';

/// Startup is deliberately kept to the minimum needed to render the first
/// frame. Anything that isn't required to paint the UI is deferred until after
/// the app is interactive, so the user sees content immediately instead of
/// staring at a blank screen.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase must be ready before any provider touches Auth/Postgres.
  await initializeSupabase();

  runApp(const RepGateApp());

  // Deferred: notification setup requests permissions, creates channels and
  // fetches an FCM token. None of that is needed to draw the UI, and awaiting
  // it before runApp() delayed the first frame by hundreds of milliseconds.
  // Scheduled after the first frame so it never competes with initial layout.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.instance.initialize();
  });
}

class RepGateApp extends StatelessWidget {
  const RepGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Stateless services. `lazy: true` (the default for Provider) means
        // each is constructed on first use rather than all at startup —
        // notably PushupService, which allocates an ML Kit PoseDetector.
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<FoodService>(create: (_) => FoodService()),
        Provider<HealthCoachService>(create: (_) => HealthCoachService()),
        Provider<FineService>(create: (_) => FineService()),
        Provider<AppSettingsService>(create: (_) => AppSettingsService()),
        Provider<PlatformChannelService>(
          create: (_) => PlatformChannelService(),
        ),

        // Holds a native PoseDetector; only build it when a session starts.
        Provider<PushupService>(
          create: (_) => PushupService(),
          dispose: (_, service) => service.dispose(),
        ),

        // State providers
        ChangeNotifierProxyProvider<AuthService, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, userProvider) => userProvider!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<DatabaseService, HealthProvider>(
          create: (_) => HealthProvider(),
          update: (_, firestore, healthProvider) =>
              healthProvider!..updateFirestore(firestore),
        ),
      ],
      child: MaterialApp(
        title: 'RepGate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}
