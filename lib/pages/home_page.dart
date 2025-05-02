import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  List<dynamic> diaryEntries = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDiaryEntries();
  }

  Future<void> _fetchDiaryEntries() async {
    final userId = supabase.auth.currentUser?.id;

    final response = await supabase
        .from('diary_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    setState(() {
      diaryEntries = response;
      isLoading = false;
    });
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _goToDetail(Map entry) {
    Navigator.pushNamed(context, '/detail', arguments: entry).then((_) {
      // Refresh list saat kembali dari detail
      _fetchDiaryEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Harian'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : diaryEntries.isEmpty
              ? const Center(child: Text('Belum ada catatan.'))
              : ListView.builder(
                itemCount: diaryEntries.length,
                itemBuilder: (context, index) {
                  final entry = diaryEntries[index];
                  return ListTile(
                    title: Text(entry['title'] ?? 'Tanpa Judul'),
                    subtitle: Text(entry['created_at']),
                    onTap: () => _goToDetail(entry),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToDetail({}), // Entry kosong untuk catatan baru
        child: const Icon(Icons.add),
      ),
    );
  }
}
