import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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

  // Mengupdate profil pengguna
  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      // Mengupdate metadata pengguna jika nama pengguna berubah
      await _supabase.auth.updateUser(
        UserAttributes(
          email: _emailController.text,
          data: {'username': _usernameController.text},
        ),
      );

      if (_passwordController.text.isNotEmpty &&
          _newPasswordController.text.isNotEmpty) {
        // Jika password baru diberikan, lakukan update password
        await _supabase.auth.updateUser(
          UserAttributes(password: _newPasswordController.text),
        );
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui!')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memperbarui profil: $e')));
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Nama Pengguna'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama pengguna tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Kata Sandi Lama'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'Kata Sandi Baru'),
                obscureText: true,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (_passwordController.text.isEmpty) {
                      return 'Masukkan kata sandi lama terlebih dahulu';
                    }
                    if (value.length < 6) {
                      return 'Kata sandi baru minimal 6 karakter';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Perbarui Profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
