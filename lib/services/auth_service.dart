import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class AuthService {
  const AuthService();

  Stream<User?> authStateChanges() => FirebaseAuth.instance.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  Future<String> createParentAuthUser({
    required String email,
    required String password,
  }) async {
    final tempApp = await Firebase.initializeApp(
      name: 'parent-create-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await tempAuth.signOut();
      return credential.user?.uid ?? '';
    } finally {
      await tempApp.delete();
    }
  }
}
