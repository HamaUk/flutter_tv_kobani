import 'package:dpad/dpad.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Login/login.dart';
import 'Home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // TV-Optimized Settings
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(
    const ProviderScope(
      child: KobaniTvApp(),
    ),
  );
}

// Global Providers
final authStateProvider = StateProvider<bool>((ref) => false);
final authCodeProvider = StateProvider<String?>((ref) => null);

class KobaniTvApp extends ConsumerStatefulWidget {
  const KobaniTvApp({super.key});

  @override
  ConsumerState<KobaniTvApp> createState() => _KobaniTvAppState();
}

class _KobaniTvAppState extends ConsumerState<KobaniTvApp> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString("auth_code");

      if (code != null && code.isNotEmpty) {
        ref.read(authCodeProvider.notifier).state = code;
        ref.read(authStateProvider.notifier).state = true;
      }
    } catch (e) {
      debugPrint('Session check failed: $e');
      _errorMessage = 'Failed to load session';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider);

    return Dpad.wrap(
      debugOverlay: false, // Set to `true` only when debugging focus issues
      onBack: () {
        // Global back button fallback
        return false; // Let WillPopScope and Navigator handle it
      },
      child: MaterialApp(
        title: 'KOBANI 4K',
        debugShowCheckedModeBanner: false,
        
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF17262A),
          scaffoldBackgroundColor: const Color(0xFF17262A),
          fontFamily: 'Rabar_015',
          
          // TV-Friendly Theme Improvements
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
            titleLarge: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          
          // Better focus & selection colors for TV
          focusColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.3),
          splashColor: Colors.transparent,
        ),
        
        home: _isLoading
            ? const SplashScreen()
            : _errorMessage != null
                ? _buildErrorScreen()
                : (isLoggedIn ? const Home() : const Login()),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: const TextStyle(fontSize: 18, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _isLoading = true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple Splash Screen
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF17262A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 24),
            Text(
              'Loading KOBANI 4K...',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
