// Firebase project: parallaxai-7653c
//
// Android values below come from the real google-services.json downloaded
// after registering the Android app (package com.healthpush.app) in the
// Firebase Console. iOS/web still use placeholder/web values — run
// `flutterfire configure` if iOS support is needed later.

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
    apiKey: 'AIzaSyD6sf7SZd8PS13ekJZPUFLgRN4GsH7VDbU',
    appId: '1:437781580933:android:a8546d73e46b7b9a5fadec',
    messagingSenderId: '437781580933',
    projectId: 'parallaxai-7653c',
    storageBucket: 'parallaxai-7653c.firebasestorage.app',
    databaseURL:
        'https://parallaxai-7653c-default-rtdb.asia-southeast1.firebasedatabase.app',
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
