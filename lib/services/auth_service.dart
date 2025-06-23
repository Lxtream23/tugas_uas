// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tugas_uas/widgets/custom_snackbar.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:62976', // ganti dengan URL kamu
          queryParams: {'prompt': 'select_account'}, // ⬅️ Paksa pilih akun
        );
        // On web, Supabase handles the redirect and authentication.
        return;
      } else {
        final googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          serverClientId:
              '658021506260-v1ob4ot2n21akugrl76itjjfr5tckitr.apps.googleusercontent.com',
        );
        await googleSignIn.signOut(); // ⬅️ Hapus sesi sebelumnya
        final account = await googleSignIn.signIn();

        if (account == null) return;
        final auth = await account.authentication;
        print('✅ Akun: ${account.email}');
        print('🪪 AccessToken: ${auth.accessToken}');
        print('🪪 IDToken: ${auth.idToken}');
        print('🧪 Platform: ${kIsWeb ? "Web" : "Android/iOS"}');

        if (auth.idToken == null || auth.accessToken == null) {
          print('❌ Token Google null');
          showCustomSnackBar(
            context,
            'Gagal mendapatkan token Google',
            type: SnackBarType.error,
            showAtTop: true,
            duration: const Duration(seconds: 2),
          );

          return;
        }

        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: auth.idToken!,
          accessToken: auth.accessToken!,
        );

        if (response.session != null) {
          print('✅ Login Google berhasil: ${response.user?.email}');
          // Navigasi ke halaman utama setelah login
          Navigator.pushReplacementNamed(context, '/home');
          showCustomSnackBar(
            context,
            'Login menggunakan Google berhasil',
            type: SnackBarType.success,
            showAtTop: true,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      print('❌ Login Google gagal: $e');
      showCustomSnackBar(
        context,
        'Login menggunakan Google gagal',
        type: SnackBarType.error,
        showAtTop: true,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
