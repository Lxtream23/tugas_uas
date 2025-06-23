import 'package:flutter/material.dart'; // Import library Flutter untuk UI
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase untuk autentikasi backend
import 'package:tugas_uas/services/auth_service.dart'; // Import service custom untuk autentikasi (Google)
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts untuk styling font
import 'package:flutter_svg/flutter_svg.dart'; // Import untuk menampilkan gambar SVG
import 'package:tugas_uas/pages/auth/register_page.dart'; // Import halaman register
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Import custom snackbar untuk notifikasi

// Widget utama halaman login, menggunakan StatefulWidget karena ada state yang berubah (misal loading, visibility password)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// State dari LoginPage
class _LoginPageState extends State<LoginPage> {
  // Controller untuk mengambil input email dari TextField
  final _emailController = TextEditingController();
  // Controller untuk mengambil input password dari TextField
  final _passwordController = TextEditingController();
  // State untuk menandakan loading saat proses login
  bool _isLoading = false;
  // State untuk mengatur visibilitas password (show/hide)
  bool _isPasswordVisible = false;
  // Instance Supabase client untuk autentikasi
  final _supabase = Supabase.instance.client;

  // Fungsi untuk melakukan proses login
  Future<void> _login() async {
    setState(() => _isLoading = true); // Set loading true saat mulai login

    try {
      // Proses login dengan email dan password menggunakan Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Jika login berhasil (user tidak null)
      if (response.user != null) {
        // Cek apakah widget masih terpasang di tree
        if (mounted) {
          print('✅ Login berhasil: ${response.user?.email}');
          // Navigasi ke halaman utama (home) setelah login sukses
          Navigator.pushReplacementNamed(context, '/home');
          // Tampilkan snackbar sukses di atas layar
          showCustomSnackBar(
            context,
            'Login berhasil!',
            type: SnackBarType.success,
            duration: const Duration(seconds: 2),
            showAtTop: true,
          );
        }
      }
    } on AuthException catch (e) {
      // Jika terjadi error autentikasi, tampilkan pesan error spesifik
      _showError(e.message);
    } catch (e) {
      // Jika terjadi error lain, tampilkan pesan error umum
      _showError("Terjadi kesalahan. Silakan coba lagi.");
    } finally {
      // Setelah proses login selesai (berhasil/gagal), set loading ke false
      setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk menampilkan snackbar error custom
  void _showError(String message) {
    showCustomSnackBar(
      context,
      message,
      type: SnackBarType.error,
      duration: const Duration(seconds: 2),
      showAtTop: true,
    );
  }

  // Fungsi untuk membuat animasi transisi ke halaman register
  Route _createRouteToRegister() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const RegisterPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animasi slide dari kanan ke kiri
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1, 0), // Mulai dari kanan layar
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

        // Animasi fade in
        final fadeAnimation = Tween<double>(
          begin: 0,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

        // Gabungkan animasi slide dan fade
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 400), // Durasi animasi
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold sebagai struktur utama halaman
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF), // Warna background halaman
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), // Padding luar
          child: Container(
            padding: const EdgeInsets.all(24), // Padding dalam
            decoration: BoxDecoration(
              color: Colors.white, // Warna background container
              borderRadius: BorderRadius.circular(20), // Sudut membulat
              boxShadow: [
                BoxShadow(
                  color: Colors.black12, // Warna bayangan
                  blurRadius: 10, // Blur bayangan
                  offset: const Offset(0, 4), // Posisi bayangan
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Center horizontal
              children: [
                // Logo aplikasi (SVG)
                SvgPicture.asset(
                  'assets/logo/notexa_logo.svg',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 24), // Spasi
                // Judul halaman
                Text(
                  'Login',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                // TextField untuk input email
                TextField(
                  controller: _emailController, // Controller email
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Email', // Placeholder
                    hintStyle: GoogleFonts.poppins(),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA), // Warna field
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // TextField untuk input password
                TextField(
                  controller: _passwordController, // Controller password
                  obscureText:
                      !_isPasswordVisible, // Sembunyikan password jika false
                  style: GoogleFonts.poppins(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: GoogleFonts.poppins(),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    // Icon untuk show/hide password
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        // Toggle visibilitas password
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Jika loading, tampilkan CircularProgressIndicator
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                      width: double.infinity,
                      // Tombol login
                      child: ElevatedButton(
                        onPressed: _login, // Panggil fungsi login saat ditekan
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                // Tombol login dengan Google
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: SvgPicture.asset(
                      'assets/icons/google_icon.svg',
                      height: 20,
                    ),
                    label: Text(
                      'Login dengan Google',
                      style: GoogleFonts.poppins(color: Colors.black87),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    onPressed: () {
                      // Panggil fungsi login Google dari AuthService
                      AuthService.signInWithGoogle(context);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Tombol navigasi ke halaman register
                TextButton(
                  onPressed: () {
                    // Navigasi ke halaman register dengan animasi custom
                    Navigator.of(context).push(_createRouteToRegister());
                  },
                  child: Text(
                    'Belum punya akun? Register',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6C63FF),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// Penjelasan Umum:

// File ini adalah halaman login aplikasi Flutter yang menggunakan Supabase untuk autentikasi email/password dan Google Sign-In.
// Terdapat validasi loading, error handling, dan transisi animasi ke halaman register.
// UI didesain modern dengan Google Fonts, SVG logo, dan custom snackbar untuk notifikasi.
// Komentar sudah ditambahkan pada setiap bagian penting untuk memudahkan pemahaman kode.
