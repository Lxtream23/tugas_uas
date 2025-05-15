import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
  String? _uploadedFotoUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
    }
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';

      try {
        final response =
            await _supabase
                .from('user_profiles')
                .select()
                .eq('id', user.id)
                .single();
        //.maybeSingle(); // Gunakan maybeSingle agar tidak error jika tidak ada data

        if (response != null) {
          _namaController.text = response['nama_lengkap'] ?? '';
          _ttlController.text = response['tempat_tanggal_lahir'] ?? '';
          _alamatController.text = response['alamat'] ?? '';
          _statusController.text = response['status'] ?? '';
          setState(() {
            _fotoUrl = response['foto_profil'] ?? '';
            _uploadedFotoUrl = response['upload_url'];
            print('LOADED upload_url from Supabase: $_uploadedFotoUrl');
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('data profil kosong')));
        }
      }
    }
    print('Foto URL: $_fotoUrl');
    print('Upload URL: $_uploadedFotoUrl');
  }

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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final fileExt = picked.path.split('.').last;
    final filePath = '${user.id}/profile.$fileExt'; // ✅ benar!

    try {
      // Upload file ke storage Supabase
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
      } else {
        final file = File(picked.path);
        await Supabase.instance.client.storage
            .from('avatars')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(upsert: true),
            );
      }

      // Ambil URL publik dari storage
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      // Update data foto ke tabel user_profiles
      await Supabase.instance.client
          .from('user_profiles')
          .update({'foto_profil': publicUrl, 'upload_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        _uploadedFotoUrl = publicUrl;
        _fotoUrl = publicUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diunggah dan disimpan'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload/simpan foto: $e')));
      print('Error uploading image: $e');
    }
  }

  void _showAvatarPicker() {
    print('Uploaded foto url: $_uploadedFotoUrl');

    final avatarAssets = [
      'assets/avatars/avatar1.png',
      'assets/avatars/avatar2.png',
      'assets/avatars/avatar3.png',
      'assets/avatars/avatar4.png',
      'assets/avatars/avatar5.png',
      'assets/avatars/avatar6.png',
      'assets/avatars/avatar7.png',
      'assets/avatars/avatar8.png',
      'assets/avatars/avatar9.png',
      'assets/avatars/avatar10.png',
    ];

    final List<String> avatarList = [];

    // Tambahkan foto dari Supabase Storage jika ada
    if (_uploadedFotoUrl != null && _uploadedFotoUrl!.startsWith('http')) {
      avatarList.add(_uploadedFotoUrl!); // taruh di awal
    }
    // Lalu tambahkan semua avatar default dari asset
    avatarList.addAll(avatarAssets);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih Avatar', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),

              // GridView untuk semua avatar
              SizedBox(
                height: 250,
                child: GridView.builder(
                  itemCount: avatarList.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final path = avatarList[index];
                    final isUrl = path.startsWith('http');

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _fotoUrl = path;
                          // ❗ Tambahkan hanya jika path adalah URL Supabase
                          if (path.startsWith('http')) {
                            _uploadedFotoUrl = path;
                          }
                        });
                        Navigator.pop(context);
                      },

                      child: CircleAvatar(
                        backgroundImage:
                            isUrl
                                ? NetworkImage(path)
                                : AssetImage(path) as ImageProvider,
                        radius: 32,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _uploadFotoProfil();
                },
                icon: const Icon(Icons.upload),
                label: const Text('Upload dari Galeri'),
              ),
            ],
          ),
        );
      },
    );
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
    ImageProvider avatarImage;

    if (_fotoUrl == null || _fotoUrl!.isEmpty) {
      avatarImage = const AssetImage('assets/avatars/avatar1.png');
    } else if (_fotoUrl!.startsWith('http')) {
      avatarImage = NetworkImage(_fotoUrl!);
    } else {
      avatarImage = AssetImage(_fotoUrl!);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _showAvatarPicker,
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.grey[200],
                  child: ClipOval(
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child:
                          _fotoUrl != null && _fotoUrl!.isNotEmpty
                              ? (_fotoUrl!.startsWith('http')
                                  ? Image.network(_fotoUrl!, fit: BoxFit.cover)
                                  : Image.asset(_fotoUrl!, fit: BoxFit.cover))
                              : Image.asset(
                                'assets/avatars/avatar1.png',
                                fit: BoxFit.cover,
                              ),
                    ),
                  ),
                ),
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
                        value == null || value.isEmpty
                            ? 'Nama Lengkap Tidak Boleh Kosong'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ttlController,
                decoration: const InputDecoration(
                  labelText: 'Tempat & Tanggal Lahir',
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Tempat & Tanggal Lahir Tidak Boleh Kosong'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _alamatController,
                decoration: const InputDecoration(labelText: 'Alamat'),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Alamat Tidak Boleh Kosong'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(
                  labelText: 'Status (Pelajar, Pegawai, dll)',
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Status Tidak Boleh Kosong'
                            : null,
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
