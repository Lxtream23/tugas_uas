// Import package untuk menyimpan data lokal secara permanen
import 'package:shared_preferences/shared_preferences.dart';
// Import package Flutter utama untuk membangun UI
import 'package:flutter/material.dart';
// Import Supabase untuk autentikasi dan backend
import 'package:supabase_flutter/supabase_flutter.dart';
// Import halaman konfirmasi email setelah update email
import 'package:tugas_uas/pages/auth/email_confirmation_page.dart';
// Import package untuk memilih warna
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
// Import halaman pengaturan notifikasi
import 'package:tugas_uas/pages/settings/notification_settings_page.dart';
// Import widget custom snackbar untuk menampilkan pesan
import 'package:tugas_uas/widgets/custom_snackbar.dart';
// Import Provider untuk state management (misal: bahasa)
import 'package:provider/provider.dart';
// Import provider lokal untuk pengaturan bahasa
import 'package:tugas_uas/locale_provider.dart';
// Import file auto-generated untuk internationalization (bahasa)
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Widget utama untuk halaman pengaturan
class SettingsPage extends StatefulWidget {
  // Callback untuk mengubah tema aplikasi
  final void Function(ThemeMode)? onThemeChanged;
  // Callback untuk mengubah warna aksen aplikasi
  final void Function(Color)? onAccentColorChanged;

  // Konstruktor SettingsPage
  const SettingsPage({
    super.key,
    this.onThemeChanged,
    this.onAccentColorChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

// State dari SettingsPage
class _SettingsPageState extends State<SettingsPage> {
  // Inisialisasi Supabase client untuk autentikasi
  final SupabaseClient _supabase = Supabase.instance.client;
  // Key untuk form validasi
  final _formKey = GlobalKey<FormState>();

  // Controller untuk input username
  final TextEditingController _usernameController = TextEditingController();
  // Controller untuk input email
  final TextEditingController _emailController = TextEditingController();
  // Controller untuk input password baru
  final TextEditingController _passwordController = TextEditingController();
  // Controller untuk input password baru (jika diperlukan)
  final TextEditingController _newPasswordController = TextEditingController();

  // Variabel untuk menyimpan tema yang dipilih
  ThemeMode _selectedTheme = ThemeMode.system;
  // Variabel untuk menyimpan warna utama aplikasi
  Color _primaryColor = Colors.blue; // Default color

  // Daftar pilihan tema yang tersedia
  final List<ThemeMode> _themeOptions = [
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  // Variabel untuk status notifikasi harian
  bool _notifAktif = false;
  // Variabel untuk status pin notifikasi ke notification bar
  bool _pinToNotification = false;
  // Variabel untuk waktu pengingat notifikasi
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  // Variabel untuk bahasa yang dipilih
  String _selectedLanguage = 'id';

  @override
  void initState() {
    super.initState();
    // Memuat data user dari Supabase
    _loadUserData();
    // Memuat tema yang tersimpan di SharedPreferences
    _loadThemeFromPrefs();
    // Memuat warna aksen yang tersimpan
    _loadAccentColor();
    // Memuat preferensi notifikasi
    _loadPrefs();
  }

  // Fungsi untuk mengambil data pengguna dari Supabase
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      final metadata = user.userMetadata ?? {};

      setState(() {
        // Set email dan username ke controller
        _emailController.text = user.email ?? '';
        _usernameController.text = user.userMetadata?['username'] ?? '';
      });
    }
  }

  // Fungsi untuk memuat tema dari SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode');

    setState(() {
      // Set tema sesuai dengan yang tersimpan
      if (themeStr == 'ThemeMode.dark') {
        _selectedTheme = ThemeMode.dark;
      } else if (themeStr == 'ThemeMode.light') {
        _selectedTheme = ThemeMode.light;
      } else {
        _selectedTheme = ThemeMode.system;
      }
    });
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

  // Fungsi untuk memuat preferensi notifikasi dari SharedPreferences
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifAktif = prefs.getBool('notif_harian') ?? false;
      _pinToNotification = prefs.getBool('pin_notif') ?? false;

      final hour = prefs.getInt('notif_hour') ?? 20;
      final minute = prefs.getInt('notif_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  // Fungsi untuk memuat bahasa dari SharedPreferences
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'id';
    });
  }

