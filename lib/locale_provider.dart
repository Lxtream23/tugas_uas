// Import package Flutter untuk membuat UI dan ChangeNotifier.
import 'package:flutter/material.dart';
// Import package SharedPreferences untuk menyimpan data secara lokal di perangkat.
import 'package:shared_preferences/shared_preferences.dart';

// LocaleProvider adalah class yang digunakan untuk mengelola dan menyediakan data bahasa (locale) aplikasi.
// Class ini menggunakan ChangeNotifier agar widget yang mendengarkan perubahan locale bisa melakukan rebuild.
class LocaleProvider extends ChangeNotifier {
  // Variabel private _locale untuk menyimpan locale saat ini. Default-nya adalah bahasa Indonesia ('id').
  Locale _locale = const Locale('id');

  // Getter untuk mengambil nilai locale saat ini.
  Locale get locale => _locale;

  // Fungsi untuk memuat locale yang tersimpan di SharedPreferences saat aplikasi dijalankan.
  // Jika tidak ada data tersimpan, default-nya menggunakan 'id' (bahasa Indonesia).
  Future<void> loadLocale() async {
    // Mengambil instance SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    // Mengambil kode bahasa yang tersimpan, jika tidak ada gunakan 'id'.
    final langCode = prefs.getString('language') ?? 'id';
    // Mengubah _locale sesuai kode bahasa yang didapat.
    _locale = Locale(langCode);
    // Memberitahu listener bahwa terjadi perubahan pada locale.
    notifyListeners();
  }

  // Fungsi untuk mengubah locale aplikasi dan menyimpannya ke SharedPreferences.
  // Digunakan saat user mengganti bahasa aplikasi.
  Future<void> setLocale(String languageCode) async {
    // Mengambil instance SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    // Menyimpan kode bahasa baru ke SharedPreferences.
    await prefs.setString('language', languageCode);
    // Mengubah _locale sesuai kode bahasa baru.
    _locale = Locale(languageCode);
    // Memberitahu listener bahwa terjadi perubahan pada locale.
    notifyListeners();
  }
}
// Penjelasan Umum:

// File ini berfungsi sebagai provider untuk pengaturan bahasa (locale) aplikasi Flutter.
// Menggunakan SharedPreferences agar pilihan bahasa tetap tersimpan walaupun aplikasi ditutup.
// Dengan ChangeNotifier, widget yang menggunakan provider ini akan otomatis memperbarui tampilan jika terjadi perubahan bahasa.
