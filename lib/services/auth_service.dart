import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Google authentication via firebase_auth only — no google_sign_in plugin
/// needed, which keeps the dependency surface small and web-friendly.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      // Web: redirect flow — works reliably in Safari, unlike popups,
      // which get blocked by Safari's tracking prevention / storage rules.
      // This navigates the browser away; the signed-in user is picked up
      // later via authStateChanges once the app reloads after redirect.
      return _auth.signInWithRedirect(provider);
    }
    // Android / iOS native app: native browser flow, unaffected by this.
    return _auth.signInWithProvider(provider);
  }

  /// Email/password sign-in — used on Windows/desktop, where Firebase's
  /// C++ SDK does not support Google Sign-In (signInWithProvider throws
  /// "Operation is not supported on non-mobile systems").
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new account with email/password — used the first time a
  /// desktop user signs in, since there's no Google flow to fall back on.
  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}