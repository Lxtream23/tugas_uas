import 'package:flutter/material.dart'; // Mengimpor package Flutter Material untuk membangun UI aplikasi

// Membuat kelas EmailConfirmationPage yang merupakan StatelessWidget
class EmailConfirmationPage extends StatelessWidget {
  // Konstruktor const untuk EmailConfirmationPage, menggunakan super.key untuk key widget
  const EmailConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Fungsi build untuk membangun tampilan halaman
    return Scaffold(
      // Scaffold menyediakan struktur dasar visual halaman (app bar, body, dll)
      appBar: AppBar(
        title: const Text('Konfirmasi Email'), // Judul pada app bar
        centerTitle: true, // Membuat judul berada di tengah app bar
      ),
      body: Center(
        // Center untuk memposisikan child di tengah layar secara horizontal dan vertikal
        child: ConstrainedBox(
          // ConstrainedBox membatasi ukuran maksimum child-nya
          constraints: BoxConstraints(maxWidth: 500), // Maksimal lebar 500px
          child: Padding(
            // Padding memberikan jarak di sekeliling child-nya
            padding: const EdgeInsets.all(24), // Padding 24px di semua sisi
            child: Column(
              // Column untuk menata widget secara vertikal
              mainAxisAlignment:
                  MainAxisAlignment
                      .center, // Menengahkan widget secara vertikal
              children: const [
                // Daftar widget yang akan ditampilkan secara vertikal
                Icon(
                  Icons.mark_email_unread, // Icon email belum dibaca
                  size: 64, // Ukuran icon 64px
                  color: Colors.blue, // Warna icon biru
                ),
                SizedBox(
                  height: 24,
                ), // Jarak vertikal 24px antara icon dan teks
                Text(
                  // Widget teks untuk menampilkan pesan konfirmasi
                  'Kami telah mengirimkan link konfirmasi ke email baru Anda. '
                  'Silakan periksa kotak masuk dan klik tautan untuk menyelesaikan perubahan.',
                  textAlign: TextAlign.center, // Teks rata tengah
                  style: TextStyle(fontSize: 16), // Ukuran font 16px
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

// File ini membuat halaman konfirmasi email yang sederhana.
// Halaman ini menampilkan icon email, pesan instruksi, dan menggunakan padding serta pembatas lebar agar tampilan tetap rapi di berbagai ukuran layar.
// Scaffold dan AppBar digunakan untuk struktur halaman standar aplikasi Flutter.
// Semua widget diatur agar tampil di tengah layar dan mudah dibaca pengguna.
