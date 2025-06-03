import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupService {
  // ✅ Backup ke file JSON
  static Future<File?> generateBackupJson() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      final response = await Supabase.instance.client
          .from('diary_entries')
          .select()
          .eq('user_id', user.id);

      final jsonString = jsonEncode(response);
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/backup_diary_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonString);
      return file;
    } catch (e) {
      print('❌ Gagal backup: $e');
      return null;
    }
  }

  // ✅ Restore dari file JSON
  static Future<void> restoreFromBackupJson(File file) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final jsonString = await file.readAsString();
      final List<dynamic> data = jsonDecode(jsonString);

      // Opsional: hapus semua data lama
      await Supabase.instance.client
          .from('diary_entries')
          .delete()
          .eq('user_id', user.id);

      for (final entry in data) {
        await Supabase.instance.client.from('diary_entries').insert({
          'title': entry['title'],
          'content': entry['content'],
          'user_id': user.id,
          'created_at': entry['created_at'],
        });
      }

      print('✅ Berhasil memulihkan ${data.length} catatan');
    } catch (e) {
      print('❌ Gagal restore: $e');
    }
  }
}
