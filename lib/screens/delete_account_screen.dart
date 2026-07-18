import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// -----------------------------------------------------------------------
/// "Delete my account & data" screen.
///
/// Matches the promise made in the privacy policy: deletes every note
/// under the user's account from Firestore, then deletes the Firebase
/// Authentication record. Irreversible.
///
/// Reauthentication is platform-aware, mirroring sign_in.dart's split:
///   • Desktop (Windows/Linux/macOS): the user signed in with email +
///     password, so we ask for the password again and reauthenticate
///     with an EmailAuthProvider credential.
///   • Mobile / web: the user signed in with Google, so we reauthenticate
///     via GoogleAuthProvider (popup on web, provider flow elsewhere).
///
/// Wire it in from Settings, e.g.:
///   ListTile(
///     leading: const Icon(Icons.delete_forever_rounded),
///     title: const Text('Delete my account & data'),
///     textColor: Theme.of(context).colorScheme.error,
///     iconColor: Theme.of(context).colorScheme.error,
///     onTap: () => Navigator.of(context).push(
///       MaterialPageRoute(builder: (_) => const DeleteAccountScreen()),
///     ),
///   ),
/// -----------------------------------------------------------------------

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;
  String? _error;
  String _status = '';

  Future<void> _startDeletion() async {
    final password = await _confirmDeletion();
    if (password == false || !mounted) return; // user cancelled
    if (_isDesktop && password is! String) return; // password required, none given

    setState(() {
      _busy = true;
      _error = null;
      _status = 'Confirming your identity…';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('No signed-in user.');
      final uid = user.uid;

      await ref.read(authServiceProvider).reauthenticate(
            password: _isDesktop ? password as String : null,
          );

      setState(() => _status = 'Deleting your notes…');
      await ref.read(noteRepositoryProvider).deleteAllNotes(uid);

      setState(() => _status = 'Deleting your account…');
      await ref.read(authServiceProvider).deleteAccount();

      // AuthGate reacts to the auth state stream — no manual navigation
      // needed, same pattern as sign_in.dart.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'For your security, please try again to confirm your '
            'identity before deleting your account.';
      case 'wrong-password':
        return 'That password didn\'t match. Please try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  /// Returns `true`/`false` for the mobile/web Google path (confirm or
  /// cancel), or the typed password string for the desktop path, or
  /// `false` if cancelled.
  Future<dynamic> _confirmDeletion() async {
    final passwordController = TextEditingController();
    final typedController = TextEditingController();
    var canConfirm = false;

    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete your account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes every note in your account and '
                'your sign-in record. This cannot be undone.',
              ),
              const SizedBox(height: 16),
              if (_isDesktop) ...[
                const Text('Enter your password to confirm:'),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Password',
                  ),
                  onChanged: (v) {
                    setDialogState(() => canConfirm = v.isNotEmpty);
                  },
                ),
              ] else ...[
                Text(
                  'Type DELETE to confirm.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: typedController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'DELETE',
                  ),
                  onChanged: (v) {
                    setDialogState(() => canConfirm = v.trim() == 'DELETE');
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canConfirm
                  ? () => Navigator.of(context).pop(
                        _isDesktop ? passwordController.text : true,
                      )
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_forever_rounded, size: 48, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'This will permanently delete all your notes and your '
                  'account. This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 30),
                if (_busy) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_status, style: TextStyle(color: cs.onSurfaceVariant)),
                ] else
                  FilledButton.icon(
                    onPressed: _startDeletion,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete my account & data'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12.5, color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
