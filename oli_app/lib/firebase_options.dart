// File generated manually based on existing configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDQMF7DsuTE4-2TlkzA9ZC96fjIzYX3wpc',
    appId: '1:1045211732966:web:af7f43365f187d500b1427',
    messagingSenderId: '1045211732966',
    projectId: 'oli-core',
    authDomain: 'oli-core.firebaseapp.com',
    storageBucket: 'oli-core.firebasestorage.app',
    measurementId: 'G-C2JSC1HMDK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD94QiOmpjpjiQPoBW-5dKJxhTI-ydQwDA',
    appId: '1:1045211732966:android:56bb5bd9d0baf97e0b1427',
    messagingSenderId: '1045211732966',
    projectId: 'oli-core',
    storageBucket: 'oli-core.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQMF7DsuTE4-2TlkzA9ZC96fjIzYX3wpc', // Using web key as placeholder if iOS key is missing, usually safe for public/auth
    appId: '1:1045211732966:ios:placeholder', // Placeholder, needs actual iOS appID if needed
    messagingSenderId: '1045211732966',
    projectId: 'oli-core',
    storageBucket: 'oli-core.firebasestorage.app',
    iosBundleId: 'com.mylze.oli',
  );
}
