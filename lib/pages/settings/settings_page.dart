import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/pages/auth/email_confirmation_page.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
//import 'package:tugas_uas/services/notification_service.dart';
import 'package:tugas_uas/pages/settings/notification_settings_page.dart';
import 'package:tugas_uas/widgets/custom_snackbar.dart';

class SettingsPage extends StatefulWidget {
  final void Function(ThemeMode)? onThemeChanged;
  final void Function(Color)? onAccentColorChanged;

  const SettingsPage({
    super.key,
    this.onThemeChanged,
    this.onAccentColorChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  ThemeMode _selectedTheme = ThemeMode.system;
  Color _primaryColor = Colors.blue; // Default color

  final List<ThemeMode> _themeOptions = [
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  bool _notifAktif = false;
  bool _pinToNotification = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemeFromPrefs();
    _loadAccentColor();
    _loadPrefs();
  }

  // Mengambil data pengguna
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;

    if (user != null) {
      final metadata = user.userMetadata ?? {};

      setState(() {
        _emailController.text = user.email ?? '';
        _usernameController.text = user.userMetadata?['username'] ?? '';
      });
    }
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode');

    setState(() {
      if (themeStr == 'ThemeMode.dark') {
        _selectedTheme = ThemeMode.dark;
      } else if (themeStr == 'ThemeMode.light') {
        _selectedTheme = ThemeMode.light;
      } else {
        _selectedTheme = ThemeMode.system;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Akun')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.brightness_6),
                title: Text('Tema Gelap'),
                trailing: Switch(
                  value: _selectedTheme == ThemeMode.dark,
                  onChanged: (value) {
                    setState(() {
                      _selectedTheme = value ? ThemeMode.dark : ThemeMode.light;
                    });

                    // Kirim ke MyApp atau simpan pakai SharedPreferences
                    widget.onThemeChanged?.call(_selectedTheme);
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.color_lens),
                title: Text('Warna Aksen'),
                trailing: CircleAvatar(backgroundColor: _primaryColor),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Pilih Warna Aksen'),
                        content: SingleChildScrollView(
                          child: BlockPicker(
                            pickerColor: _primaryColor,
                            onColorChanged: (color) async {
                              setState(() => _primaryColor = color);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              prefs.setInt('primary_color', color.value);

                              // Kirim ke main.dart kalau kamu pakai fungsi callback
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
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Pemberitahuan'),
                subtitle: const Text(
                  'Atur pengingat harian, waktu, dan preferensi',
                ),
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

              ListTile(
                leading: Icon(Icons.email),
                title: Text('Ubah Email'),
                onTap: () {
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
                                    await _supabase.auth.updateUser(
                                      UserAttributes(email: email),
                                    );

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                const EmailConfirmationPage(),
                                      ),
                                    );
                                  } catch (e) {
                                    // ScaffoldMessenger.of(context).showSnackBar(
                                    //   SnackBar(
                                    //     content: Text('Gagal ubah email: $e'),
                                    //   ),
                                    // );
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
              ListTile(
                leading: Icon(Icons.lock),
                title: Text('Ubah Password'),
                onTap: () {
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
                                if (password.length < 6) {
                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   SnackBar(
                                  //     content: Text(
                                  //       'Password minimal 6 karakter',
                                  //     ),
                                  //   ),
                                  // );
                                  showCustomSnackBar(
                                    context,
                                    'Password minimal 6 karakter',
                                    type: SnackBarType.warning,
                                    showAtTop: true,
                                  );
                                  return;
                                }
                                try {
                                  await _supabase.auth.updateUser(
                                    UserAttributes(password: password),
                                  );
                                  // Navigator.pop(context);
                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   SnackBar(
                                  //     content: Text(
                                  //       'Password berhasil diperbarui',
                                  //     ),
                                  //   ),
                                  // );
                                  showCustomSnackBar(
                                    context,
                                    'Password berhasil diperbarui',
                                    type: SnackBarType.success,
                                    showAtTop: true,
                                  );
                                } catch (e) {
                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   SnackBar(
                                  //     content: Text('Gagal ubah password: $e'),
                                  //   ),
                                  // );
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
