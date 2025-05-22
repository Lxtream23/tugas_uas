import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

enum SnackBarType { success, error, info, warning }

void showCustomSnackBar(
  BuildContext context,
  String message, {
  String? title, // Judul opsional
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onActionPressed,
  bool showAtTop = false,
  double borderRadius = 12,
  EdgeInsets? margin,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  Icon icon;
  Color bgColor;

  switch (type) {
    case SnackBarType.success:
      icon = const Icon(Icons.check_circle, color: Colors.white);
      bgColor = Colors.green[600]!;
      break;
    case SnackBarType.error:
      icon = const Icon(Icons.error, color: Colors.white);
      bgColor = Colors.red[600]!;
      break;
    case SnackBarType.warning:
      icon = const Icon(Icons.warning, color: Colors.white);
      bgColor = Colors.orange[700]!;
      break;
    default:
      icon = const Icon(Icons.info_outline, color: Colors.white);
      bgColor = Colors.blue[600]!;
  }

  Flushbar(
    titleText:
        title != null
            ? Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            )
            : null,
    messageText: Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
    backgroundColor: bgColor,
    flushbarPosition:
        showAtTop ? FlushbarPosition.TOP : FlushbarPosition.BOTTOM,
    duration: duration,
    borderRadius: BorderRadius.circular(borderRadius),
    margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    animationDuration: const Duration(milliseconds: 400),
    mainButton:
        (actionLabel != null && onActionPressed != null)
            ? TextButton(
              onPressed: onActionPressed,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
            : null,
    isDismissible: true,
  ).show(context);
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
