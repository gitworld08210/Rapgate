// Generated from your Firebase Console config.
//
// For production Android builds, run `flutterfire configure` to generate
// the platform-specific API keys. The web apiKey below works for initial
// development but the Android key will differ after proper configuration.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android — after running `flutterfire configure`, the apiKey here will be
  // replaced with your Android-specific key. Until then, the web key works
  // for Auth/Firestore/Functions in debug mode.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCDFm516Yy7E82He3xaZp5jYtIUJLkiPtI',
    appId: '1:611057820540:web:7d0462c6bd7628a679baf9',
    messagingSenderId: '611057820540',
    projectId: 'social-claud',
    storageBucket: 'social-claud.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCDFm516Yy7E82He3xaZp5jYtIUJLkiPtI',
    appId: '1:611057820540:web:7d0462c6bd7628a679baf9',
    messagingSenderId: '611057820540',
    projectId: 'social-claud',
    storageBucket: 'social-claud.firebasestorage.app',
    iosBundleId: 'com.healthpush.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCDFm516Yy7E82He3xaZp5jYtIUJLkiPtI',
    appId: '1:611057820540:web:7d0462c6bd7628a679baf9',
    messagingSenderId: '611057820540',
    projectId: 'social-claud',
    storageBucket: 'social-claud.firebasestorage.app',
    authDomain: 'social-claud.firebaseapp.com',
    measurementId: 'G-8LJJMQ1DJ5',
  );
}
