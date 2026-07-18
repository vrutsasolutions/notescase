import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers.dart';
import 'privacy_policy_screen.dart';

const String _consentKey = 'accepted_privacy_v1';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;

  // Consent gate — applies to BOTH the Google path and the desktop
  // email/password path below, since either one creates an account.
  bool _accepted = false;
  bool _consentLoaded = false;

  // Google Sign-In only works on Android/iOS/web via Firebase — the C++
  // SDK used on desktop platforms doesn't support it.
  bool get _isDesktop =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _restoreConsent();
  }

  Future<void> _restoreConsent() async {
    bool accepted = false;
    try {
      // Timeout guards against platforms (seen on Windows when the plugin
      // isn't fully registered with the native runner) where the
      // SharedPreferences platform channel call hangs indefinitely instead
      // of throwing — without this, _consentLoaded would never flip to
      // true and the checkbox would stay invisible forever.
      final p = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      accepted = p.getBool(_consentKey) ?? false;
    } catch (_) {
      // Couldn't read/write persisted consent on this platform — fail
      // safe by defaulting to NOT accepted, and still show the checkbox
      // so the user isn't blocked from ever seeing or ticking it. Consent
      // just won't be remembered across restarts on a platform where this
      // is failing.
      accepted = false;
    }
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _consentLoaded = true;
    });
  }

  Future<void> _setConsent(bool value) async {
    setState(() => _accepted = value);
    try {
      final p = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await p.setBool(_consentKey, value);
    } catch (_) {
      // Persisting failed on this platform — the checkbox state for THIS
      // session is still correct (already applied via setState above), it
      // just won't survive an app restart. Not worth blocking sign-in over.
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (!_accepted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // AuthGate reacts to the auth stream — no navigation needed.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithEmail() async {
    if (!_accepted || _busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(authServiceProvider);
      if (_isRegistering) {
        await service.registerWithEmail(email, password);
      } else {
        await service.signInWithEmail(email, password);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 16),
                Text('NotesCase',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Notes, passwords and small facts — synced privately to your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                if (_consentLoaded)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _busy ? null : () => _setConsent(!_accepted),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _accepted,
                            onChanged:
                                _busy ? null : (v) => _setConsent(v ?? false),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  children: [
                                    const TextSpan(
                                        text: 'I have read and agree to the '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () =>
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const PrivacyPolicyScreen(),
                                              ),
                                            ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                if (!_isDesktop) ...[
                  // Android / iOS / web: Google Sign-In.
                  FilledButton.icon(
                    onPressed: (_accepted && !_busy) ? _signInWithGoogle : null,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                        _busy ? 'Signing in…' : 'Continue with Google'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ] else ...[
                  // Windows / desktop: email + password, since Google
                  // Sign-In isn't supported by the C++ Firebase SDK.
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: (_accepted && !_busy) ? _signInWithEmail : null,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_busy
                        ? 'Please wait…'
                        : (_isRegistering ? 'Create account' : 'Sign in')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _isRegistering = !_isRegistering),
                    child: Text(_isRegistering
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account'),
                  ),
                ],

                if (!_accepted && _consentLoaded) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Please accept the Privacy Policy to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: cs.outline),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!,
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onErrorContainer)),
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