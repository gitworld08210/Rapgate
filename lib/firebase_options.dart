// Firebase project: parallaxai-7653c
//
// For production Android builds, run `flutterfire configure` to get the
// Android-specific API key. The web key below works for dev/testing.

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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDwzGTDJMUVHfECuht2fSK1Zm9KhNGvNIQ',
    appId: '1:437781580933:web:8bc1262e33e47ccc5fadec',
    messagingSenderId: '437781580933',
    projectId: 'parallaxai-7653c',
    storageBucket: 'parallaxai-7653c.firebasestorage.app',
    databaseURL: 'https://parallaxai-7653c-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwzGTDJMUVHfECuht2fSK1Zm9KhNGvNIQ',
    appId: '1:437781580933:web:8bc1262e33e47ccc5fadec',
    messagingSenderId: '437781580933',
    projectId: 'parallaxai-7653c',
    storageBucket: 'parallaxai-7653c.firebasestorage.app',
    databaseURL: 'https://parallaxai-7653c-default-rtdb.asia-southeast1.firebasedatabase.app',
    iosBundleId: 'com.healthpush.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDwzGTDJMUVHfECuht2fSK1Zm9KhNGvNIQ',
    appId: '1:437781580933:web:8bc1262e33e47ccc5fadec',
    messagingSenderId: '437781580933',
    projectId: 'parallaxai-7653c',
    storageBucket: 'parallaxai-7653c.firebasestorage.app',
    authDomain: 'parallaxai-7653c.firebaseapp.com',
    databaseURL: 'https://parallaxai-7653c-default-rtdb.asia-southeast1.firebasedatabase.app',
    measurementId: 'G-WEX4GRMJB2',
  );
}
