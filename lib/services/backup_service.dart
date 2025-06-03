import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupService {
  /// Backup: Android/iOS → simpan ke file
  ///         Web → unduh JSON
  static Future<void> generateBackupJson(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      final response = await Supabase.instance.client
          .from('diary_entries')
          .select()
          .eq('user_id', user.id);

      final jsonString = jsonEncode(response);
      final filename =
          'backup_diary_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', filename)
              ..click();
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ File berhasil diunduh')),
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsString(jsonString);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File tersimpan di: ${file.path}')),
        );
      }
    } catch (e) {
      print('❌ Gagal backup: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Gagal backup: $e')));
    }
  }

  /// Restore: pilih file → pulihkan ke Supabase
  static Future<void> restoreBackup(BuildContext context) async {
    if (kIsWeb) {
      await _restoreFromBackupWeb(context);
    } else {
      await _restoreFromBackupMobile(context);
    }
  }

  // Android/iOS
  static Future<void> _restoreFromBackupMobile(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('Tidak ada file dipilih');
      }

      final filePath = result.files.first.path;
      if (filePath == null) throw Exception('Path file tidak ditemukan');
      final file = File(filePath);
      final contents = await file.readAsString();
      final List<dynamic> data = jsonDecode(contents);

      await _uploadToSupabase(data, user.id, context);
    } catch (e) {
      print('❌ Gagal restore (mobile): $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Gagal pulihkan: $e')));
    }
  }

  // Web
  static Future<void> _restoreFromBackupWeb(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      final uploadInput = html.FileUploadInputElement()..accept = '.json';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files == null || files.isEmpty) return;

        final reader = html.FileReader();
        reader.readAsText(files.first);

        reader.onLoadEnd.listen((e) async {
          final contents = reader.result as String;
          final List<dynamic> data = jsonDecode(contents);
          await _uploadToSupabase(data, user.id, context);
        });
      });
    } catch (e) {
      print('❌ Gagal restore (web): $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Gagal pulihkan: $e')));
    }
  }

  // Upload data JSON ke Supabase
  static Future<void> _uploadToSupabase(
    List<dynamic> data,
    String userId,
    BuildContext context,
  ) async {
    for (final item in data) {
      await Supabase.instance.client.from('diary_entries').upsert({
        'id': item['id'],
        'user_id': userId,
        'title': item['title'],
        'content': item['content'],
        'created_at': item['created_at'],
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Data berhasil dipulihkan')));
  }
}
