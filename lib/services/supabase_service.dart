import 'package:supabase_flutter/supabase_flutter.dart'; // Import package Supabase untuk Flutter
import '../models/diary_entry.dart'; // Import model DiaryEntry

// Kelas service untuk mengelola operasi Supabase terkait autentikasi dan data diary
class SupabaseService {
  // Inisialisasi SupabaseClient dari instance Supabase yang sudah dikonfigurasi
  final SupabaseClient _client = Supabase.instance.client;

  /// =========================
  /// Bagian Autentikasi (Auth)
  /// =========================

  /// Fungsi untuk login user menggunakan email dan password
  /// Mengembalikan AuthResponse dari Supabase
  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Fungsi untuk mendaftarkan user baru menggunakan email dan password
  /// Mengembalikan AuthResponse dari Supabase
  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Fungsi untuk logout user yang sedang aktif
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Getter untuk mengambil user id dari user yang sedang login
  /// Jika belum login, akan mengembalikan null
  String? get currentUserId => _client.auth.currentUser?.id;

  /// ==========================================================
  /// Bagian CRUD untuk data diary_entries pada user yang aktif
  /// ==========================================================

  /// Mengambil semua data diary milik user yang sedang login
  /// Data diurutkan berdasarkan waktu pembuatan terbaru
  /// Jika user belum login, mengembalikan list kosong
  Future<List<DiaryEntry>> getDiaryEntries() async {
    final userId = currentUserId;
    if (userId == null) return []; // Jika belum login, return list kosong

    // Query ke tabel diary_entries, filter berdasarkan user_id, urutkan berdasarkan created_at descending
    final response = await _client
        .from('diary_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    // Mapping hasil query ke list DiaryEntry
    return (response as List<dynamic>)
        .map((entry) => DiaryEntry.fromMap(entry))
        .toList();
  }

  /// Menambahkan data diary baru ke tabel diary_entries
  /// Hanya bisa dilakukan jika user sudah login
  Future<void> addDiaryEntry(String title, String content) async {
    final userId = currentUserId;
    if (userId == null) return; // Jika belum login, tidak melakukan apa-apa

    // Insert data baru ke tabel diary_entries
    await _client.from('diary_entries').insert({
      'user_id': userId,
      'title': title,
      'content': content,
    });
  }

  /// Mengupdate data diary yang sudah ada berdasarkan id
  /// Mengubah title, content, dan updated_at
  Future<void> updateDiaryEntry(String id, String title, String content) async {
    await _client
        .from('diary_entries')
        .update({
          'title': title, // Update judul
          'content': content, // Update isi
          'updated_at': DateTime.now().toIso8601String(), // Update waktu terakhir diubah
        })
        .eq('id', id); // Filter berdasarkan id diary yang ingin diupdate
  }

  /// Menghapus data diary berdasarkan id
  Future<void> deleteDiaryEntry(String id) async {
    await _client.from('diary_entries').delete().eq('id', id); // Hapus entry dengan id tertentu
  }
}
