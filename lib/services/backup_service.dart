import 'dart:convert'; // Untuk encoding dan decoding JSON
import 'dart:io' show File, Platform; // Untuk operasi file di platform non-web
import 'package:flutter/material.dart'; // Untuk widget dan context Flutter
import 'package:flutter/foundation.dart'
    show kIsWeb; // Untuk deteksi platform web
import 'package:universal_html/html.dart' as html; // Untuk operasi file di web
import 'package:path_provider/path_provider.dart'; // Untuk mendapatkan direktori aplikasi
import 'package:file_picker/file_picker.dart'; // Untuk memilih file dari device
import 'package:supabase_flutter/supabase_flutter.dart'; // Untuk koneksi ke Supabase
import 'package:shared_preferences/shared_preferences.dart'; // Untuk penyimpanan lokal sederhana
import 'package:tugas_uas/services/google_drive_helper.dart'; // Helper upload ke Google Drive
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar untuk notifikasi

/// Service untuk backup dan restore data diary ke/dari file JSON dan Supabase
class BackupService {
  /// Membuat file backup JSON dari data diary user
  /// - Android/iOS: simpan file ke storage lokal
  /// - Web: unduh file JSON
  static Future<File?> generateBackupJson(BuildContext? context) async {
    try {
      // Ambil user yang sedang login dari Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      // Ambil data diary_entries milik user dari Supabase
      final response = await Supabase.instance.client
          .from('diary_entries')
          .select()
          .eq('user_id', user.id);

      // Encode data ke JSON string
      final jsonString = jsonEncode(response);
      // Buat nama file backup dengan timestamp
      final filename =
          'backup_diary_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        // Jika di web, buat file blob dan trigger download
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', filename)
              ..click();
        html.Url.revokeObjectUrl(url);

        // Tampilkan notifikasi sukses jika context tersedia
        if (context != null) {
          showCustomSnackBar(
            context,
            'File berhasil diunduh',
            type: SnackBarType.success,
            showAtTop: true,
            duration: const Duration(seconds: 2),
          );
        }
        return null; // Tidak ada file fisik di web
      } else {
        // Jika di Android/iOS, simpan file ke direktori aplikasi
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsString(jsonString);

        // Tampilkan notifikasi sukses dengan path file
        if (context != null) {
          showCustomSnackBar(
            context,
            'File tersimpan di: ${file.path}',
            type: SnackBarType.success,
            showAtTop: true,
            duration: const Duration(seconds: 2),
          );
        }
        return file; // Return file yang sudah dibuat
      }
    } catch (e) {
      // Jika error, tampilkan pesan error di console dan snackbar
      print('❌ Gagal backup: $e');
      if (context != null) {
        showCustomSnackBar(
          context,
          'Gagal backup: $e',
          type: SnackBarType.error,
          showAtTop: true,
          duration: const Duration(seconds: 2),
        );
      }
      return null;
    }
  }

  /// Restore data diary dari file backup JSON ke Supabase
  /// - Web: upload file JSON dari user
  /// - Mobile: pilih file JSON dari storage
  static Future<void> restoreBackup(BuildContext context) async {
    if (kIsWeb) {
      // Jika di web, gunakan metode restore khusus web
      await _restoreFromBackupWeb(context);
    } else {
      // Jika di mobile, gunakan metode restore khusus mobile
      await _restoreFromBackupMobile(context);
    }
  }

  /// Restore backup khusus Android/iOS
  static Future<void> _restoreFromBackupMobile(BuildContext context) async {
    try {
      // Ambil user yang sedang login
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      // Tampilkan file picker untuk memilih file JSON
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Jika user batal memilih file
      if (result == null || result.files.isEmpty) {
        throw Exception('Tidak ada file dipilih');
      }

      // Ambil path file yang dipilih
      final filePath = result.files.first.path;
      if (filePath == null) throw Exception('Path file tidak ditemukan');
      final file = File(filePath);
      // Baca isi file sebagai string
      final contents = await file.readAsString();
      // Decode JSON ke List<dynamic>
      final List<dynamic> data = jsonDecode(contents);

      // Upload data ke Supabase
      await _uploadToSupabase(data, user.id, context);
    } catch (e) {
      // Jika error, tampilkan pesan error di console dan snackbar
      print('❌ Gagal restore (mobile): $e');
      showCustomSnackBar(
        context,
        'Gagal pulihkan: $e',
        type: SnackBarType.error,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Restore backup khusus Web
  static Future<void> _restoreFromBackupWeb(BuildContext context) async {
    try {
      // Ambil user yang sedang login
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User belum login');

      // Buat input file HTML untuk upload file JSON
      final uploadInput = html.FileUploadInputElement()..accept = '.json';
      uploadInput.click();

      // Listener ketika file dipilih
      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files == null || files.isEmpty) return;

        // Baca isi file sebagai string
        final reader = html.FileReader();
        reader.readAsText(files.first);

        // Listener ketika file selesai dibaca
        reader.onLoadEnd.listen((e) async {
          final contents = reader.result as String;
          // Decode JSON ke List<dynamic>
          final List<dynamic> data = jsonDecode(contents);
          // Upload data ke Supabase
          await _uploadToSupabase(data, user.id, context);
        });
      });
    } catch (e) {
      // Jika error, tampilkan pesan error di console dan snackbar
      print('❌ Gagal restore (web): $e');
      showCustomSnackBar(
        context,
        'Gagal pulihkan: $e',
        type: SnackBarType.error,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }

  /// Upload data hasil restore ke Supabase
  /// - data: List entry diary hasil decode JSON
  /// - userId: ID user yang login
  /// - context: BuildContext untuk notifikasi
  static Future<void> _uploadToSupabase(
    List<dynamic> data,
    String userId,
    BuildContext context,
  ) async {
    // Loop setiap item dan lakukan upsert ke tabel diary_entries
    for (final item in data) {
      await Supabase.instance.client.from('diary_entries').upsert({
        'id': item['id'],
        'user_id': userId,
        'title': item['title'],
        'content': item['content'],
        'content_below': item['content_below'],
        'emoji': item['emoji'],
        'background': item['background'],
        'text_color': item['text_color'],
        'image_url': item['image_url'],
        'is_favorite': item['is_favorite'],
        'created_at': item['created_at'],
      });
    }
    // Tampilkan notifikasi sukses setelah selesai upload
    showCustomSnackBar(
      context,
      'Data berhasil dipulihkan',
      type: SnackBarType.success,
      showAtTop: true,
      duration: const Duration(seconds: 2),
    );
  }

  /// Backup otomatis ke Google Drive (background)
  static Future<void> backgroundBackup() async {
    // Ambil preferensi apakah backup otomatis aktif
    final prefs = await SharedPreferences.getInstance();
    final isAuto = prefs.getBool('backup_otomatis') ?? false;
    if (!isAuto) return; // Jika tidak aktif, keluar

    // Generate file backup JSON tanpa context (tidak tampilkan snackbar)
    final file = await generateBackupJson(null);
    if (file == null) return;

    // Baca isi file backup sebagai string
    final json = await file.readAsString();

    // Upload file backup ke Google Drive secara silent
    await GoogleDriveHelper.uploadBackupJsonSilently(
      fileName: 'backup_auto_${DateTime.now().toIso8601String()}.json',
      jsonData: json,
    );

    // Simpan waktu terakhir sync ke shared preferences
    await prefs.setString('last_sync', DateTime.now().toIso8601String());
  }
}
// Penjelasan umum:

// File ini berisi class BackupService yang menyediakan fungsi backup dan restore data diary user ke/dari file JSON, baik di platform mobile maupun web.
// Backup bisa dilakukan manual (oleh user) atau otomatis (background ke Google Drive).
// Restore memungkinkan user mengembalikan data diary dari file backup ke database Supabase.
