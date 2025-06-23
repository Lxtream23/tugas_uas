import 'package:flutter/material.dart'; // Import library Flutter untuk UI
import 'package:another_flushbar/flushbar.dart'; // Import package Flushbar untuk custom snackbar

// Enum untuk menentukan tipe snackbar yang akan ditampilkan
enum SnackBarType { success, error, info, warning }

// Fungsi utama untuk menampilkan custom snackbar
void showCustomSnackBar(
  BuildContext context, // Context dari widget yang memanggil
  String message, // Pesan utama yang akan ditampilkan
  {
    String? title, // Judul opsional pada snackbar
    SnackBarType type = SnackBarType.info, // Tipe snackbar, default info
    Duration duration = const Duration(seconds: 3), // Durasi tampil snackbar
    String? actionLabel, // Label tombol aksi opsional
    VoidCallback? onActionPressed, // Fungsi callback saat tombol aksi ditekan
    bool showAtTop = false, // Posisi snackbar, default di bawah
    double borderRadius = 12, // Radius sudut snackbar
    EdgeInsets? margin, // Margin snackbar, opsional
  }
) {
  // Cek apakah tema aplikasi sedang gelap atau terang
  final isDark = Theme.of(context).brightness == Brightness.dark;

  Icon icon; // Variabel untuk ikon yang akan ditampilkan
  Color bgColor; // Variabel untuk warna background snackbar

  // Pilih ikon dan warna background berdasarkan tipe snackbar
  switch (type) {
    case SnackBarType.success:
      icon = const Icon(Icons.check_circle, color: Colors.white); // Ikon sukses
      bgColor = Colors.green[600]!; // Warna hijau untuk sukses
      break;
    case SnackBarType.error:
      icon = const Icon(Icons.error, color: Colors.white); // Ikon error
      bgColor = Colors.red[600]!; // Warna merah untuk error
      break;
    case SnackBarType.warning:
      icon = const Icon(Icons.warning, color: Colors.white); // Ikon warning
      bgColor = Colors.orange[700]!; // Warna oranye untuk warning
      break;
    default:
      icon = const Icon(Icons.info_outline, color: Colors.white); // Ikon info
      bgColor = Colors.blue[600]!; // Warna biru untuk info
  }

  // Membuat dan menampilkan Flushbar (custom snackbar)
  Flushbar(
    // Jika ada judul, tampilkan dengan style tebal dan putih
    titleText: title != null
        ? Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          )
        : null, // Jika tidak ada judul, null

    // Isi pesan snackbar, terdiri dari ikon, spasi, dan pesan
    messageText: Row(
      children: [
        icon, // Ikon sesuai tipe
        const SizedBox(width: 8), // Spasi antar ikon dan teks
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white), // Pesan berwarna putih
          ),
        ),
      ],
    ),

    backgroundColor: bgColor, // Warna background sesuai tipe
    flushbarPosition:
        showAtTop ? FlushbarPosition.TOP : FlushbarPosition.BOTTOM, // Posisi snackbar (atas/bawah)
    duration: duration, // Durasi tampil snackbar
    borderRadius: BorderRadius.circular(borderRadius), // Sudut membulat
    margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Margin default jika tidak diisi
    animationDuration: const Duration(milliseconds: 400), // Durasi animasi muncul
    // Tombol aksi jika label dan callback tersedia
    mainButton: (actionLabel != null && onActionPressed != null)
        ? TextButton(
            onPressed: onActionPressed, // Fungsi saat tombol ditekan
            child: Text(
              actionLabel, // Label tombol
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : null, // Jika tidak ada aksi, null
    isDismissible: true, // Bisa ditutup dengan swipe/tap di luar
  ).show(context); // Tampilkan snackbar di context yang diberikan
}

// | Fitur               | Keterangan                                    |
// | ------------------- | --------------------------------------------- |
// | 🔔 Ikon otomatis    | Berdasarkan tipe (`success`, `error`, `info`) |
// | 🎨 Warna background | Hijau, merah, biru (bisa diubah sesuai tema)  |
// | 🧭 Floating style   | Melayang dari bawah, tidak menempel           |
// | 🧱 Rounded corner   | Terlihat modern dan elegan                    |
// | ⏳ Durasi custom     | Bisa diganti `duration: Duration(seconds: 5)` |
// | 📱 Responsif        | Cocok untuk mobile, tablet, dan desktop       |

//✅ Contoh Penggunaan di Mana Saja:
// showCustomSnackBar(context, 'Berhasil menyimpan data', type: SnackBarType.success);
// showCustomSnackBar(context, 'Terjadi kesalahan saat login', type: SnackBarType.error);
// showCustomSnackBar(context, 'Fitur belum tersedia'); // default: info
//✅ Undo:
//showCustomSnackBar(context,'Catatan dihapus',type: SnackBarType.error,actionLabel: 'Undo',onActionPressed: () {// Logika untuk mengembalikan data},);
//✅ Tutup manual:
//showCustomSnackBar(context,'Tema berhasil diubah',type: SnackBarType.success,actionLabel: 'Tutup',onActionPressed: () {ScaffoldMessenger.of(context).hideCurrentSnackBar();},);
//📍 Tampilkan di atas:
//showCustomSnackBar( context, 'Pengaturan diperbarui',showAtTop: true,);
