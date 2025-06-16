import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map? _entry;
  Map<String, dynamic>? _lastDeletedEntry;
  String? _selectedEmoji; // null kalau belum dipilih
  //String? _entryId;

  bool _isInitialized = false;

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
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
      if (_entry == null) {
        // INSERT BARU
        await supabase.from('diary_entries').insert({
          'user_id': user.id,
          'title': title,
          'content': content,
          'emoji': _selectedEmoji ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // UPDATE
        final id = _entry?['id'];
        if (id == null) throw Exception('ID catatan tidak ditemukan');
        print({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'emoji': _selectedEmoji ?? '',
        });
        print('ID: ${_entry?['id']}');
        await supabase
            .from('diary_entries')
            .update({
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
              'emoji': _selectedEmoji ?? '',
              //'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _entry?['id']);
        //print({'title': title, 'content': content, 'emoji': _selectedEmoji});
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

  @override
  Widget build(BuildContext context) {
    print("Build tampilan emoji: $_selectedEmoji");

    return Scaffold(
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
      backgroundColor: const Color(0xFFDCEEFF), // biru muda
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bar atas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // Text(
                      //   _entry == null ? 'Tambah Catatan' : 'Edit Catatan',
                      //   style: const TextStyle(
                      //     fontSize: 20,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'SIMPAN',
                                  style: TextStyle(color: Colors.white),
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Tanggal
                  Row(
                    children: const [
                      Text(
                        '14',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Jun 2025',
                        style: TextStyle(fontSize: 20, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Judul
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Judul',
                      border: InputBorder.none,
                    ),
                  ),
                  // Isi catatan
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Tulis lebih banyak di sini...',
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            // Emoji mood
            Positioned(
              top: 60,
              right: 16,
              child: GestureDetector(
                onTap: _showEmojiPicker,
                child: Text(
                  //_selectedEmoji ?? '🙂', // default tampilan
                  (_selectedEmoji != null && _selectedEmoji!.isNotEmpty)
                      ? _selectedEmoji!
                      : '🙂',
                  style: const TextStyle(
                    fontSize: 40, // Besar emoji, bisa kamu sesuaikan
                  ),
                ),
              ),
            ),

            // Bottom bar icon
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.line_weight),
                    Icon(Icons.image),
                    Icon(Icons.star_border),
                    Icon(Icons.emoji_emotions),
                    Icon(Icons.text_fields),
                    Icon(Icons.format_list_bulleted),
                    Icon(Icons.label_outline),
                    Icon(Icons.call),
                    Icon(Icons.mic),
                  ],
                ),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}
