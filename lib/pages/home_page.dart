import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/services/supabase_service.dart';
import 'package:tugas_uas/models/diary_entry.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabaseService = SupabaseService();
  final supabase = Supabase.instance.client;
  List<DiaryEntry> diaryEntries = [];
  List<DiaryEntry> filteredEntries = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDiaryEntries();
    _searchController.addListener(_filterDiaryEntries);
  }

  //void fetchData() async {
  //  final entries = await supabaseService.getDiaryEntries();
  //  setState(() {
  //    diaryEntries = entries;
  //  });
  // }

  Future<void> _fetchDiaryEntries() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      // Jika user tidak terautentikasi, arahkan ke halaman login
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final response = await supabase
        .from('diary_entries')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;

    setState(() {
      diaryEntries =
          data
              .map((item) => DiaryEntry.fromMap(item as Map<String, dynamic>))
              .toList();
      filteredEntries = List.from(diaryEntries);
      isLoading = false;
    });
  }

  void _filterDiaryEntries() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      filteredEntries =
          diaryEntries
              .where((entry) => entry.title.toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _logout() async {
    setState(() => isLoading = true);
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _goToDetail(DiaryEntry? entry) {
    if (entry == null) {
      // Tambah baru
      Navigator.pushNamed(context, '/detail').then((_) {
        _fetchDiaryEntries();
      });
    } else {
      // Edit
      Navigator.pushNamed(
        context,
        '/detail',
        arguments: {
          'id': entry.id,
          'title': entry.title,
          'content': entry.content,
          'created_at': entry.createdAt.toIso8601String(),
        },
      ).then((_) {
        _fetchDiaryEntries();
      });
    }
  }

  void _goToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Harian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile-form');
            },
          ), // Arahkan ke ProfileFormPage
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _goToSettings,
          ), // Arahkan ke SettingsPage
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ), // Arahkan ke halaman login
        ],
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
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredEntries.isEmpty
              ? const Center(child: Text('Tidak ada catatan yang cocok.'))
              : Expanded(
                child: ListView.builder(
                  itemCount: filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    return Card(
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
                    );
                  },
                ),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => _goToDetail(null), // kirim null untuk tambah catatan baru
        child: const Icon(Icons.add),
      ),
    );
  }
}
