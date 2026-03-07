import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    BootstrapApp(
      initializeFirebase: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
    ),
  );
}

class BootstrapApp extends StatelessWidget {
  const BootstrapApp({super.key, required this.initializeFirebase});

  final Future<FirebaseApp> initializeFirebase;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: initializeFirebase,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasError) {
          final message =
              'Firebase init error. Run flutterfire configure for this project.\n\n${snapshot.error}';
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              ),
            ),
          );
        }

        return const DaycareBackofficeApp();
      },
    );
  }
}
