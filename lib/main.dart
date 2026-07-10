import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'screens/home.dart';
import 'screens/sign_in.dart';

/// -----------------------------------------------------------------------
/// THE BLANK-SCREEN FIX, in one sentence:
/// runApp() is called IMMEDIATELY — all async initialization happens
/// inside the widget tree, where loading and failure states are VISIBLE.
/// (v1 awaited the database before runApp(); when that future threw on
/// web/Windows, no frame was ever rendered → blank white screen.)
/// -----------------------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VaultApp()));
}

/// Firebase init as a provider: loading → spinner, error → readable screen.
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
      title: 'Notes Case',
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
    );
  }
}
/// Shows the splash screen first, then hands off to the real bootstrap flow.
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
/// Step 1: initialize Firebase with visible states.
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

/// Step 2: route on auth state — sign-in screen or the app.
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

/// -----------------------------------------------------------------------
/// Shared splash / error widgets — the app can never render "nothing".
/// -----------------------------------------------------------------------

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
            Icon(Icons.shield_rounded, size: 42, color: cs.primary),
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
