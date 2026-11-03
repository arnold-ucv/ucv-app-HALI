import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'HALI solo está configurado para web, Android e iOS',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBWtkGm52b7RksoVbGsmo6aHKPfVQ6q9HE',
    appId: '1:862203912888:web:2d7b1981cf6e656c938a4d',
    messagingSenderId: '862203912888',
    projectId: 'hali-gestion-ucv-2026',
    authDomain: 'hali-gestion-ucv-2026.firebaseapp.com',
    storageBucket: 'hali-gestion-ucv-2026.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD2DLCzJ0JVHkdtamKpwH5V_gLVHRSrd-k',
    appId: '1:862203912888:android:bc4c71c73b23296b938a4d',
    messagingSenderId: '862203912888',
    projectId: 'hali-gestion-ucv-2026',
    storageBucket: 'hali-gestion-ucv-2026.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDIsVrUbn2b7WjXGXcZS25VBpU8_ymKBSw',
    appId: '1:862203912888:ios:924b582defa58196938a4d',
    messagingSenderId: '862203912888',
    projectId: 'hali-gestion-ucv-2026',
    storageBucket: 'hali-gestion-ucv-2026.firebasestorage.app',
    iosBundleId: 'pe.hali.gestion',
  );
}
