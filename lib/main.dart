import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/guards/session_guard.dart';
import 'package:tugas_uas/pages/detail_page.dart';
import 'package:tugas_uas/pages/home_page.dart';
import 'package:tugas_uas/pages/login_page.dart';
import 'package:tugas_uas/pages/profile_form_page.dart';
import 'package:tugas_uas/pages/register_page.dart';
import 'package:tugas_uas/pages/splash_page.dart';
import 'package:tugas_uas/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://pkdoslagpkuxbstpuvil.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrZG9zbGFncGt1eGJzdHB1dmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYxNDc0NDgsImV4cCI6MjA2MTcyMzQ0OH0.4pZTEO6DM_CD8-7bap2VEgS5dVRpnxPsgn3gdq2rZYQ',
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  void _onThemeChanged(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('theme_mode');
      setState(() {
        if (mode == 'ThemeMode.dark') {
          _themeMode = ThemeMode.dark;
        } else if (mode == 'ThemeMode.light') {
          _themeMode = ThemeMode.light;
        } else {
          _themeMode = ThemeMode.system;
        }
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _themeMode = ThemeMode.system;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Harian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashPage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home':
            (_) =>
                SessionGuard(child: HomePage(onThemeChanged: _onThemeChanged)),
        '/detail': (_) => const SessionGuard(child: DetailPage()),
        '/settings':
            (_) => SessionGuard(
              child: SettingsPage(onThemeChanged: _onThemeChanged),
            ),
        '/profile-form': (_) => const SessionGuard(child: ProfileFormPage()),
      },
    );
  }
}
