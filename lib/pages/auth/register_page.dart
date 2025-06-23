import 'dart:math'; // Untuk animasi shake (menggunakan sin)
import 'package:flutter/material.dart'; // Paket utama Flutter untuk UI
import 'package:supabase_flutter/supabase_flutter.dart'; // Untuk autentikasi Supabase
import 'package:flutter_svg/flutter_svg.dart'; // Untuk menampilkan gambar SVG
import 'package:tugas_uas/services/auth_service.dart'; // Service custom untuk autentikasi (Google)
import 'package:tugas_uas/pages/auth/login_page.dart'; // Halaman login, untuk navigasi
import 'package:tugas_uas/widgets/custom_snackbar.dart'; // Widget custom untuk snackbar (notifikasi)

/// Halaman Register (pendaftaran akun baru)
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

/// State dari RegisterPage, menggunakan TickerProviderStateMixin untuk animasi
class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  // Controller untuk input email
  final _emailController = TextEditingController();
  // Controller untuk input password
  final _passwordController = TextEditingController();
  // State untuk loading (menampilkan loading indicator)
  bool _isLoading = false;
  // State untuk menampilkan/menyembunyikan password
  bool _obscurePassword = true;
  // Instance Supabase untuk autentikasi
  final _supabase = Supabase.instance.client;

  // Controller animasi shake
  late AnimationController _shakeController;
  // Animasi shake (nilai double dari 0 ke 1)
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller animasi shake
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Tween animasi shake dari 0 ke 1
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(_shakeController);
  }

  @override
  void dispose() {
    // Dispose controller agar tidak terjadi memory leak
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Fungsi untuk melakukan registrasi akun baru
  Future<void> _register() async {
    setState(() => _isLoading = true); // Tampilkan loading

    try {
      // Proses sign up ke Supabase
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Jika berhasil, tampilkan pesan dan arahkan ke halaman login
      if (response.user != null) {
        _showMessage(
          'Registrasi berhasil. Silakan cek email untuk verifikasi.',
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(_createRouteToLogin());
        }
      }
    } on AuthException catch (e) {
      // Jika error autentikasi, tampilkan pesan error dan animasi shake
      _showMessage(e.message);
      _shakeController.forward(from: 0);
    } catch (_) {
      // Jika error lain, tampilkan pesan error umum dan animasi shake
      _showMessage("Terjadi kesalahan. Silakan coba lagi.");
      _shakeController.forward(from: 0);
    } finally {
      setState(() => _isLoading = false); // Sembunyikan loading
    }
  }

  /// Fungsi untuk menampilkan custom snackbar (notifikasi)
  void _showMessage(String message) {
    showCustomSnackBar(
      context,
      message,
      type: SnackBarType.error,
      duration: const Duration(seconds: 2),
      showAtTop: true,
    );
  }

  /// Fungsi untuk membuat animasi transisi ke halaman login
  Route _createRouteToLogin() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const LoginPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animasi slide dari kiri ke kanan
        final slide = Tween<Offset>(
          begin: const Offset(-1, 0), // Mulai dari kiri layar
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

        // Animasi fade in
        final fade = Tween<double>(
          begin: 0,
          end: 1,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Izinkan pop (back) dari halaman ini
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Jika pop tidak terjadi, handle manual ke halaman login
          Navigator.of(context).pushReplacement(_createRouteToLogin());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register'), // Judul AppBar
          leading: IconButton(
            icon: const Icon(Icons.arrow_back), // Tombol back
            onPressed: () {
              // Navigasi ke halaman login saat tombol back ditekan
              Navigator.of(context).pushReplacement(_createRouteToLogin());
            },
          ),
        ),
        backgroundColor: const Color(0xFFF8F9FF), // Warna background halaman
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24), // Padding konten
            child: AnimatedBuilder(
              animation: _shakeAnimation, // Animasi shake
              builder: (context, child) {
                // Hitung offset shake menggunakan sin
                final shakeOffset = sin(_shakeAnimation.value * pi * 10) * 10;
                return Transform.translate(
                  offset: Offset(shakeOffset, 0), // Geser horizontal
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24), // Padding dalam container
                decoration: BoxDecoration(
                  color: Colors.white, // Warna background container
                  borderRadius: BorderRadius.circular(20), // Sudut melengkung
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12, // Bayangan
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo aplikasi (SVG)
                    SvgPicture.asset(
                      'assets/logo/notexa_logo.svg',
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(height: 24),
                    // Judul halaman
                    const Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Input email
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        filled: true,
                        fillColor: Color(0xFFF5F6FA),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Input password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword, // Sembunyikan password
                      decoration: InputDecoration(
                        hintText: 'Password (min. 6 karakter)',
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
                        // Tombol untuk show/hide password
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tombol daftar (atau loading indicator)
                    _isLoading
                        ? const CircularProgressIndicator() // Loading saat proses daftar
                        : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _register, // Panggil fungsi register
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Daftar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    // Tombol daftar dengan Google
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: SvgPicture.asset(
                          'assets/icons/google_icon.svg',
                          height: 20,
                        ),
                        label: const Text(
                          'Daftar dengan Google',
                          style: TextStyle(color: Colors.black87),
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
                          // Panggil fungsi sign in Google dari AuthService
                          AuthService.signInWithGoogle(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tombol navigasi ke halaman login jika sudah punya akun
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacement(_createRouteToLogin());
                      },
                      child: const Text(
                        'Sudah punya akun? Login',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// Penjelasan singkat:

// File ini adalah halaman register (pendaftaran akun) dengan autentikasi Supabase dan Google.
// Terdapat animasi shake jika terjadi error saat register.
// Navigasi ke halaman login menggunakan animasi transisi custom.
// Input email dan password, serta tombol daftar dan daftar dengan Google.
// Menggunakan custom snackbar untuk menampilkan pesan error atau sukses.
