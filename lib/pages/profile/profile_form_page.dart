import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/widgets/custom_snackbar.dart';

// Widget utama halaman form profil
class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

// State dari halaman ProfileFormPage
class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>(); // Key untuk validasi form
  final _supabase = Supabase.instance.client; // Instance Supabase untuk akses database dan storage

  // Controller untuk input field
  final _emailController = TextEditingController();
  final _namaController = TextEditingController();
  final _ttlController = TextEditingController();
  final _alamatController = TextEditingController();
  final _statusController = TextEditingController();

  String? _fotoUrl; // URL foto profil yang dipilih/diupload
  String? _uploadedFotoUrl; // URL foto profil yang diupload (tidak selalu digunakan)
  bool _isLoading = false; // Status loading saat proses simpan

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? ''; // Set email dari user login
    }
    _loadUserData(); // Ambil data profil user dari database
  }

  // Fungsi untuk mengambil data profil user dari Supabase
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';

      try {
        // Query data profil user berdasarkan id user
        final response =
            await _supabase
                .from('user_profiles')
                .select()
                .eq('id', user.id)
                .single();

        if (response != null) {
          // Set data ke controller dan state
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
        // Jika gagal ambil data, tampilkan snackbar error
        if (mounted) {
          showCustomSnackBar(
            context,
            'data profil kosong',
            type: SnackBarType.error,
            duration: const Duration(seconds: 2),
            showAtTop: true,
          );
        }
      }
    }
    print('Foto URL: $_fotoUrl');
    print('Upload URL: $_uploadedFotoUrl');
  }

  // Fungsi untuk menyimpan/update data profil ke Supabase
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return; // Validasi form

    setState(() => _isLoading = true); // Tampilkan loading

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      // Data yang akan diupdate/insert ke tabel user_profiles
      final data = {
        'id': user.id,
        'email': _emailController.text.trim(),
        'nama_lengkap': _namaController.text.trim(),
        'tempat_tanggal_lahir': _ttlController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'status': _statusController.text.trim(),
        'foto_profil': _fotoUrl ?? '',
      };

      await _supabase.from('user_profiles').upsert(data); // Simpan ke database

      if (mounted) {
        // Tampilkan notifikasi sukses dan kembali ke halaman sebelumnya
        showCustomSnackBar(
          context,
          'Profil berhasil disimpan',
          type: SnackBarType.success,
          duration: const Duration(seconds: 2),
          showAtTop: true,
        );

        Navigator.pop(context);
      }
    } catch (e) {
      // Tampilkan notifikasi error jika gagal simpan
      showCustomSnackBar(
        context,
        'Gagal menyimpan: $e',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
    } finally {
      setState(() => _isLoading = false); // Sembunyikan loading
    }
  }

  // Fungsi untuk upload foto profil ke Supabase Storage
  Future<void> _uploadFotoProfil() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery); // Pilih gambar dari galeri
    if (picked == null) return;

    final fileExt = picked.name.split('.').last.toLowerCase(); // Ekstensi file
    if (!(fileExt == 'jpg' || fileExt == 'png')) {
      // Validasi format file
      showCustomSnackBar(
        context,
        'Format file tidak didukung (hanya JPG/PNG)',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final fileBytes = await picked.readAsBytes(); // Baca file sebagai bytes

    // Buat nama file unik berdasarkan timestamp
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = "${user.id}/$fileName";

    try {
      // Upload file ke Supabase Storage
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: false),
          );

      // Ambil public URL dari file yang diupload
      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      print('✅ File uploaded: $filePath');
      print('✅ Public URL: $publicUrl');

      setState(() {
        _fotoUrl = publicUrl; // Set URL foto profil
      });

      // Update URL foto profil di database
      await _supabase
          .from('user_profiles')
          .update({'foto_profil': _fotoUrl})
          .eq('id', user.id);

      // Tampilkan notifikasi sukses
      showCustomSnackBar(
        context,
        'Foto berhasil diunggah',
        type: SnackBarType.success,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
    } catch (e) {
      // Tampilkan notifikasi error jika gagal upload
      showCustomSnackBar(
        context,
        'Gagal upload foto: $e',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );

      print('Gagal upload foto: $e');
    }
  }

  // Fungsi untuk mengambil daftar avatar yang sudah diupload user dari Supabase Storage
  Future<List<Map<String, String>>> _getUploadedAvatars() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Ambil daftar file di folder user pada storage 'avatars'
      final files = await _supabase.storage.from('avatars').list(path: user.id);

      // Filter hanya file jpg/png
      final validFiles =
          files
              .where(
                (file) =>
                    file.name.endsWith('.jpg') || file.name.endsWith('.png'),
              )
              .toList();

      // Mapping ke format {url, name}
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

  // Fungsi untuk menampilkan modal bottom sheet pemilih avatar
  Future<void> _showAvatarPicker() async {
    // Daftar avatar default dari asset lokal
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

    // Ambil avatar yang sudah diupload user
    final uploadedAvatars = await _getUploadedAvatars();
    print('📸 Avatar dari Supabase: $uploadedAvatars');

    // Gabungkan avatar upload dan asset lokal
    final avatarList = [
      ...uploadedAvatars,
      ...avatarAssets.map((asset) => {'url': asset, 'name': ''}),
    ];
    print('📦 Total avatar: ${avatarList.length}');

    // Tampilkan modal bottom sheet
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

              // GridView untuk menampilkan daftar avatar
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
                    final isUrl = path.startsWith('http'); // Cek apakah avatar dari storage atau asset

                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        // Widget avatar (bisa dari network atau asset)
                        GestureDetector(
                          onTap: () async {
                            setState(() {
                              _fotoUrl = path; // Set avatar yang dipilih
                            });

                            // Update foto profil di database
                            await _supabase
                                .from('user_profiles')
                                .update({'foto_profil': _fotoUrl})
                                .eq('id', _supabase.auth.currentUser!.id);

                            Navigator.pop(context); // Tutup modal
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

                        // Tombol hapus hanya muncul untuk avatar dari Supabase Storage
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
                                  // Hapus file dari Supabase Storage
                                  final result = await _supabase.storage
                                      .from('avatars')
                                      .remove([filePath]);

                                  print('🔁 Result hapus: $result');

                                  if (result.isNotEmpty) {
                                    setState(() {
                                      _fotoUrl = null; // Reset foto profil jika dihapus
                                    });
                                    showCustomSnackBar(
                                      context,
                                      'Avatar berhasil dihapus',
                                      type: SnackBarType.success,
                                      duration: const Duration(seconds: 2),
                                      showAtTop: true,
                                    );

                                    Navigator.pop(context); // Tutup modal
                                    await _showAvatarPicker(); // Refresh daftar avatar
                                  } else {
                                    // Jika gagal hapus, tampilkan error
                                    showCustomSnackBar(
                                      context,
                                      'Gagal menghapus avatar',
                                      type: SnackBarType.error,
                                      duration: const Duration(seconds: 2),
                                      showAtTop: true,
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

              // Tombol untuk upload avatar baru dari galeri
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
    // Dispose semua controller untuk menghindari memory leak
    _emailController.dispose();
    _namaController.dispose();
    _ttlController.dispose();
    _alamatController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tentukan image provider untuk avatar (network atau asset)
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
              // Widget avatar, bisa di-tap untuk memilih avatar
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

              // Tombol untuk upload foto profil dari galeri
              ElevatedButton.icon(
                onPressed: _uploadFotoProfil,
                icon: const Icon(Icons.image),
                label: const Text('Unggah Foto Profil'),
              ),
              const SizedBox(height: 16),
              // Field email (readonly)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
              ),
              const SizedBox(height: 12),
              // Field nama lengkap
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
              // Field tempat & tanggal lahir
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
              // Field alamat
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
              // Field status
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
              // Tombol simpan profil
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
