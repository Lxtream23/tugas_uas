import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diary_entry.dart';

class HomePage extends StatefulWidget {
  final void Function(ThemeMode)? onThemeChanged;

  const HomePage({Key? key, this.onThemeChanged}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  List<DiaryEntry> diaryEntries = [];
  List<DiaryEntry> filteredEntries = [];
  final _searchController = TextEditingController();
  bool isLoading = true;
  DiaryEntry? _lastDeletedEntry;

  @override
  void initState() {
    super.initState();
    _fetchDiaryEntries();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchDiaryEntries() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        diaryEntries = [];
        filteredEntries = [];
      });
      return;
    }

    final response = await supabase
        .from('diary_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final data = List<Map<String, dynamic>>.from(response);

    if (!mounted) return;
    setState(() {
      diaryEntries = data.map((e) => DiaryEntry.fromMap(e)).toList();
      filteredEntries = diaryEntries;
      isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredEntries =
          diaryEntries
              .where((entry) => entry.title.toLowerCase().contains(query))
              .toList();
    });
  }

  void _goToDetail(DiaryEntry? entry) {
    final args =
        entry == null
            ? null
            : {
              'id': entry.id,
              'title': entry.title,
              'content': entry.content,
              'created_at': entry.createdAt.toIso8601String(),
            };

    Navigator.pushNamed(context, '/detail', arguments: args).then((
      result,
    ) async {
      if (result == true) {
        await Future.delayed(const Duration(milliseconds: 300));
        _fetchDiaryEntries();
      }
    });
  }

  Future<void> _deleteDiaryEntry(String id) async {
    try {
      final deleted = diaryEntries.firstWhere((e) => e.id == id);
      _lastDeletedEntry = deleted;

      await supabase.from('diary_entries').delete().eq('id', id);
      if (!mounted) return;
      _fetchDiaryEntries();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Catatan dihapus'),
          action: SnackBarAction(label: 'Undo', onPressed: _undoDelete),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus catatan: $e')));
    }
  }

  Future<void> _undoDelete() async {
    final userId = supabase.auth.currentUser?.id;
    if (_lastDeletedEntry == null || userId == null) return;

    try {
      await supabase.from('diary_entries').insert({
        'user_id': userId,
        'title': _lastDeletedEntry!.title,
        'content': _lastDeletedEntry!.content,
        'created_at': DateTime.now().toIso8601String(),
      });
      _fetchDiaryEntries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengembalikan catatan: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catatan Saya')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pushNamed(context, '/profile-form');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Pengaturan'),
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Keluar'),
              onTap: () async {
                await supabase.auth.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Cari berdasarkan judul...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredEntries.isEmpty
                    ? const Center(child: Text('Tidak ada catatan'))
                    : ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return Dismissible(
                          key: Key(entry.id),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder:
                                  (_) => AlertDialog(
                                    title: const Text('Hapus Catatan'),
                                    content: const Text(
                                      'Yakin ingin menghapus catatan ini?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                          onDismissed: (_) => _deleteDiaryEntry(entry.id),
                          child: Card(
                            margin: const EdgeInsets.all(8),
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(entry.title),
                              subtitle: Text(entry.createdAt.toString()),
                              onTap: () => _goToDetail(entry),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToDetail(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
