import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    // Native flow: talks to Google Play Services directly, no browser
    // Custom Tab involved, so the sessionStorage/redirect error page
    // can't occur.
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

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

    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      await user.reauthenticateWithPopup(provider);
      return;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Re-authentication was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
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