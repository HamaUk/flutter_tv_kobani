import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Login/login.dart';
import 'Home/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (using google-services.json)
  await Firebase.initializeApp();

  // Enforce Landscape for TV
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString("auth_code");
    
    if (code != null && code.isNotEmpty) {
      ref.read(authCodeProvider.notifier).state = code;
      ref.read(authStateProvider.notifier).state = true;
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'KOBANI 4K',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF17262A), // Dark from templates
        scaffoldBackgroundColor: const Color(0xFF17262A),
        fontFamily: 'WorkSans',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)))
          : (isLoggedIn ? const Home() : const Login()),
    );
  }
}
