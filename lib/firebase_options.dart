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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only supported for web and Android.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCfqu-bG0uVsvFAxBKrCep5XdFex-l4VjQ',
    appId: '1:411380309891:web:d52398e24cb0827ccee0b6',
    messagingSenderId: '411380309891',
    projectId: 'mygana-7b3c4',
    authDomain: 'mygana-7b3c4.firebaseapp.com',
    databaseURL: 'https://mygana-7b3c4-default-rtdb.firebaseio.com',
    storageBucket: 'mygana-7b3c4.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCfqu-bG0uVsvFAxBKrCep5XdFex-l4VjQ',
    appId: '1:411380309891:android:d52398e24cb0827ccee0b6',
    messagingSenderId: '411380309891',
    projectId: 'mygana-7b3c4',
    databaseURL: 'https://mygana-7b3c4-default-rtdb.firebaseio.com',
    storageBucket: 'mygana-7b3c4.firebasestorage.app',
  );
}