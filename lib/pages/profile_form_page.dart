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

    final fileExt = picked.name.split('.').last.toLowerCase();
    if (!(fileExt == 'jpg' || fileExt == 'png')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format file tidak didukung (hanya JPG/PNG)'),
        ),
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final fileBytes = await picked.readAsBytes();

    // ✅ Buat nama file dari timestamp saja
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = "${user.id}/$fileName";

    try {
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: false),
          );

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      print('✅ File uploaded: $filePath');
      print('✅ Public URL: $publicUrl');

      setState(() {
        _fotoUrl = publicUrl;
      });

      await _supabase
          .from('user_profiles')
          .update({'foto_profil': _fotoUrl})
          .eq('id', user.id);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto berhasil diunggah')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal upload foto: $e')));
      print('Gagal upload foto: $e');
    }
  }

  Future<List<Map<String, String>>> _getUploadedAvatars() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final files = await _supabase.storage.from('avatars').list(path: user.id);

      final validFiles =
          files
              .where(
                (file) =>
                    file.name.endsWith('.jpg') || file.name.endsWith('.png'),
              )
              .toList();

      return validFiles.map((file) {
        final url = _supabase.storage
            .from('avatars')
            .getPublicUrl("${user.id}/${file.name}");
        return {'url': url, 'name': file.name};
      }).toList();
    } catch (e) {
      print('❌ Gagal ambil avatar: \$e');
      return [];
    }
  }

  Future<void> _showAvatarPicker() async {
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

    // Ambil avatar dari Supabase Storage
    final uploadedAvatars = await _getUploadedAvatars();
    print('📸 Avatar dari Supabase: $uploadedAvatars');

    // Gabungkan semua avatar (upload + asset)
    final avatarList = [
      ...uploadedAvatars,
      ...avatarAssets.map((asset) => {'url': asset, 'name': ''}),
    ];
    print('📦 Total avatar: ${avatarList.length}');

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

              // GridView avatar
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
                    final data = avatarList[index];
                    final mapData = data as Map<String, String>;
                    final path = mapData['url']!;
                    final fileName = mapData['name']!;
                    final isUrl = path.startsWith('http');

                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            setState(() {
                              _fotoUrl = path;
                            });

                            await _supabase
                                .from('user_profiles')
                                .update({'foto_profil': _fotoUrl})
                                .eq('id', _supabase.auth.currentUser!.id);

                            Navigator.pop(context);
                          },
                          child: CircleAvatar(
                            backgroundImage:
                                isUrl
                                    ? NetworkImage(path)
                                    : AssetImage(path) as ImageProvider,
                            radius: 32,
                            onBackgroundImageError: (e, stack) {
                              print("❌ Gagal load avatar: $path");
                            },
                          ),
                        ),

                        // 🗑️ Tampilkan tombol hapus hanya untuk URL Supabase
                        if (isUrl)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.red,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final user = _supabase.auth.currentUser;
                                if (user == null) return;

                                final filename = path.split('/').last;
                                final filePath = "${user.id}/$filename";
                                print("🧾 Hapus file di Supabase: $filePath");

                                try {
                                  final result = await _supabase.storage
                                      .from('avatars')
                                      .remove([filePath]);

                                  print('🔁 Result hapus: $result');

                                  if (result.isNotEmpty) {
                                    setState(() {
                                      _fotoUrl = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ Avatar berhasil dihapus',
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);
                                    await _showAvatarPicker(); // refresh daftar
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '❌ Gagal menghapus avatar',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('❌ Gagal hapus avatar: $e');
                                }
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Tombol Upload Avatar
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _uploadFotoProfil(); // Fungsi upload avatar
                },
                icon: const Icon(Icons.upload),
                label: const Text('Upload dari Galeri'),
              ),
            ],
          ),
        );
      },
    );

    print('📦 Total avatar yang ditampilkan: ${avatarList.length}');
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
                onTap: () async {
                  await _showAvatarPicker();
                },
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.grey[200],
                  child: ClipOval(
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child:
                          (_fotoUrl != null &&
                                  _fotoUrl!.isNotEmpty &&
                                  _fotoUrl!.startsWith('http'))
                              ? Image.network(
                                _fotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/avatars/avatar1.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                              : (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                              ? Image.asset(_fotoUrl!, fit: BoxFit.cover)
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
