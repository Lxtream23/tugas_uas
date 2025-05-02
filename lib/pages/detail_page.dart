import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final supabase = Supabase.instance.client;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isLoading = false;
  Map? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entry = ModalRoute.of(context)!.settings.arguments as Map?;

    if (_entry != null && _entry!.isNotEmpty) {
      _titleController.text = _entry!['title'] ?? '';
      _contentController.text = _entry!['content'] ?? '';
    }
  }

  Future<void> _saveEntry() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (_entry != null && _entry!.isNotEmpty) {
      // Update
      await supabase
          .from('diary_entries')
          .update({
            'title': title,
            'content': content,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _entry!['id']);
    } else {
      // Insert
      await supabase.from('diary_entries').insert({
        'user_id': user.id,
        'title': title,
        'content': content,
      });
    }

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteEntry() async {
    if (_entry == null || _entry!['id'] == null) return;

    final confirm = await showDialog(
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

    if (confirm == true) {
      await supabase.from('diary_entries').delete().eq('id', _entry!['id']);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _entry != null && _entry!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Catatan' : 'Catatan Baru'),
        actions: [
          if (isEditing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteEntry),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 12),
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
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  onPressed: _saveEntry,
                  label: const Text('Simpan'),
                ),
          ],
        ),
      ),
    );
  }
}
