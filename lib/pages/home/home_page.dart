import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/diary_entry.dart';
import '../../services/notification_service.dart';
import '../../services/backup_service.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  final void Function(ThemeMode)? onThemeChanged;

  const HomePage({Key? key, this.onThemeChanged}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  bool _isSearching = false;
  List<DiaryEntry> diaryEntries = [];
  List<DiaryEntry> filteredEntries = [];
  final _searchController = TextEditingController();
  bool isLoading = true;
  DiaryEntry? _lastDeletedEntry;
  bool _showChallenge = true;
  int _challengeProgress = 1; // misal, 1 dari 3 hari

  double get _progress => _challengeProgress / 3;

  Color getProgressColor(double value) {
    if (value >= 1.0) return Colors.green;
    if (value >= 0.5) return Colors.orange;
    if (value > 0.0) return Colors.red;
    return Colors.grey;
  }

  String _sortBy = 'terbaru'; // nilai default

  @override
  void initState() {
    super.initState();
    _fetchDiaryEntries();
    _searchController.addListener(_onSearchChanged);
    _loadChallengeProgress();
    _loadChallengePrefs();
    _loadSortPreference();
    _cekBackupOtomatis();
    _cekBackupOtomatisSekaliSehari();
  }

  Future<void> _cekBackupOtomatis() async {
    await Future.delayed(const Duration(seconds: 2)); // ✅ Delay 2 detik
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final aktif = prefs.getBool('backup_otomatis') ?? false;

    if (aktif) {
      await BackupService.generateBackupJson(context);
    }
  }

  Future<void> _cekBackupOtomatisSekaliSehari() async {
    final prefs = await SharedPreferences.getInstance();
    final aktif = prefs.getBool('backup_otomatis') ?? false;

    if (!aktif) return;

    // Ambil tanggal terakhir backup
    final lastBackup = prefs.getString('last_backup_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastBackup != today) {
      // Tambahkan delay opsional
      await Future.delayed(const Duration(seconds: 2));

      // Jalankan backup
      await BackupService.generateBackupJson(context);

      // Simpan tanggal hari ini
      prefs.setString('last_backup_date', today);

      // (Opsional) Tampilkan notifikasi sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Backup otomatis berhasil')),
      );
    }
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
              'emoji': entry.emoji,
              'background': entry.background,
              'text_color': entry.textColor ?? 'black',
              'created_at': entry.createdAt.toIso8601String(),
            };

    Navigator.pushNamed(context, '/detail', arguments: args).then((
      result,
    ) async {
      if (result == true) {
        await Future.delayed(const Duration(milliseconds: 300));
        _fetchDiaryEntries();

        if (_challengeProgress < 3) {
          setState(() => _challengeProgress += 1);
          _saveChallengePrefs();

          if (_challengeProgress == 3) {
            await NotificationService.showChallengeCompleted();
          }
        }
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
        'emoji': _lastDeletedEntry!.emoji,
        'background': _lastDeletedEntry!.background,
        'text_color': _lastDeletedEntry!.textColor ?? 'black',
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

  void _loadChallengeProgress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _challengeProgress = prefs.getInt('challenge_progress') ?? 1;
    });
  }

  void _loadChallengePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showChallenge = prefs.getBool('show_challenge') ?? true;
      _challengeProgress = prefs.getInt('challenge_progress') ?? 1;
    });
  }

  Future<void> _saveChallengePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_challenge', _showChallenge);
    await prefs.setInt('challenge_progress', _challengeProgress);
  }

  void _showSortDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sort Dialog',
      barrierColor: Colors.black54, // efek gelap di background
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return const SizedBox(); // kita render dialog di transitionBuilder
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: curvedAnimation,
            child: Center(
              child: Material(
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                color: Colors.white,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Sortir Catatan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          leading: const Icon(Icons.arrow_downward),
                          title: const Text('Terbaru'),
                          trailing:
                              _sortBy == 'terbaru'
                                  ? const Icon(Icons.check)
                                  : null,
                          onTap: () {
                            Navigator.pop(context);
                            _applySort('terbaru');
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.arrow_upward),
                          title: const Text('Terlama'),
                          trailing:
                              _sortBy == 'terlama'
                                  ? const Icon(Icons.check)
                                  : null,
                          onTap: () {
                            Navigator.pop(context);
                            _applySort('terlama');
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.sort_by_alpha),
                          title: const Text('Judul'),
                          trailing:
                              _sortBy == 'judul'
                                  ? const Icon(Icons.check)
                                  : null,
                          onTap: () {
                            Navigator.pop(context);
                            _applySort('judul');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _applySort(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      filteredEntries = [...diaryEntries];

      if (sortBy == 'terbaru') {
        filteredEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (sortBy == 'terlama') {
        filteredEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else if (sortBy == 'judul') {
        filteredEntries.sort((a, b) => a.title.compareTo(b.title));
      }
    });

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('sort_by', sortBy);
    });
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final sortBy = prefs.getString('sort_by') ?? 'terbaru';
    _applySort(sortBy);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Catatan Saya')),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(180),
        child: Stack(
          children: [
            Container(
              height: 180,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/header_mountain.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title:
                  _isSearching
                      ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari catatan...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => _onSearchChanged(),
                      )
                      : Text(
                        'Catatan Saya',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 20,
                          //fontWeight: FontWeight.bold,
                        ),
                      ),
              leading:
                  _isSearching
                      ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                            filteredEntries = diaryEntries;
                          });
                        },
                      )
                      : Builder(
                        builder:
                            (context) => IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed:
                                  () => Scaffold.of(context).openDrawer(),
                            ),
                      ),
              actions: [
                if (!_isSearching)
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black),
                  onSelected: (value) async {
                    if (value == 'backup') {
                      //print('📦 Cadangkan data');
                      Navigator.pushNamed(context, '/backup');
                    } else if (value == 'sort') {
                      // ⬇️ Tampilkan submenu sortir
                      final RenderBox overlay =
                          Overlay.of(context).context.findRenderObject()
                              as RenderBox;

                      final result = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          overlay.size.width - 40,
                          kToolbarHeight + 50,
                          0,
                          0,
                        ),
                        items: [
                          PopupMenuItem(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            value: 'sort_latest',
                            child: IntrinsicWidth(
                              // Gunakan IntrinsicWidth untuk menghindari overflow
                              child: SizedBox(
                                width: 220, // Atur sesuai kebutuhan
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⬇️ '),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sortir: Terbaru',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                      overflow:
                                          TextOverflow
                                              .visible, // Pastikan teks bisa tampil penuh
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            value: 'sort_oldest',
                            child: IntrinsicWidth(
                              // Gunakan IntrinsicWidth untuk menghindari overflow
                              child: SizedBox(
                                width: 220, // Atur sesuai kebutuhan
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⬆️ '),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sortir: Terlama',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                      overflow:
                                          TextOverflow
                                              .visible, // Pastikan teks bisa tampil penuh
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            value: 'sort_title',
                            child: IntrinsicWidth(
                              child: SizedBox(
                                width: 220, // Atur sesuai kebutuhan
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🔤 '),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sortir: Judul',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                      overflow:
                                          TextOverflow
                                              .visible, // Pastikan teks bisa tampil penuh
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        elevation: 10,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );

                      if (result == 'sort_latest') {
                        setState(() {
                          filteredEntries.sort(
                            (a, b) => b.createdAt.compareTo(a.createdAt),
                          );
                        });
                      } else if (result == 'sort_oldest') {
                        setState(() {
                          filteredEntries.sort(
                            (a, b) => a.createdAt.compareTo(b.createdAt),
                          );
                        });
                      } else if (result == 'sort_title') {
                        setState(() {
                          filteredEntries.sort(
                            (a, b) => a.title.compareTo(b.title),
                          );
                        });
                      }
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'backup',
                          child: Text(
                            'Cadangan',
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          onTap:
                              () => Future.delayed(
                                Duration.zero,
                                () => _showSortDialog(context),
                              ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sortir dengan',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ],
        ),
      ),
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
          //wigdet Tantangan
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                _showChallenge
                    ? Padding(
                      key: const ValueKey('challenge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tantangan Kebiasaan 3 Hari',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tulis jurnal selama 3 hari berturut-turut',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: _progress,
                                    ),
                                    duration: const Duration(milliseconds: 500),
                                    builder: (context, value, _) {
                                      return LinearProgressIndicator(
                                        value: value,
                                        backgroundColor: Colors.grey[200],
                                        color: getProgressColor(value),
                                        minHeight: 6,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Progress: $_challengeProgress / 3',
                                    style: GoogleFonts.poppins(
                                      color: getProgressColor(_progress),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _showChallenge = false);
                                _saveChallengePrefs();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
          // List Catatan
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredEntries.isEmpty
                    ? Center(
                      child: Text(
                        'Tidak ada catatan',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    )
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
                                    title: Text(
                                      'Hapus Catatan',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black,
                                        fontSize: 18,
                                      ),
                                    ),
                                    content: Text(
                                      'Yakin ingin menghapus catatan ini?',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: Text(
                                          'Batal',
                                          style: GoogleFonts.poppins(
                                            color: Colors.blue,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: Text(
                                          'Hapus',
                                          style: GoogleFonts.poppins(
                                            color: Colors.red,
                                            fontSize: 16,
                                          ),
                                        ),
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
