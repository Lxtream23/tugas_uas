import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/pages/email_confirmation_page.dart';

class SettingsPage extends StatefulWidget {
  final void Function(ThemeMode)? onThemeChanged;

  const SettingsPage({super.key, this.onThemeChanged});

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

  ThemeMode _selectedTheme = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
