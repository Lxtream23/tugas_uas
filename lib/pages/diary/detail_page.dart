import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args != null && args is Map) {
      _entry = args;
      _titleController.text = _entry!['title'] ?? '';
      _contentController.text = _entry!['content'] ?? '';
    }
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
        // Tambah baru
        await supabase.from('diary_entries').insert({
          'user_id': user.id,
          'title': title,
          'content': content,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Perbarui
        final id = _entry?['id'];
        if (id == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID catatan tidak ditemukan.')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await supabase
            .from('diary_entries')
            .update({'title': title, 'content': content})
            .eq('id', id);
      }

      if (mounted)
        Navigator.pop(context, true); // kembali ke halaman sebelumnya
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan catatan: $e')));
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
        'created_at': DateTime.now().toIso8601String(),
      });

      _lastDeletedEntry = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengembalikan catatan: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_entry == null ? 'Tambah Catatan' : 'Edit Catatan'),
        actions: [
          if (_entry != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Hapus',
              onPressed: _deleteEntry,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Isi Catatan'),
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveEntry,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_entry == null ? 'Simpan' : 'Perbarui'),
            ),
          ],
        ),
      ),
    );
  }
}
