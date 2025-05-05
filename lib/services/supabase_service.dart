import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diary_entry.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Auth
  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Fetch all diary entries for the current user
  Future<List<DiaryEntry>> getDiaryEntries() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('diary_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((entry) => DiaryEntry.fromMap(entry))
        .toList();
  }

  /// Insert new diary entry
  Future<void> addDiaryEntry(String title, String content) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client.from('diary_entries').insert({
      'user_id': userId,
      'title': title,
      'content': content,
    });
  }

  /// Update existing diary entry
  Future<void> updateDiaryEntry(String id, String title, String content) async {
    await _client
        .from('diary_entries')
        .update({
          'title': title,
          'content': content,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Delete diary entry
  Future<void> deleteDiaryEntry(String id) async {
    await _client.from('diary_entries').delete().eq('id', id);
  }
}
