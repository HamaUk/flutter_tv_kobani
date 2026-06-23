import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Login/login.dart';
import 'Home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase
  await Firebase.initializeApp();

  // Enforce landscape for TV – no portrait mode ever
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full-screen immersive: hides status bar & nav bar permanently
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    const ProviderScope(
      child: KobaniTvApp(),
    ),
  );
}

// ─── Global Providers ────────────────────────────────────────────────────────

final authStateProvider = StateProvider<bool>((ref) => false);
final authCodeProvider  = StateProvider<String?>((ref) => null);

// ─── App Root ────────────────────────────────────────────────────────────────

class KobaniTvApp extends ConsumerStatefulWidget {
  const KobaniTvApp({super.key});

  @override
  ConsumerState<KobaniTvApp> createState() => _KobaniTvAppState();
}

class _KobaniTvAppState extends ConsumerState<KobaniTvApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so the ProviderScope is fully mounted
    // before we touch any ref.read() calls.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString('auth_code');

    if (code != null && code.isNotEmpty) {
      ref.read(authCodeProvider.notifier).state  = code;
      ref.read(authStateProvider.notifier).state = true;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'KOBANI 4K',
      debugShowCheckedModeBanner: false,

      // TV-optimised focus traversal: directional (arrow keys) not
      // the default reading-order traversal which jumps unpredictably.
      builder: (context, child) {
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: child!,
        );
      },

      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF17262A),
        scaffoldBackgroundColor: const Color(0xFF17262A),
        fontFamily: 'Rabar_015',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
        // Disable the default blue focus highlight – we draw our own
        focusColor: Colors.transparent,
      ),

      home: _isLoading
          ? const _SplashScreen()
          : (isLoggedIn ? const Home() : const Login()),
    );
  }
}

// ─── Splash / Loading Screen ─────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF17262A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KOBANI 4K',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.amber),
          ],
        ),
      ),
    );
  }
}
