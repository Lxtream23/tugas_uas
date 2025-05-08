import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _namaController = TextEditingController();
  final _ttlController = TextEditingController();
  final _alamatController = TextEditingController();
  final _statusController = TextEditingController();

  String? _fotoUrl;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      final data = {
        'id': user.id,
        'email': _emailController.text.trim(),
        'nama_lengkap': _namaController.text.trim(),
        'tempat_tanggal_lahir': _ttlController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'status': _statusController.text.trim(),
        'foto_profil': _fotoUrl ?? '',
      };

      await _supabase.from('user_profiles').upsert(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil disimpan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFotoProfil() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final file = File(picked.path);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final fileExt = picked.path.split('.').last;
    final filePath = 'avatars/${user.id}.$fileExt';

    try {
      // Upload ke Storage Supabase
      await _supabase.storage
          .from('avatars')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      setState(() {
        _fotoUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diunggah')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _namaController.dispose();
    _ttlController.dispose();
    _alamatController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Profil Anda')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_fotoUrl != null)
                Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(_fotoUrl!),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ElevatedButton.icon(
                onPressed: _uploadFotoProfil,
                icon: const Icon(Icons.image),
                label: const Text('Unggah Foto Profil'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Email wajib diisi';
                  final pattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!pattern.hasMatch(value))
                    return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                validator:
                    (value) =>
                        value == null || value.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ttlController,
                decoration: const InputDecoration(
                  labelText: 'Tempat & Tanggal Lahir',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamatController,
                decoration: const InputDecoration(labelText: 'Alamat'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: 'Status (Pelajar, Pegawai, dll)',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Simpan Profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
