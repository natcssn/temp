import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for EZFOODZ.
/// Generated from the provided Firebase project config.
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
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4HKcVKSxIsbFU6C3H926pCRhEaAmrCFo',
    appId: '1:527895736417:web:c5aepkvojae8isvdvs14tlbb9a4o6fjc',
    messagingSenderId: '527895736417',
    projectId: 'business-2c38a',
    authDomain: 'business-2c38a.firebaseapp.com',
    storageBucket: 'business-2c38a.firebasestorage.app',
  );

  // NOTE: For Android, you need to download google-services.json from Firebase Console
  // and place it at android/app/google-services.json.
  // Then update the values below OR use FlutterFire CLI: `flutterfire configure`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC4HKcVKSxIsbFU6C3H926pCRhEaAmrCFo',
    appId: '1:527895736417:android:e92b6055ebe87716943a20',
    messagingSenderId: '527895736417',
    projectId: 'business-2c38a',
    storageBucket: 'business-2c38a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAom58-XFC4yvjYiaIiPYpoilRVgB5E29g',
    appId: '1:164107786597:web:8b72a1cff9328982d4e98c',
    messagingSenderId: '164107786597',
    projectId: 'temp-bfe41',
    storageBucket: 'temp-bfe41.firebasestorage.app',
    iosBundleId: 'com.example.ezfoodz',
  );
}
