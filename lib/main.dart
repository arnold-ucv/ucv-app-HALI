import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/app.dart';

const useFirebase = bool.fromEnvironment('FIREBASE_ENABLED');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const HaliApp());
}