  // Fungsi untuk menyimpan bahasa ke SharedPreferences
  Future<void> _saveLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    setState(() => _selectedLanguage = langCode);
    // Bisa restart app atau trigger update locale
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold sebagai kerangka utama halaman
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Pengaturan tema gelap/terang
              ListTile(
                leading: Icon(Icons.brightness_6),
                title: Text('Tema Gelap'),
                trailing: Switch(
                  value: _selectedTheme == ThemeMode.dark,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value ? ThemeMode.dark : ThemeMode.light;
                    });

                    // Callback ke parent widget atau simpan ke SharedPreferences
                    widget.onThemeChanged?.call(_selectedTheme);
                  },
                ),
              ),
              // Pengaturan warna aksen aplikasi
              ListTile(
                leading: Icon(Icons.color_lens),
                title: Text(AppLocalizations.of(context)!.accentColor),
                trailing: CircleAvatar(backgroundColor: _primaryColor),
                onTap: () {
                  // Tampilkan dialog pemilih warna
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(AppLocalizations.of(context)!.accentColor),
                        content: SingleChildScrollView(
                          child: BlockPicker(
                            pickerColor: _primaryColor,
                            onColorChanged: (color) async {
                              setState(() => _primaryColor = color);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              prefs.setInt('primary_color', color.value);

                              // Callback ke parent widget jika ada
                              widget.onAccentColorChanged?.call(color);

                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // Pengaturan bahasa aplikasi
              ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton<String>(
                  value: context.watch<LocaleProvider>().locale.languageCode,
                  onChanged: (value) {
                    if (value != null) {
                      // Update locale aplikasi
                      context.read<LocaleProvider>().setLocale(value);
                      showCustomSnackBar(
                        context,
                        'Bahasa diperbarui',
                        type: SnackBarType.success,
                        showAtTop: true,
                      );
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'id',
                      child: Text('Bahasa Indonesia'),
                    ),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                ),
              ),

              // Navigasi ke pengaturan notifikasi
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(AppLocalizations.of(context)!.notif),
                subtitle: Text(AppLocalizations.of(context)!.notifDesk),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsPage(),
                    ),
                  );
                },
              ),

              // Pengaturan untuk mengubah email user
              ListTile(
                leading: Icon(Icons.email),
                title: Text('Ubah Email'),
                onTap: () {
                  // Tampilkan dialog input email baru
                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: Text('Ubah Email'),
                          content: TextField(
                            controller: _emailController,
                            decoration: InputDecoration(hintText: 'Email baru'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final email = _emailController.text.trim();
                                if (email.isNotEmpty) {
                                  try {
                                    // Update email user di Supabase
                                    await _supabase.auth.updateUser(
                                      UserAttributes(email: email),
                                    );

                                    // Navigasi ke halaman konfirmasi email
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                const EmailConfirmationPage(),
                                      ),
                                    );
                                  } catch (e) {
                                    // Tampilkan pesan error jika gagal
                                    showCustomSnackBar(
                                      context,
                                      'Gagal ubah email: $e',
                                      type: SnackBarType.error,
                                      showAtTop: true,
                                    );
                                  }
                                }
                              },
                              child: Text('Simpan'),
                            ),
                          ],
                        ),
                  );
                },
              ),
              // Pengaturan untuk mengubah password user
              ListTile(
                leading: Icon(Icons.lock),
                title: Text('Ubah Password'),
                onTap: () {
                  // Tampilkan dialog input password baru
                  showDialog(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: Text('Ubah Password'),
                          content: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'Password baru',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final password =
                                    _passwordController.text.trim();
                                // Validasi panjang password minimal 6 karakter
                                if (password.length < 6) {
                                  showCustomSnackBar(
                                    context,
                                    'Password minimal 6 karakter',
                                    type: SnackBarType.warning,
                                    showAtTop: true,
                                  );
                                  return;
                                }
                                try {
                                  // Update password user di Supabase
                                  await _supabase.auth.updateUser(
                                    UserAttributes(password: password),
                                  );

                                  // Tampilkan pesan sukses
                                  showCustomSnackBar(
                                    context,
                                    'Password berhasil diperbarui',
                                    type: SnackBarType.success,
                                    showAtTop: true,
                                  );
                                } catch (e) {
                                  // Tampilkan pesan error jika gagal
                                  showCustomSnackBar(
                                    context,
                                    'Gagal ubah password: $e',
                                    type: SnackBarType.error,
                                    showAtTop: true,
                                  );
                                }
                              },
                              child: Text('Simpan'),
                            ),
                          ],
                        ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
