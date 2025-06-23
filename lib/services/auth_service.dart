// File ini berisi service untuk autentikasi, khususnya login menggunakan Google dan integrasi dengan Supabase.

import 'package:flutter/material.dart'; // Paket UI Flutter
import 'package:google_sign_in/google_sign_in.dart'; // Paket untuk Google Sign-In (Android/iOS)
import 'package:supabase_flutter/supabase_flutter.dart'; // Paket Supabase untuk autentikasi backend
import 'package:flutter/foundation.dart' show kIsWeb; // Untuk deteksi platform (web/mobile)
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom snackbar untuk notifikasi

// Kelas AuthService berisi method statis untuk autentikasi user
class AuthService {
  // Inisialisasi client Supabase yang akan digunakan untuk autentikasi
  static final _supabase = Supabase.instance.client;

  // Fungsi statis untuk login menggunakan Google
  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Jika aplikasi dijalankan di web
      if (kIsWeb) {
        // Menggunakan OAuth Supabase untuk login Google di web
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:62976', // URL redirect setelah login (ganti sesuai kebutuhan)
          queryParams: {'prompt': 'select_account'}, // Memaksa user memilih akun Google
        );
        // Pada web, Supabase akan menangani redirect dan autentikasi secara otomatis
        return;
      } else {
        // Jika aplikasi dijalankan di Android/iOS
        final googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'], // Scope data yang diminta dari Google
          serverClientId:
              '658021506260-v1ob4ot2n21akugrl76itjjfr5tckitr.apps.googleusercontent.com', // Client ID dari Google API Console
        );
        await googleSignIn.signOut(); // Logout sesi Google sebelumnya agar selalu muncul pilihan akun
        final account = await googleSignIn.signIn(); // Memulai proses login Google

        if (account == null) return; // Jika user batal login, keluar dari fungsi
        final auth = await account.authentication; // Mendapatkan token autentikasi Google
        print('✅ Akun: ${account.email}');
        print('🪪 AccessToken: ${auth.accessToken}');
        print('🪪 IDToken: ${auth.idToken}');
        print('🧪 Platform: ${kIsWeb ? "Web" : "Android/iOS"}');

        // Jika token Google tidak tersedia, tampilkan error
        if (auth.idToken == null || auth.accessToken == null) {
          print('❌ Token Google null');
          showCustomSnackBar(
            context,
            'Gagal mendapatkan token Google', // Pesan error
            type: SnackBarType.error, // Tipe error
            showAtTop: true, // Tampilkan di atas layar
            duration: const Duration(seconds: 2), // Durasi tampil
          );

          return;
        }

        // Kirim token Google ke Supabase untuk login backend
        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google, // Provider Google
          idToken: auth.idToken!, // Token ID Google
          accessToken: auth.accessToken!, // Access token Google
        );

        // Jika login berhasil (ada session), navigasi ke halaman utama
        if (response.session != null) {
          print('✅ Login Google berhasil: ${response.user?.email}');
          // Navigasi ke halaman home setelah login sukses
          Navigator.pushReplacementNamed(context, '/home');
          showCustomSnackBar(
            context,
            'Login menggunakan Google berhasil', // Pesan sukses
            type: SnackBarType.success, // Tipe sukses
            showAtTop: true,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      // Jika terjadi error saat proses login Google
      print('❌ Login Google gagal: $e');
      showCustomSnackBar(
        context,
        'Login menggunakan Google gagal', // Pesan error
        type: SnackBarType.error,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
