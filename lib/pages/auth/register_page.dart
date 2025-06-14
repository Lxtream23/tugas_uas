import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tugas_uas/services/auth_service.dart'; // pastikan kamu punya file ini
import 'package:tugas_uas/pages/auth/login_page.dart'; // tambahkan ini untuk LoginPage

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _supabase = Supabase.instance.client;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(_shakeController);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        _showMessage(
          'Registrasi berhasil. Silakan cek email untuk verifikasi.',
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(_createRouteToLogin());
        }
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
      _shakeController.forward(from: 0);
    } catch (_) {
      _showMessage("Terjadi kesalahan. Silakan coba lagi.");
      _shakeController.forward(from: 0);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Route _createRouteToLogin() {
    return PageRouteBuilder(
      pageBuilder:
          (context, animation, secondaryAnimation) => const LoginPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(-1, 0), // Slide dari kiri
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

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
      canPop: true, // biar PopScope tangani event back
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Kalau kita mau handle pop sendiri
          Navigator.of(context).pushReplacement(_createRouteToLogin());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Register'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(_createRouteToLogin());
            },
          ),
        ),
        backgroundColor: const Color(0xFFF8F9FF),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final shakeOffset = sin(_shakeAnimation.value * pi * 10) * 10;
                return Transform.translate(
                  offset: Offset(shakeOffset, 0),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/logo/notexa_logo.svg',
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
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
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _register,
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
                          AuthService.signInWithGoogle(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
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
