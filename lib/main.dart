import 'package:flutter/material.dart'; // Paket utama Flutter untuk UI
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Untuk memilih warna
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase untuk backend (auth, database)
import 'package:tugas_uas/guards/session_guard.dart'; // Guard untuk membatasi akses halaman jika belum login
import 'package:tugas_uas/pages/diary/detail_page.dart'; // Halaman detail catatan harian
import 'package:tugas_uas/pages/home/home_page.dart'; // Halaman utama aplikasi
import 'package:tugas_uas/pages/auth/login_page.dart'; // Halaman login
import 'package:tugas_uas/pages/profile/profile_form_page.dart'; // Halaman edit profil
import 'package:tugas_uas/pages/auth/register_page.dart'; // Halaman registrasi
import 'package:tugas_uas/splash/splash_page.dart'; // Halaman splash screen
import 'package:tugas_uas/pages/settings/settings_page.dart'; // Halaman pengaturan
import 'package:tugas_uas/pages/settings/backup_page.dart'; // Halaman backup data
import 'package:shared_preferences/shared_preferences.dart'; // Untuk penyimpanan lokal sederhana
import 'package:tugas_uas/services/notification_service.dart'; // Layanan notifikasi lokal
import 'package:flutter_localizations/flutter_localizations.dart'; // Mendukung multi bahasa
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // File hasil generate untuk lokalization
import 'package:provider/provider.dart'; // State management (Provider)
import 'package:tugas_uas/locale_provider.dart'; // Provider untuk pengaturan bahasa
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // Untuk alarm/background task di Android
import 'dart:io' if (dart.library.html) 'dart:html' show window; // Untuk deteksi platform
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform; // Untuk deteksi platform

// Fungsi utama aplikasi, dijalankan pertama kali saat aplikasi dibuka
void main() async {
  // Inisialisasi Supabase (backend untuk autentikasi dan database)
  await Supabase.initialize(
    url: 'https://pkdoslagpkuxbstpuvil.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrZG9zbGFncGt1eGJzdHB1dmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYxNDc0NDgsImV4cCI6MjA2MTcyMzQ0OH0.4pZTEO6DM_CD8-7bap2VEgS5dVRpnxPsgn3gdq2rZYQ',
  );
  WidgetsFlutterBinding.ensureInitialized(); // Wajib sebelum menjalankan aplikasi Flutter
  await NotificationService.init(); // Inisialisasi notifikasi lokal

  // Mengambil instance SharedPreferences untuk menyimpan data lokal
  final prefs = await SharedPreferences.getInstance();
  // Jika notifikasi harian diaktifkan, jadwalkan pengingat harian
  if (prefs.getBool('notif_harian') ?? false) {
    final hour = prefs.getInt('notif_hour') ?? 20;
    final minute = prefs.getInt('notif_minute') ?? 0;
    await NotificationService.scheduleDailyReminder(hour: hour, minute: minute);
  }

  // Inisialisasi provider untuk pengaturan bahasa/locale
  final localeProvider = LocaleProvider();
  await localeProvider.loadLocale(); // Memuat locale dari penyimpanan lokal

  // Inisialisasi alarm manager khusus Android (untuk background task)
  if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
    await AndroidAlarmManager.initialize();
  }

  // Menjalankan aplikasi dengan provider locale
  runApp(ChangeNotifierProvider.value(value: localeProvider, child: MyApp()));
}

// Widget utama aplikasi
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Notifier untuk perubahan tema (light/dark/system)
  final ValueNotifier<ThemeMode> _themeNotifier = ValueNotifier(
    ThemeMode.system,
  );
  // Notifier untuk perubahan warna aksen utama aplikasi
  final ValueNotifier<Color> _accentColorNotifier = ValueNotifier(Colors.blue);
  // Variabel untuk menyimpan mode tema saat ini
  ThemeMode _themeMode = ThemeMode.system;
  // Variabel untuk menyimpan warna utama saat ini
  Color _primaryColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadThemeMode(); // Memuat mode tema dari penyimpanan lokal
    _loadAccentColor(); // Memuat warna aksen dari penyimpanan lokal
  }

  // Fungsi untuk mengubah tema dan menyimpannya ke SharedPreferences
  void _onThemeChanged(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
    setState(() {
      _themeMode = mode;
    });
  }

  // Fungsi untuk memuat mode tema dari SharedPreferences
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

  // Fungsi untuk memuat warna aksen dari SharedPreferences
  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('primary_color');
    if (colorValue != null) {
      setState(() {
        _primaryColor = Color(colorValue);
      });
    }
  }

  // Fungsi untuk mengubah warna aksen dan menyimpannya ke SharedPreferences
  void _onAccentColorChanged(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_color', color.value);
    _accentColorNotifier.value = color;
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil provider locale dari context
    final localeProvider = Provider.of<LocaleProvider>(context);
    // Builder untuk mendengarkan perubahan tema
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, mode, _) {
        // Builder untuk mendengarkan perubahan warna aksen
        return ValueListenableBuilder<Color>(
          valueListenable: _accentColorNotifier,
          builder: (context, color, _) {
            return MaterialApp(
              // Pengaturan locale aplikasi
              locale:
                  localeProvider.locale, // Locale dari SharedPreferences/Provider
              supportedLocales: const [Locale('en'), Locale('id')], // Bahasa yang didukung
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              title: 'Catatan Harian', // Judul aplikasi
              debugShowCheckedModeBanner: false, // Hilangkan banner debug
              // Pengaturan tema aplikasi
              themeMode: _themeMode, // Mode tema (light/dark/system)
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: color), // Warna utama
                useMaterial3: true, // Menggunakan Material 3
              ),
              darkTheme: ThemeData.dark().copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: color,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              // Pengaturan routing halaman aplikasi
              initialRoute: '/', // Halaman pertama saat aplikasi dibuka
              routes: {
                // Routing ke halaman-halaman aplikasi
                '/': (_) => const SplashPage(), // Halaman splash
                '/login': (_) => const LoginPage(), // Halaman login
                '/register': (_) => const RegisterPage(), // Halaman register
                '/home':
                    (_) => SessionGuard(
                      child: HomePage(onThemeChanged: _onThemeChanged),
                    ), // Halaman utama, dilindungi SessionGuard
                '/detail': (_) => const SessionGuard(child: DetailPage()), // Detail catatan
                '/settings':
                    (_) => SessionGuard(
                      child: SettingsPage(
                        onThemeChanged: _onThemeChanged, // Callback untuk ganti tema
                        onAccentColorChanged: _onAccentColorChanged, // Callback untuk ganti warna aksen
                      ),
                    ), // Halaman pengaturan
                '/profile-form':
                    (_) => const SessionGuard(child: ProfileFormPage()), // Edit profil
                '/backup': (_) => const SessionGuard(child: BackupPage()), // Backup data
              },
            );
          },
        );
      },
    );
  }
}
