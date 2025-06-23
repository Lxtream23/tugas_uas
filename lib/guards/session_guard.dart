import 'package:flutter/material.dart'; // Import library Flutter untuk UI
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase untuk autentikasi

// Widget SessionGuard digunakan untuk membungkus widget lain dan memastikan user sudah login sebelum mengaksesnya
class SessionGuard extends StatelessWidget {
  final Widget child; // Widget yang akan ditampilkan jika user sudah login

  // Konstruktor SessionGuard, menerima widget child yang wajib diisi
  const SessionGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Mengambil session saat ini dari Supabase (null jika belum login)
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Jika user belum login, arahkan ke halaman login
      // Future.microtask digunakan agar navigasi dijalankan setelah build selesai
      Future.microtask(() {
        Navigator.pushReplacementNamed(
          context,
          '/login',
        ); // Ganti halaman dengan login
      });
      // Tampilkan loading indicator sementara proses navigasi berlangsung
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Jika user sudah login, tampilkan widget child (halaman tujuan)
    return child;
  }
}

// Penjelasan:

// File ini berfungsi sebagai guard (penjaga) untuk memastikan hanya user yang sudah login yang bisa mengakses halaman tertentu.
// Jika belum login, user otomatis diarahkan ke halaman login.
// Jika sudah login, halaman tujuan (child) akan ditampilkan.
// Sangat berguna untuk proteksi route pada aplikasi berbasis autentikasi.
