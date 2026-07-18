import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }
    return _auth.signInWithProvider(provider);
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Firebase requires a *recent* sign-in before it will allow deleting an
  /// account (throws FirebaseAuthException: requires-recent-login
  /// otherwise). Google session tokens go stale quickly, so this always
  /// re-prompts rather than trying to detect staleness.
  ///
  /// [password] is required when the signed-in user authenticated via the
  /// desktop email/password path (see sign_in.dart's _isDesktop branch);
  /// leave it null for the Google-authenticated mobile/web path.
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');

    if (password != null) {
      final email = user.email;
      if (email == null) {
        throw StateError('This account has no email to re-authenticate with.');
      }
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
      return;
    }

    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await user.reauthenticateWithPopup(provider);
    } else {
      await user.reauthenticateWithProvider(provider);
    }
  }

  /// Deletes the Firebase Authentication record itself. Call
  /// reauthenticate() immediately before this, and delete the user's
  /// Firestore data (NoteRepository.deleteAllNotes) before calling this,
  /// since the security rules require an authenticated uid to delete
  /// under users/{uid}/notes.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    await user.delete();
  }
}