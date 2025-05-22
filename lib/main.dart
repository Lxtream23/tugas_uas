import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/guards/session_guard.dart';
import 'package:tugas_uas/pages/diary/detail_page.dart';
import 'package:tugas_uas/pages/home/home_page.dart';
import 'package:tugas_uas/pages/auth/login_page.dart';
import 'package:tugas_uas/pages/profile/profile_form_page.dart';
import 'package:tugas_uas/pages/auth/register_page.dart';
import 'package:tugas_uas/splash/splash_page.dart';
import 'package:tugas_uas/pages/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tugas_uas/services/notification_service.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://pkdoslagpkuxbstpuvil.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrZG9zbGFncGt1eGJzdHB1dmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYxNDc0NDgsImV4cCI6MjA2MTcyMzQ0OH0.4pZTEO6DM_CD8-7bap2VEgS5dVRpnxPsgn3gdq2rZYQ',
  );
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('notif_harian') ?? false) {
    final hour = prefs.getInt('notif_hour') ?? 20;
    final minute = prefs.getInt('notif_minute') ?? 0;
    await NotificationService.scheduleDailyReminder(hour: hour, minute: minute);
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(
    ThemeMode.system,
  );
  final ValueNotifier<Color> _accentColorNotifier = ValueNotifier(Colors.blue);
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadAccentColor();
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

  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('primary_color');
    if (colorValue != null) {
      setState(() {
        _primaryColor = Color(colorValue);
      });
    }
  }

  void _onAccentColorChanged(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color', color.value);
    _accentColorNotifier.value = color;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: _accentColorNotifier,
          builder: (context, color, _) {
            return MaterialApp(
              title: 'Catatan Harian',
              debugShowCheckedModeBanner: false,
              // theme: ThemeData.light(),
              // darkTheme: ThemeData.dark(),
              themeMode: _themeMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: color),
                useMaterial3: true,
              ),
              darkTheme: ThemeData.dark().copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),

              initialRoute: '/',
              routes: {
                '/': (_) => const SplashPage(),
                '/login': (_) => const LoginPage(),
                '/register': (_) => const RegisterPage(),
                '/home':
                    (_) => SessionGuard(
                      child: HomePage(onThemeChanged: _onThemeChanged),
                    ),
                '/detail': (_) => const SessionGuard(child: DetailPage()),
                '/settings':
                    (_) => SessionGuard(
                      child: SettingsPage(
                        onThemeChanged: _onThemeChanged,
                        onAccentColorChanged: _onAccentColorChanged,
                      ),
                    ),
                '/profile-form':
                    (_) => const SessionGuard(child: ProfileFormPage()),
              },
            );
          },
        );
      },
    );
  }
}
