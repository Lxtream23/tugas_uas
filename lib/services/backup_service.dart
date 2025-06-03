import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';

class BackupService {
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
        // ✅ WEB: Unduh file via anchor
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
        // ✅ ANDROID / iOS / macOS
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsString(jsonString);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File tersimpan di ${file.path}')),
        );
      }
    } catch (e) {
      print('❌ Gagal backup: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Gagal backup: $e')));
    }
  }

  static Future<void> restoreFromBackupJson(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb, // WEB: baca bytes
      );

      if (result == null) throw Exception('Tidak ada file dipilih');

      String jsonContent;

      if (kIsWeb) {
        // ✅ WEB: Ambil dari bytes
        final bytes = result.files.first.bytes;
        if (bytes == null) throw Exception('Gagal baca file');
        jsonContent = utf8.decode(bytes);
      } else {
        // ✅ ANDROID: Baca dari path
        final filePath = result.files.first.path;
        if (filePath == null) throw Exception('Path file tidak ditemukan');
        final file = File(filePath);
        jsonContent = await file.readAsString();
      }

      final List<dynamic> data = jsonDecode(jsonContent);

      for (final item in data) {
        await Supabase.instance.client.from('diary_entries').upsert({
          'id': item['id'],
          'user_id': user.id,
          'title': item['title'],
          'content': item['content'],
          'created_at': item['created_at'],
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Data berhasil dipulihkan')),
      );
    } catch (e) {
      print('❌ Gagal pulihkan data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Gagal pulihkan: $e')));
    }
  }
}
