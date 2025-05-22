import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/pages/email_confirmation_page.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:tugas_uas/services/notification_service.dart';

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

  bool _isLoading = false;
  bool _notifAktif = false;

  ThemeMode _selectedTheme = ThemeMode.system;

  Color _primaryColor = Colors.blue; // Default color

  final List<ThemeMode> _themeOptions = [
    ThemeMode.light,
    ThemeMode.dark,
    ThemeMode.system,
  ];

  TimeOfDay _waktuNotifikasi = const TimeOfDay(
    hour: 20,
    minute: 0,
  ); // default jam 8 malam

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemeFromPrefs();
    _loadAccentColor();
    _loadNotifikasiStatus();
    _loadWaktuNotifikasi();
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

  Future<void> _loadNotifikasiStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifAktif = prefs.getBool('notif_harian') ?? false;
    });
  }

  Future<void> _loadWaktuNotifikasi() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('notif_hour') ?? 20;
    final minute = prefs.getInt('notif_minute') ?? 0;

    setState(() {
      _waktuNotifikasi = TimeOfDay(hour: hour, minute: minute);
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
              ExpansionTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notifikasi Harian'),
                children: [
                  SwitchListTile(
                    title: const Text('Aktifkan Notifikasi'),
                    value: _notifAktif,
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      setState(() => _notifAktif = value);
                      await prefs.setBool('notif_harian', value);

                      if (value) {
                        await NotificationService.scheduleDailyReminder(
                          hour: _waktuNotifikasi.hour,
                          minute: _waktuNotifikasi.minute,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notifikasi diaktifkan'),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifikasi dimatikan')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Jam Pengingat'),
                    subtitle: Text(
                      '${_waktuNotifikasi.format(context)} setiap hari',
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _waktuNotifikasi,
                      );

                      if (picked != null) {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _waktuNotifikasi = picked);
                        await prefs.setInt('notif_hour', picked.hour);
                        await prefs.setInt('notif_minute', picked.minute);

                        if (_notifAktif) {
                          await NotificationService.scheduleDailyReminder(
                            hour: picked.hour,
                            minute: picked.minute,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Notifikasi dijadwalkan ulang ke ${picked.format(context)}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal ubah email: $e'),
                                      ),
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Password minimal 6 karakter',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await _supabase.auth.updateUser(
                                    UserAttributes(password: password),
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Password berhasil diperbarui',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal ubah password: $e'),
                                    ),
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
