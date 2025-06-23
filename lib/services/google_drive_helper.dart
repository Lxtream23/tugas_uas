import 'dart:convert'; // Untuk encoding dan decoding data JSON
import 'dart:typed_data'; // Untuk manipulasi data byte

import 'package:flutter/foundation.dart'; // Untuk deteksi platform (web/native)
import 'package:flutter/material.dart'; // Untuk akses widget dan context Flutter
import 'package:google_sign_in/google_sign_in.dart'; // Untuk autentikasi Google Sign-In
import 'package:http/http.dart' as http; // Untuk melakukan HTTP request
import 'package:googleapis/drive/v3.dart' as drive; // Library Google Drive API
import 'package:shared_preferences/shared_preferences.dart'; // Untuk penyimpanan lokal sederhana
import 'package:http_parser/http_parser.dart'; // Untuk parsing tipe konten HTTP
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar untuk notifikasi

// Kelas custom client HTTP yang menambahkan header autentikasi Google ke setiap request
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers; // Header autentikasi
  final http.Client _client = http.Client(); // Client HTTP dasar

  GoogleAuthClient(this._headers);

  // Override method send untuk menambahkan header autentikasi ke setiap request
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

// Helper untuk operasi terkait Google Drive
class GoogleDriveHelper {
  // Inisialisasi GoogleSignIn dengan clientId khusus web dan scope yang dibutuhkan
  static final _googleSignIn = GoogleSignIn(
    clientId:
        kIsWeb
            ? '658021506260-9cld2l1msjk48qaeuebkontdgnoumdfg.apps.googleusercontent.com' // Client ID khusus web
            : null, // Untuk platform selain web, gunakan default
    scopes: [
      'https://www.googleapis.com/auth/drive.file', // Akses file di Google Drive
      'https://www.googleapis.com/auth/userinfo.email', // Akses email user
      'https://www.googleapis.com/auth/userinfo.profile', // Akses profil user
      'openid', // Scope openid untuk autentikasi
    ],
  );

  // Fungsi untuk mengupload file JSON ke Google Drive dengan autentikasi Google Sign-In
  static Future<void> uploadBackupJson({
    required BuildContext context, // Context untuk menampilkan snackbar
    required String fileName, // Nama file yang akan diupload
    required String jsonData, // Data JSON yang akan diupload
  }) async {
    try {
      // Proses login Google
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('Login Google dibatalkan');

      // Ambil header autentikasi dari akun Google
      final authHeaders = await account.authHeaders;
      final client = GoogleAuthClient(
        authHeaders,
      ); // Buat client dengan header autentikasi
      final driveApi = drive.DriveApi(client); // Inisialisasi API Google Drive

      // Siapkan data file yang akan diupload (media)
      final media = drive.Media(
        Stream.value(
          utf8.encode(jsonData),
        ), // Data file dalam bentuk stream byte
        utf8.encode(jsonData).length, // Panjang data
        contentType: 'application/json', // Tipe konten file
      );

      // Buat objek file dengan nama yang diinginkan
      final file = drive.File()..name = fileName;

      // Upload file ke Google Drive
      await driveApi.files.create(file, uploadMedia: media);

      // Jika context masih aktif, tampilkan snackbar sukses
      if (context.mounted) {
        showCustomSnackBar(
          context,
          'Backup berhasil ke Google Drive', // Pesan sukses
          type: SnackBarType.success, // Tipe snackbar sukses
          showAtTop: true, // Tampilkan di atas
          duration: const Duration(seconds: 2), // Durasi tampil 2 detik
        );
      }
    } catch (e) {
      // Jika terjadi error, tampilkan pesan error di debug console
      debugPrint('❌ Gagal upload ke Google Drive: $e');
      // Jika context masih aktif, tampilkan snackbar error
      if (context.mounted) {
        showCustomSnackBar(
          context,
          'Gagal upload ke Google Drive: $e', // Pesan error
          type: SnackBarType.error, // Tipe snackbar error
          showAtTop: true,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  // Fungsi alternatif untuk upload file JSON ke Google Drive secara silent (tanpa UI)
  static Future<void> uploadBackupJsonSilently({
    required String fileName, // Nama file yang akan diupload
    required String jsonData, // Data JSON yang akan diupload
  }) async {
    // Ambil access token dari SharedPreferences (penyimpanan lokal)
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      print('❌ Access token kosong atau tidak ada');
      return;
    }

    // Endpoint upload file ke Google Drive dengan tipe multipart
    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
    );

    // Buat request multipart POST
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] =
          'Bearer $token'; // Tambahkan header autentikasi

    // Metadata file (nama dan tipe file)
    final metadata = json.encode({
      'name': fileName,
      'mimeType': 'application/json',
    });

    // Tambahkan metadata ke request
    request.files.add(
      http.MultipartFile.fromString(
        'metadata',
        metadata,
        contentType: MediaType('application', 'json'),
      ),
    );

    // Tambahkan file JSON ke request
    request.files.add(
      http.MultipartFile.fromString(
        'file',
        jsonData,
        filename: fileName,
        contentType: MediaType('application', 'json'),
      ),
    );

    // Kirim request ke Google Drive
    final response = await request.send();

    // Cek status response, tampilkan log sesuai hasil
    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ Backup berhasil');
    } else {
      print('❌ Gagal upload: ${response.statusCode}');
    }
  }
}
// Penjelasan Umum:

// File ini berfungsi sebagai helper/service untuk melakukan backup data ke Google Drive menggunakan dua metode: dengan autentikasi Google Sign-In (menampilkan UI) dan secara silent menggunakan access token yang sudah disimpan.
// Terdapat juga custom HTTP client untuk menambahkan header autentikasi secara otomatis.
// Notifikasi keberhasilan/gagal upload ditampilkan menggunakan custom snackbar atau log di console.
