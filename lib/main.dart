import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/pushup_service.dart';
import 'services/food_service.dart';
import 'services/fine_service.dart';
import 'services/notification_service.dart';
import 'services/platform_channel_service.dart';
import 'providers/user_provider.dart';
import 'providers/health_provider.dart';
import 'screens/auth/auth_wrapper.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Initialize notifications
  await NotificationService.instance.initialize();

  runApp(const HealthPushApp());
}

class HealthPushApp extends StatelessWidget {
  const HealthPushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<PushupService>(create: (_) => PushupService()),
        Provider<FoodService>(create: (_) => FoodService()),
        Provider<FineService>(create: (_) => FineService()),
        Provider<PlatformChannelService>(
            create: (_) => PlatformChannelService()),

        // State providers
        ChangeNotifierProxyProvider<AuthService, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, userProvider) =>
              userProvider!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<FirestoreService, HealthProvider>(
          create: (_) => HealthProvider(),
          update: (_, firestore, healthProvider) =>
              healthProvider!..updateFirestore(firestore),
        ),
      ],
      child: MaterialApp(
        title: 'HealthPush',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}
