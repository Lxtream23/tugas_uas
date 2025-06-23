import 'package:flutter/material.dart'; // Paket UI utama Flutter
import 'package:supabase_flutter/supabase_flutter.dart'; // Untuk koneksi ke Supabase (backend)
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:google_fonts/google_fonts.dart'; // Untuk menggunakan font Google
import 'package:palette_generator/palette_generator.dart'; // Untuk mengambil warna dominan dari gambar
import 'package:image_picker/image_picker.dart'; // Untuk memilih gambar dari galeri
import 'dart:io'; // Untuk operasi file (khusus mobile)
import 'package:flutter/foundation.dart'; // Untuk cek platform (web/mobile)
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar

// Halaman detail catatan harian (tambah/edit)
class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with TickerProviderStateMixin {
  // Controller untuk input judul
  final _titleController = TextEditingController();
  // Controller untuk input isi utama
  final _contentController = TextEditingController();
  // Controller untuk input isi di bawah gambar
  final _contentBelowController = TextEditingController();

  // Instance Supabase untuk akses database dan storage
  final supabase = Supabase.instance.client;
  bool _isLoading = false; // Status loading saat simpan/hapus
  Map? _entry; // Data catatan yang sedang diedit (null jika tambah baru)
  Map<String, dynamic>? _lastDeletedEntry; // Untuk fitur undo hapus
  String? _selectedEmoji; // Emoji yang dipilih
  String? _selectedBackground; // Path background yang dipilih
  Color _textColor = Colors.black; // Warna teks (otomatis menyesuaikan background)

  List<File> _pickedImages = []; // List gambar yang dipilih (mobile)
  List<Uint8List> _pickedImagesBytes = []; // List gambar (web)
  List<String> _uploadedImageUrls = []; // URL gambar yang sudah diupload ke Supabase

  bool _isInitialized = false; // Untuk mencegah inisialisasi ulang
  DateTime? _entryDate; // Tanggal catatan
  bool _isFavorite = false; // Status favorit

