import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'screens/splash.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'screens/home.dart';
import 'screens/sign_in.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/delete_account_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Use clean path URLs on web (e.g. /privacy, /delete-account) instead of
  // the default hash-based URLs (e.g. /#/privacy). Required for direct,
  // reviewer-friendly links like https://notescaseapp.web.app/privacy to
  // load straight to that screen instead of falling back to home.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  runApp(const ProviderScope(child: VaultApp()));
}

final firebaseInitProvider = FutureProvider<void>((ref) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
});

const _seed = Color(0xFF2F6B57);

class VaultApp extends ConsumerWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'NotesCase',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const _AppRoot(),
      // Lets /privacy and /delete-account work as real, directly-loadable
      // URLs when this app is built for web and deployed
      // (flutter build web). On web, if the browser's initial URL matches
      // one of these, Flutter looks it up here and shows that screen
      // directly — bypassing splash/auth entirely — so each behaves like
      // a normal static page for anyone (including Play Store review)
      // visiting that link.
      //
      // In-app taps (from sign_in.dart / home.dart) still use
      // Navigator.of(context).push(MaterialPageRoute(...)) directly, which
      // works regardless of this map — this route table is what makes the
      // *direct URLs* work, not what the in-app buttons use.
      //
      // Requires:
      //   1. usePathUrlStrategy() above (so URLs have no # in them).
      //   2. A hosting rewrite so a hard refresh on these paths doesn't
      //      404 — see firebase.json note in the deployment steps.
      routes: {
        '/privacy': (context) => const PrivacyPolicyScreen(),
        '/delete-account': (context) => const DeleteAccountScreen(),
      },
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onFinished: () {
        if (mounted) setState(() => _showSplash = false);
      });
    }
    return const Bootstrap();
  }
}

class Bootstrap extends ConsumerWidget {
  const Bootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(firebaseInitProvider);

    return init.when(
      loading: () => const _Splash(message: 'Starting…'),
      error: (e, _) => _ErrorScreen(
        title: 'Firebase failed to initialize',
        details: e.toString(),
        onRetry: () => ref.invalidate(firebaseInitProvider),
      ),
      data: (_) => const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const _Splash(message: 'Checking session…'),
      error: (e, _) => _ErrorScreen(
        title: 'Authentication error',
        details: e.toString(),
        onRetry: () => ref.invalidate(authStateProvider),
      ),
      data: (user) =>
          user == null ? const SignInScreen() : const HomeScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 92,
              height: 92,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen(
      {required this.title, required this.details, required this.onRetry});

  final String title;
  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 44, color: cs.error),
                const SizedBox(height: 14),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(details,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12.5)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}