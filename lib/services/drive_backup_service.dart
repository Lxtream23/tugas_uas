import 'dart:convert'; // Untuk encoding dan decoding data JSON
import 'package:flutter/material.dart'; // Untuk widget dan context Flutter
import 'package:google_sign_in/google_sign_in.dart'; // Untuk autentikasi Google Sign-In
import 'package:googleapis/drive/v3.dart'
    as drive; // Library Google Drive API versi 3
import 'package:googleapis_auth/auth_io.dart'; // Untuk otentikasi OAuth Google API
import 'package:http/http.dart' as http; // Untuk melakukan request HTTP
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar untuk notifikasi

// Kelas helper untuk operasi Google Drive
class GoogleDriveHelper {
  // Inisialisasi GoogleSignIn dengan scope Drive API (hanya akses file yang dibuat aplikasi)
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  // Fungsi statis untuk mengunggah file JSON ke Google Drive
  // context: BuildContext dari widget Flutter
  // filename: Nama file yang akan diunggah ke Drive
  // jsonContent: Isi file dalam format JSON (string)
  static Future<void> uploadToDrive(
    BuildContext context,
    String filename,
    String jsonContent,
  ) async {
    try {
      // Proses login Google, akan menampilkan dialog login jika belum login
      final account = await _googleSignIn.signIn();
      // Jika user membatalkan login, lempar exception
      if (account == null) throw Exception('Login Google dibatalkan');

      // Ambil authHeaders dari akun Google yang sudah login
      final authHeaders = await account.authHeaders;
      // Buat client otentikasi khusus untuk Google API
      final client = GoogleAuthClient(authHeaders);

      // Inisialisasi Drive API dengan client yang sudah otentikasi
      final driveApi = drive.DriveApi(client);

      // Siapkan media/file yang akan diupload ke Drive
      final media = drive.Media(
        Stream.value(
          utf8.encode(jsonContent),
        ), // Data file dalam bentuk stream byte
        utf8.encode(jsonContent).length, // Panjang data file
        contentType: 'application/json', // Tipe konten file
      );

      // Buat objek file Drive dengan nama file yang diinginkan
      final file = drive.File()..name = filename;

      // Proses upload file ke Google Drive
      await driveApi.files.create(file, uploadMedia: media);

      // Tampilkan snackbar sukses jika upload berhasil
      showCustomSnackBar(
        context,
        'File berhasil diunggah ke Google Drive',
        type: SnackBarType.success,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      // Jika terjadi error, tampilkan pesan error di console
      print('❌ Gagal upload: $e');
      // Tampilkan snackbar error ke user
      showCustomSnackBar(
        context,
        'Gagal upload: $e',
        type: SnackBarType.error,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }
}

// Kelas client HTTP khusus untuk Google API yang menambahkan authHeaders ke setiap request
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers; // Header otentikasi
  final http.Client _client = http.Client(); // Client HTTP standar

  // Konstruktor menerima header otentikasi
  GoogleAuthClient(this._headers);

  // Override method send untuk menambahkan header otentikasi ke setiap request
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
// Penjelasan singkat:

// File ini berfungsi untuk mengunggah file JSON ke Google Drive menggunakan akun Google user.
// Menggunakan autentikasi Google Sign-In dan Google Drive API.
// Jika upload berhasil/gagal, akan menampilkan notifikasi (snackbar) ke user.
// Kelas GoogleAuthClient digunakan untuk memastikan setiap request ke Google API sudah menyertakan header otentikasi yang benar.
