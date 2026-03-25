import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'core/hive_helper.dart';
import 'providers/app_state_provider.dart';
import 'ui/onboarding_screen.dart';
import 'ui/home_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await HiveHelper.instance.init();

  // Initialize offline map tile caching
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapStore').manage.create();

  runApp(
    const ProviderScope(
      child: OffTalkApp(),
    ),
  );
}

class OffTalkApp extends ConsumerWidget {
  const OffTalkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'OffTalk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A884),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A884),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: switch (authState) {
        AuthState.authenticated => const HomeScreen(),
        AuthState.locked => const LoginScreen(),
        AuthState.unauthenticated => const OnboardingScreen(),
        AuthState.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      },
    );
  }
}
