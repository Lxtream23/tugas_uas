import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentBelowController = TextEditingController();

  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map? _entry;
  Map<String, dynamic>? _lastDeletedEntry;
  String? _selectedEmoji; // null kalau belum dipilih
  String? _selectedBackground; // null = default background
  //String? _entryId;
  Color _textColor = Colors.black; // Default text color

  List<File> _pickedImages = []; // List to store picked images
  List<Uint8List> _pickedImagesBytes = []; // For web support
  List<String> _uploadedImageUrls = []; // URLs of uploaded images

  bool _isInitialized = false;
  DateTime? _entryDate;

  late AnimationController _dateController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args != null && args is Map) {
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
            _entry?['content_below'] ?? ''; // Ambil content_below kalau ada
        _uploadedImageUrls =
            (_entry!['image_urls'] as List<dynamic>?)
                ?.map((url) => url.toString())
                .toList() ??
            [];

        // Ambil tanggal entry, kalau tidak ada gunakan sekarang
        _entryDate =
            DateTime.tryParse(_entry!['created_at'] ?? '') ?? DateTime.now();
      } else {
        _entryDate = DateTime.now();
      }
      _isInitialized = true;
    }

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

    // Start the animation
    _dateController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentBelowController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User tidak ditemukan. Silakan login ulang.'),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi tidak boleh kosong')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
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
        await supabase.from('diary_entries').insert(data);
      } else {
        final id = _entry?['id'];
        if (id == null) throw Exception('ID catatan tidak ditemukan');

        final updateData = Map.of(data);
        updateData.remove('user_id');
        updateData.remove('created_at');

        await supabase.from('diary_entries').update(updateData).eq('id', id);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan catatan: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry() async {
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
      _lastDeletedEntry = Map<String, dynamic>.from(_entry!);
      await supabase.from('diary_entries').delete().eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Catatan dihapus'),
            action: SnackBarAction(label: 'Undo', onPressed: _undoDelete),
            duration: const Duration(seconds: 5),
          ),
        );

        Navigator.pop(context, true); // kembali ke halaman sebelumnya
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus catatan: $e')));
    }
  }

  Future<void> _undoDelete() async {
    final userId = supabase.auth.currentUser?.id;

    if (_lastDeletedEntry == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal undo: pengguna tidak ditemukan')),
      );
      return;
    }

    try {
      await supabase.from('diary_entries').insert({
        'user_id': userId,
        'title': _lastDeletedEntry!['title'],
        'content': _lastDeletedEntry!['content'],
        'emoji': _lastDeletedEntry!['emoji'], // kembalikan emoji kalau ada
        'background':
            _lastDeletedEntry!['background'] ??
            '', // kembalikan background kalau ada
        'text_color': _lastDeletedEntry!['text_color'] ?? 'black',
        'content_below': _lastDeletedEntry!['content_below'] ?? '',
        'image_urls': _lastDeletedEntry!['image_urls'] ?? [],
        'created_at': DateTime.now().toIso8601String(),
      });

      _lastDeletedEntry = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengembalikan catatan: $e')),
      );
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final emojis = [
          '😀',
          '😎',
          '😊',
          '😍',
          '🤩',
          '😢',
          '😭',
          '😡',
          '🤔',
          '😴',
          '😇',
          '🥳',
          '🤯',
          '😱',
          '🤤',
          '😬',
          '🙄',
          '😌',
          '💀',
          '👻',
          '🤗',
          '🥰',
          '😅',
          '🤪',
          '😷',
          '😤',
          '🤫',
          '🤮',
          '😈',
          '👽',
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

  String _formatDate(DateTime date) {
    // Format sesuai kebutuhan, misal: 14 Juni 2025
    return "${date.day} ${_monthName(date.month)} ${date.year}";
  }

  String _monthName(int month) {
    const bulan = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return bulan[month];
  }

  void _showBackgroundPicker() {
    final backgrounds = [
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

                  // Tampilkan loading dulu
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) =>
                            const Center(child: CircularProgressIndicator()),
                  );

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User tidak ditemukan, silakan login ulang'),
          ),
        );
        return;
      }
      print(supabase.auth.currentUser);

      final safeName = pickedFile.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9_\-\.]'),
        '',
      );
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final storage = Supabase.instance.client.storage.from('diaryimages');
      final fileBytes = await pickedFile.readAsBytes();

      try {
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar berhasil diupload')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal upload gambar: $e')));
      }
    }
  }

  void _toggleFavorite() {
    // Toggle status favorit pada _entry (misal: tambahkan field is_favorite)
    setState(() {
      if (_entry != null) {
        _entry!['is_favorite'] = !(_entry!['is_favorite'] ?? false);
      } else {
        // Untuk entry baru, bisa tampilkan pesan atau simpan status lokal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorit hanya untuk catatan yang sudah disimpan'),
          ),
        );
      }
    });
  }

  void _insertTextField() {
    // Menyisipkan placeholder [text_field] di posisi kursor
    final text = _contentController.text;
    final selection = _contentController.selection;
    const field = '\n[text_field]\n';
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      field,
    );
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + field.length,
    );
  }

  void _insertList() {
    // Menyisipkan bullet list di posisi kursor
    final text = _contentController.text;
    final selection = _contentController.selection;
    const list = '\n• Item 1\n• Item 2\n';
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      list,
    );
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + list.length,
    );
  }

  void _assignLabel() {
    // Menyisipkan label/tag di posisi kursor
    final text = _contentController.text;
    final selection = _contentController.selection;
    const label = '\n#label\n';
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      label,
    );
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + label.length,
    );
  }

  void _savePhoneNumber() {
    // Menyisipkan placeholder nomor telepon di posisi kursor
    final text = _contentController.text;
    final selection = _contentController.selection;
    const phone = '\n[phone: 08xxxxxxxxxx]\n';
    _contentController.text = text.replaceRange(
      selection.start,
      selection.end,
      phone,
    );
    _contentController.selection = TextSelection.collapsed(
      offset: selection.start + phone.length,
    );
  }

  // void _recordAudio() {
  //   // Menyisipkan placeholder audio di posisi kursor
  //   final text = _contentController.text;
  //   final selection = _contentController.selection;
  //   const audio = '\n[audio]\n';
  //   _contentController.text = text.replaceRange(
  //     selection.start,
  //     selection.end,
  //     audio,
  //   );
  //   _contentController.selection = TextSelection.collapsed(
  //     offset: selection.start + audio.length,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    print("Build tampilan emoji: $_selectedEmoji");
    return Scaffold(
      //resizeToAvoidBottomInset: false,  // Agar tidak mengganggu tampilan saat keyboard muncul
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
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Judul',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            color:
                                _textColor?.withOpacity(0.6) ??
                                Colors.black, // hint lebih transparan
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
                      // TextField(
                      //   controller: _contentController,
                      //   maxLines: null,
                      //   decoration: const InputDecoration(
                      //     hintText: 'Tulis lebih banyak di sini...',
                      //     border: InputBorder.none,
                      //     isDense: true,
                      //     contentPadding: EdgeInsets.zero,
                      //   ),
                      //   style: GoogleFonts.poppins(
                      //     fontSize: 16,
                      //     color: _textColor,
                      //   ),
                      // ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Render TextField untuk isi atas (selalu ada)
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

                          // Render gambar + tombol hapus
                          // Render gambar dari _uploadedImageUrls (URL dari Supabase Storage)
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

                          // Render content_below kalau ada gambar
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
            IconButton(
              icon: const Icon(Icons.wallpaper, size: 24),
              onPressed: _showBackgroundPicker,
            ),
            IconButton(
              icon: const Icon(Icons.image, size: 24),
              onPressed: _pickImage,
            ),
            IconButton(
              icon: const Icon(Icons.star_border, size: 24),
              onPressed: _toggleFavorite,
            ),
            IconButton(
              icon: const Icon(Icons.emoji_emotions, size: 24),
              onPressed: _showEmojiPicker,
            ),
            IconButton(
              icon: const Icon(Icons.text_fields, size: 24),
              onPressed: _insertTextField,
            ),
            IconButton(
              icon: const Icon(Icons.format_list_bulleted, size: 24),
              onPressed: _insertList,
            ),
            IconButton(
              icon: const Icon(Icons.label_outline, size: 24),
              onPressed: _assignLabel,
            ),
          ],
        ),
      ),
    );
  }
}
// appBar: AppBar(
      //   title: Text(_entry == null ? 'Tambah Catatan' : 'Edit Catatan'),

      //   // actions: [
      //   //   if (_entry != null)
      //   //     IconButton(
      //   //       icon: const Icon(Icons.delete),
      //   //       tooltip: 'Hapus',
      //   //       onPressed: _deleteEntry,
      //   //     ),
      //   // ],
      // ),
      // Tombol simpan
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     onPressed: _isLoading ? null : _saveEntry,
            //     child:
            //         _isLoading
            //             ? const CircularProgressIndicator()
            //             : Text(_entry == null ? 'Simpan' : 'Perbarui'),

            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: const Color(0xFF6C63FF),
            //       padding: const EdgeInsets.symmetric(vertical: 16),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(12),
            //       ),
            //     ),
            //   ),
            // ),