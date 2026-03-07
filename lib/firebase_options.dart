import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform. '
      'Run flutterfire configure --project=liisgo-daycare-system --platforms=web',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDflrgJxoYh_zJfy1kFCKACOcZi8QNHxXI',
    appId: '1:1042137244295:web:75218e1756ea3f975fce22',
    messagingSenderId: '1042137244295',
    projectId: 'liisgo-daycare-system',
    authDomain: 'liisgo-daycare-system.firebaseapp.com',
    storageBucket: 'liisgo-daycare-system.firebasestorage.app',
    measurementId: 'G-8TMZJ6Z6FE',
  );

  // Replace values by running FlutterFire CLI for this repo.
}