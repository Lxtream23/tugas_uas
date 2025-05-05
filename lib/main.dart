import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tugas_uas/guards/session_guard.dart';
import 'package:tugas_uas/pages/detail_page.dart';
import 'package:tugas_uas/pages/home_page.dart';
import 'package:tugas_uas/pages/login_page.dart';
import 'package:tugas_uas/pages/register_page.dart';
import 'package:tugas_uas/pages/splash_page.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://pkdoslagpkuxbstpuvil.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrZG9zbGFncGt1eGJzdHB1dmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYxNDc0NDgsImV4cCI6MjA2MTcyMzQ0OH0.4pZTEO6DM_CD8-7bap2VEgS5dVRpnxPsgn3gdq2rZYQ',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Catatan Harian',
      theme: ThemeData.light(), // Tema terang
      darkTheme: ThemeData.dark(), // Tema gelap
      themeMode:
          ThemeMode.system, // Mengikuti pengaturan sistem (gelap atau terang)
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashPage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const SessionGuard(child: HomePage()),
        '/detail': (context) => const SessionGuard(child: DetailPage()),
      },
    );
  }
}