  // Controller animasi untuk tanggal
  late AnimationController _dateController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Inisialisasi data jika belum
    if (!_isInitialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args != null && args is Map) {
        // Jika mode edit, ambil data dari argumen
        _entry = args;
        _titleController.text = _entry!['title'] ?? '';
        _contentController.text = _entry!['content'] ?? '';
        _selectedEmoji = _entry!['emoji'] ?? '';
        _selectedBackground = _entry?['background'] ?? '';
        _textColor =
            (_entry!['text_color'] ?? 'black') == 'white'
                ? Colors.white
                : Colors.black;
        _contentBelowController.text =
            _entry?['content_below'] ?? '';
        _uploadedImageUrls =
            (_entry!['image_urls'] as List<dynamic>?)
                ?.map((url) => url.toString())
                .toList() ??
            [];
        _entryDate =
            DateTime.tryParse(_entry!['created_at'] ?? '') ?? DateTime.now();
        _isFavorite = _entry!['is_favorite'] ?? false;
      } else {
        // Jika tambah baru
        _entryDate = DateTime.now();
        _isFavorite = false;
      }
      _isInitialized = true;
    }

    // Setup animasi tanggal
    _dateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _dateController, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(
      parent: _dateController,
      curve: Curves.easeIn,
    );
    _dateController.forward();
  }

  @override
  void dispose() {
    // Dispose controller untuk menghindari memory leak
    _titleController.dispose();
    _contentController.dispose();
    _contentBelowController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // Fungsi untuk menyimpan catatan (tambah/edit)
  Future<void> _saveEntry() async {
    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final user = supabase.auth.currentUser;

    // Validasi user login
    if (user == null) {
      showCustomSnackBar(
        context,
        'User tidak ditemukan. Silakan login ulang.',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
      setState(() => _isLoading = false);
      return;
    }

    // Validasi input tidak kosong
    if (title.isEmpty || content.isEmpty) {
      showCustomSnackBar(
        context,
        'Judul dan isi tidak boleh kosong',
        type: SnackBarType.warning,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Data yang akan disimpan
      final data = {
        'user_id': user.id,
        'title': title,
        'content': content,
        'emoji': _selectedEmoji ?? '',
        'background': _selectedBackground ?? '',
        'text_color': _textColor == Colors.white ? 'white' : 'black',
        'content_below': _contentBelowController.text.trim(),
        'image_urls': _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls : null,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (_entry == null) {
        // Tambah baru
        await supabase.from('diary_entries').insert(data);
      } else {
        // Edit, update data kecuali user_id & created_at
        final id = _entry?['id'];
        if (id == null) throw Exception('ID catatan tidak ditemukan');
        final updateData = Map.of(data);
        updateData.remove('user_id');
        updateData.remove('created_at');
        await supabase.from('diary_entries').update(updateData).eq('id', id);
      }

      if (mounted) Navigator.pop(context, true); // Kembali ke halaman sebelumnya
    } catch (e) {
      showCustomSnackBar(
        context,
        'Gagal menyimpan catatan: $e',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk menghapus catatan
  Future<void> _deleteEntry() async {
    // Konfirmasi hapus
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Hapus Catatan'),
            content: const Text('Yakin ingin menghapus catatan ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final id = _entry?['id'];
    if (id == null) return;

    try {
      // Simpan data terakhir untuk undo
      _lastDeletedEntry = Map<String, dynamic>.from(_entry!);
      await supabase.from('diary_entries').delete().eq('id', id);

      if (mounted) {
        // Tampilkan snackbar dengan opsi undo
        showCustomSnackBar(
          context,
          'Catatan dihapus',
          type: SnackBarType.warning,
          actionLabel: 'Undo',
          onActionPressed: _undoDelete,
          duration: const Duration(seconds: 5),
          showAtTop: true,
        );

        Navigator.pop(context, true); // kembali ke halaman sebelumnya
      }
    } catch (e) {
      showCustomSnackBar(
        context,
        'Gagal menghapus catatan: $e',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
    }
  }

  // Fungsi untuk undo hapus catatan
  Future<void> _undoDelete() async {
    final userId = supabase.auth.currentUser?.id;

    if (_lastDeletedEntry == null || userId == null) {
      showCustomSnackBar(
        context,
        'Gagal undo: pengguna tidak ditemukan',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
      return;
    }

    try {
      // Insert ulang data yang dihapus
      await supabase.from('diary_entries').insert({
        'user_id': userId,
        'title': _lastDeletedEntry!['title'],
        'content': _lastDeletedEntry!['content'],
        'emoji': _lastDeletedEntry!['emoji'],
        'background': _lastDeletedEntry!['background'] ?? '',
        'text_color': _lastDeletedEntry!['text_color'] ?? 'black',
        'content_below': _lastDeletedEntry!['content_below'] ?? '',
        'image_urls': _lastDeletedEntry!['image_urls'] ?? [],
        'created_at': DateTime.now().toIso8601String(),
      });

      _lastDeletedEntry = null;
    } catch (e) {
      showCustomSnackBar(
        context,
        'Gagal mengembalikan catatan: $e',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
    }
  }

  // Menampilkan bottom sheet untuk memilih emoji
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final emojis = [
          // Daftar emoji yang bisa dipilih
          '😀','😎','😊','😍','🤩','😢','😭','😡','🤔','😴','😇','🥳','🤯','😱','🤤','😬','🙄','😌','💀','👻','🤗','🥰','😅','🤪','😷','😤','🤫','🤮','😈','👽',
        ];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: emojis.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmoji = emojis[index];
                  });
                  Navigator.pop(context);
                },
                child: Center(
                  child: Text(
                    emojis[index],
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Fungsi untuk mengubah angka bulan menjadi nama bulan Indonesia
  String _monthName(int month) {
    const bulan = [
      '',
      'Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember',
    ];
    return bulan[month];
  }

  // Menampilkan bottom sheet untuk memilih background
  void _showBackgroundPicker() {
    final backgrounds = [
      // Daftar path gambar background
      'assets/bg_catatan/bg.jpeg',
      'assets/bg_catatan/bg1.jpeg',
      'assets/bg_catatan/bg2.jpeg',
      'assets/bg_catatan/bg3.jpeg',
      'assets/bg_catatan/bg4.jpeg',
      'assets/bg_catatan/bg5.jpeg',
      'assets/bg_catatan/bg6.jpeg',
      'assets/bg_catatan/bg7.jpeg',
      'assets/bg_catatan/bg8.jpeg',
      'assets/bg_catatan/bg9.jpeg',
      'assets/bg_catatan/bg10.jpeg',
      'assets/bg_catatan/bg11.jpeg',
      'assets/bg_catatan/bg12.jpeg',
      'assets/bg_catatan/bg13.jpeg',
      'assets/bg_catatan/bg14.jpeg',
      'assets/bg_catatan/bg15.jpeg',
      'assets/bg_catatan/bg16.jpeg',
      'assets/bg_catatan/bg17.jpeg',
      'assets/bg_catatan/bg18.jpeg',
      'assets/bg_catatan/bg19.jpeg',
      'assets/bg_catatan/bg20.jpeg',
      'assets/bg_catatan/bg21.jpeg',
      'assets/bg_catatan/bg22.jpeg',
      'assets/bg_catatan/bg23.jpeg',
      'assets/bg_catatan/bg24.jpeg',
      'assets/bg_catatan/bg25.jpeg',
      'assets/bg_catatan/bg27.jpeg',
      'assets/bg_catatan/bg28.jpeg',
      'assets/bg_catatan/bg29.jpeg',
      'assets/bg_catatan/bg30.jpeg',
      'assets/bg_catatan/bg31.jpeg',
      'assets/bg_catatan/bg32.jpeg',
      'assets/bg_catatan/bg33.jpeg',
      'assets/bg_catatan/bg34.jpeg',
      'assets/bg_catatan/bg35.jpeg',
      'assets/bg_catatan/bg36.jpeg',
      'assets/bg_catatan/bg37.jpeg',
      'assets/bg_catatan/bg38.jpeg',
      'assets/bg_catatan/bg39.jpeg',
      'assets/bg_catatan/bg40.jpeg',
      'assets/bg_catatan/bg41.jpeg',
      'assets/bg_catatan/bg42.jpeg',
      'assets/bg_catatan/bg43.jpeg',
      'assets/bg_catatan/bg44.jpeg',
      'assets/bg_catatan/bg45.jpeg',
      'assets/bg_catatan/bg46.jpeg',
      'assets/bg_catatan/bg47.jpeg',
      'assets/bg_catatan/bg48.jpeg',
      'assets/bg_catatan/bg49.jpeg',
      'assets/bg_catatan/bg50.jpeg',
      'assets/bg_catatan/bg51.jpeg',
      'assets/bg_catatan/bg52.jpeg',
      'assets/bg_catatan/bg53.jpeg',
      'assets/bg_catatan/bg54.jpeg',
      'assets/bg_catatan/bg55.jpeg',
      'assets/bg_catatan/bg56.jpeg',
      'assets/bg_catatan/bg57.jpeg',
      'assets/bg_catatan/bg58.jpeg',
      'assets/bg_catatan/bg59.jpeg',
      'assets/bg_catatan/bg60.jpeg',
      'assets/bg_catatan/bg61.jpeg',
      'assets/bg_catatan/bg62.jpeg',
      'assets/bg_catatan/bg63.jpeg',
      'assets/bg_catatan/bg64.jpeg',
      'assets/bg_catatan/bg65.jpeg',
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: backgrounds.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () async {
                  final imagePath = backgrounds[index];

                  // Tampilkan loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  // Ambil warna dominan dari gambar
                  final imageProvider = AssetImage(imagePath);
                  final palette = await PaletteGenerator.fromImageProvider(
                    imageProvider,
                  );
                  final dominantColor =
                      palette.dominantColor?.color ?? Colors.white;
                  final luminance = dominantColor.computeLuminance();

                  setState(() {
                    _selectedBackground = imagePath;
                    _textColor = luminance > 0.5 ? Colors.black : Colors.white;
                  });

                  Navigator.pop(context); // tutup loading
                  Navigator.pop(context); // tutup bottom sheet
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(backgrounds[index], fit: BoxFit.cover),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Fungsi untuk memilih gambar dari galeri dan upload ke Supabase Storage
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        showCustomSnackBar(
          context,
          'User tidak ditemukan, silakan login ulang',
          type: SnackBarType.error,
          duration: const Duration(seconds: 2),
          showAtTop: true,
        );
        return;
      }
      print(supabase.auth.currentUser);

      // Nama file aman
      final safeName = pickedFile.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-\.]'),
        '',
      );
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final storage = Supabase.instance.client.storage.from('diaryimages');
      final fileBytes = await pickedFile.readAsBytes();

      try {
        // Upload ke Supabase Storage
        final response = await storage.uploadBinary(
          fileName,
          fileBytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            metadata: {'user_id': userId},
          ),
        );

        if (response.isEmpty) {
          throw Exception('Upload gagal');
        }

        final publicUrl = storage.getPublicUrl(fileName);
        print('✅ Public URL: $publicUrl');

        setState(() {
          if (kIsWeb) {
            _pickedImagesBytes.add(fileBytes);
          } else {
            _pickedImages.add(File(pickedFile.path));
          }
          _uploadedImageUrls.add(publicUrl);
        });
        showCustomSnackBar(
          context,
          'Gambar berhasil diupload',
          type: SnackBarType.success,
          duration: const Duration(seconds: 2),
          showAtTop: true,
        );
      } catch (e) {
        showCustomSnackBar(
          context,
          'Gagal upload gambar: $e',
          type: SnackBarType.error,
          duration: const Duration(seconds: 2),
          showAtTop: true,
        );
      }
    }
  }

  // Fungsi untuk toggle status favorit catatan
  Future<void> _toggleFavorite() async {
    if (_entry != null && _entry!['id'] != null) {
      final newStatus = !(_entry!['is_favorite'] ?? false);
      setState(() {
        _entry!['is_favorite'] = newStatus;
      });

      try {
        await Supabase.instance.client
            .from('diary_entries')
            .update({'is_favorite': newStatus})
            .eq('id', _entry!['id']);

        showCustomSnackBar(
          context,
          newStatus ? 'Ditandai sebagai favorit' : 'Dihapus dari favorit',
          type: SnackBarType.success,
          duration: const Duration(seconds: 2),
          showAtTop: true,
        );
      } catch (e) {
        // Revert jika gagal
        setState(() {
          _entry!['is_favorite'] = !newStatus;
        });
        showCustomSnackBar(
          context,
          'Gagal mengupdate favorit. Coba lagi!',
          type: SnackBarType.error,
          duration: const Duration(seconds: 2),
          showAtTop: true,
        );
        print('Error updating favorite status: $e');
      }
    } else {
      // Entry belum disimpan ke DB
      showCustomSnackBar(
        context,
        'Favorit hanya untuk catatan yang sudah disimpan',
        type: SnackBarType.error,
        duration: const Duration(seconds: 2),
        showAtTop: true,
      );
    }
  }

  // --- Fitur insert text, list, label, phone, audio (belum aktif) ---

  @override
  Widget build(BuildContext context) {
    print("Build tampilan emoji: $_selectedEmoji");
    return Scaffold(
      // Scaffold utama halaman detail
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR (putih)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white, // Top bar solid white
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol kembali modern
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Kembali',
                  ),

                  // Tombol aksi (hapus + simpan)
                  Row(
                    children: [
                      if (_entry != null)
                        OutlinedButton.icon(
                          onPressed: _deleteEntry,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'HAPUS',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      if (_entry != null) const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveEntry,
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'SIMPAN',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: 0, // flat style
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // AREA DENGAN BACKGROUND IMAGE
            Expanded(
              child: Container(
                width: double.infinity,
                decoration:
                    _selectedBackground != null &&
                            _selectedBackground!.isNotEmpty
                        ? BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(_selectedBackground!),
                            fit: BoxFit.cover,
                          ),
                        )
                        : const BoxDecoration(color: Color(0xFFDCEEFF)),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tanggal + emoji
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_entryDate!.day}',
                                style: TextStyle(
                                  fontSize: 32,
                                  color: _textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _monthName(_entryDate!.month),
                                    style: GoogleFonts.poppins(
                                      color:
                                          _textColor?.withOpacity(0.8) ??
                                          Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${_entryDate!.year}',
                                    style: GoogleFonts.poppins(
                                      color:
                                          _textColor?.withOpacity(0.8) ??
                                          Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _showEmojiPicker,
                            child: Text(
                              (_selectedEmoji?.isNotEmpty ?? false)
                                  ? _selectedEmoji!
                                  : '🙂',
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Input judul catatan
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Judul',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            color:
                                _textColor?.withOpacity(0.6) ??
                                Colors.black,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Input isi utama catatan
                          TextField(
                            controller: _contentController,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'Tulis lebih banyak di sini...',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                color:
                                    _textColor?.withOpacity(0.6) ?? Colors.grey,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: _textColor,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Render gambar yang sudah diupload
                          ..._uploadedImageUrls.asMap().entries.map((entry) {
                            final index = entry.key;
                            final url = entry.value;
                            print(_uploadedImageUrls);
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        progress,
                                      ) {
                                        if (progress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                progress.expectedTotalBytes !=
                                                        null
                                                    ? progress
                                                            .cumulativeBytesLoaded /
                                                        (progress
                                                                .expectedTotalBytes ??
                                                            1)
                                                    : null,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Center(
                                                child: Text(
                                                  'Gagal memuat gambar',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                                // Tombol hapus gambar
                                Positioned(
                                  top: 10,
                                  right: 6,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _uploadedImageUrls.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          const SizedBox(height: 8),

                          // Input isi di bawah gambar (jika ada gambar)
                          if ((_uploadedImageUrls.isNotEmpty ||
                                  _pickedImages.isNotEmpty ||
                                  _pickedImagesBytes.isNotEmpty) ||
                              _contentBelowController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: TextField(
                                controller: _contentBelowController,
                                maxLines: null,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: _textColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Tulis di bawah gambar...',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color:
                                        _textColor?.withOpacity(0.6) ??
                                        Colors.grey,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom navigation bar untuk fitur tambahan
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Tombol pilih background
            IconButton(
              icon: const Icon(Icons.wallpaper, size: 24),
              onPressed: _showBackgroundPicker,
            ),
            // Tombol upload gambar
            IconButton(
              icon: const Icon(Icons.image, size: 24),
              onPressed: _pickImage,
            ),
            // Tombol favorit
            IconButton(
              icon: Icon(
                (_entry?['is_favorite'] ?? false)
                    ? Icons.star
                    : Icons.star_border,
                color:
                    (_entry?['is_favorite'] ?? false)
                        ? Colors.yellow[700]
                        : Colors.grey,
                size: 24,
              ),
              onPressed: _toggleFavorite,
            ),
            // Tombol pilih emoji
            IconButton(
              icon: const Icon(Icons.emoji_emotions, size: 24),
              onPressed: _showEmojiPicker,
            ),
            // Tombol fitur text field (belum aktif)
            IconButton(
              icon: const Icon(Icons.text_fields, size: 24),
              onPressed: () {
                showCustomSnackBar(
                  context,
                  'Fitur belum tersedia',
                  type: SnackBarType.warning,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              },
            ),
            // Tombol fitur bullet list (belum aktif)
            IconButton(
              icon: const Icon(Icons.format_list_bulleted, size: 24),
              onPressed: () {
                showCustomSnackBar(
                  context,
                  'Fitur belum tersedia',
                  type: SnackBarType.warning,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              },
            ),
            // Tombol fitur label/tag (belum aktif)
            IconButton(
              icon: const Icon(Icons.label_outline, size: 24),
              onPressed: () {
                showCustomSnackBar(
                  context,
                  'Fitur label belum tersedia',
                  type: SnackBarType.warning,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              },
            ),
            // Tombol fitur phone (belum aktif)
            IconButton(
              icon: const Icon(Icons.phone, size: 24),
              onPressed: () {
                showCustomSnackBar(
                  context,
                  'Fitur belum tersedia',
                  type: SnackBarType.warning,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              },
            ),
            // Tombol fitur rekam audio (belum aktif)
            IconButton(
              icon: const Icon(Icons.mic, size: 24),
              onPressed: () {
                showCustomSnackBar(
                  context,
                  'Fitur rekam audio belum tersedia',
                  type: SnackBarType.warning,
                  duration: const Duration(seconds: 2),
                  showAtTop: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
