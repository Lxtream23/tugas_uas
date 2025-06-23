import 'package:flutter/material.dart'; // Import package Flutter untuk widget UI
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase untuk autentikasi dan backend

// Widget SplashPage sebagai halaman splash screen aplikasi
class SplashPage extends StatefulWidget {
  const SplashPage({super.key}); // Konstruktor dengan key opsional

  @override
  State<SplashPage> createState() => _SplashPageState(); // Membuat state untuk SplashPage
}

// State dari SplashPage, berisi logika dan tampilan
class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkSession(); // Memanggil fungsi untuk cek status login saat widget pertama kali dibuat
  }

  // Fungsi async untuk mengecek apakah user sudah login atau belum
  Future<void> _checkSession() async {
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Menunda eksekusi selama 1 detik, bisa diganti animasi/logo

    final session = Supabase.instance.client.auth.currentSession; // Mengambil session user dari Supabase

    if (session != null) {
      // Jika session tidak null, berarti user masih login
      if (mounted) { // Mengecek apakah widget masih ada di tree
        Navigator.pushReplacementNamed(context, '/home'); // Navigasi ke halaman home, menggantikan splash
      }
    } else {
      // Jika session null, berarti user belum login
      if (mounted) { // Mengecek apakah widget masih ada di tree
        Navigator.pushReplacementNamed(context, '/login'); // Navigasi ke halaman login, menggantikan splash
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Membuat tampilan splash screen dengan judul di tengah layar
    return const Scaffold(
      body: Center(
        child: Text(
          'Catatan Harian', // Judul aplikasi
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), // Styling teks
        ),
      ),
    );
  }
}
