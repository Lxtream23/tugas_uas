// Kelas model untuk merepresentasikan satu entri diary
class DiaryEntry {
  // Field unik untuk mengidentifikasi setiap entri diary
  final String id; // ID unik entri diary

  // Field untuk mengidentifikasi pemilik entri diary
  final String userId; // ID user yang membuat entri

  // Judul dari entri diary
  final String title; // Judul entri diary

  // Isi utama dari entri diary
  final String content; // Konten/isi diary

  // Emoji yang digunakan untuk mengekspresikan mood/emosi pada entri
  final String emoji; // Emoji pada entri

  // Background entri diary, bisa berupa warna atau gambar (opsional)
  final String? background; // Latar belakang diary (opsional)

  // Warna teks pada entri diary (opsional)
  final String? textColor; // Warna teks (opsional)

  // Konten tambahan yang diletakkan di bawah konten utama (opsional)
  final String? contentBelow; // Konten tambahan di bawah (opsional)

  // Daftar URL gambar yang dilampirkan pada entri diary (opsional)
  final List<String>? imageUrls; // Daftar URL gambar (opsional)

  // Status favorit, menandakan apakah entri ini ditandai sebagai favorit
  final bool isFavorite; // Status favorit

  // Waktu pembuatan entri diary
  final DateTime createdAt; // Tanggal & waktu pembuatan

  // Waktu terakhir entri diary diubah (opsional)
  final DateTime? updatedAt; // Tanggal & waktu update terakhir (opsional)

  // Konstruktor untuk membuat instance DiaryEntry dengan parameter yang diperlukan dan opsional
  DiaryEntry({
    required this.id, // Wajib: ID unik entri
    required this.userId, // Wajib: ID user
    required this.title, // Wajib: Judul entri
    required this.content, // Wajib: Isi entri
    required this.emoji, // Wajib: Emoji
    required this.background, // Wajib: Background (bisa null)
    this.textColor, // Opsional: Warna teks
    this.contentBelow, // Opsional: Konten tambahan di bawah
    this.imageUrls, // Opsional: Daftar URL gambar
    required this.isFavorite, // Wajib: Status favorit
    required this.createdAt, // Wajib: Tanggal pembuatan
    this.updatedAt, // Opsional: Tanggal update terakhir
  });

  // Factory constructor untuk membuat DiaryEntry dari Map (biasanya dari database atau API)
  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'], // Ambil id dari map
      userId: map['user_id'], // Ambil user_id dari map
      title: map['title'] ?? '', // Ambil title, default '' jika null
      content: map['content'] ?? '', // Ambil content, default '' jika null
      emoji: map['emoji'] ?? '', // Ambil emoji, default '' jika null
      background:
          map['background'] ?? '', // Ambil background, default '' jika null
      textColor: map['text_color'], // Ambil text_color, bisa null
      contentBelow: map['content_below'], // Ambil content_below, bisa null
      // Konversi image_urls dari berbagai format (List atau String) menjadi List<String>
      imageUrls:
          (map['image_urls'] is List)
              ? (map['image_urls'] as List).map((e) => e.toString()).toList()
              : (map['image_urls'] != null && map['image_urls'] is String)
              ? (map['image_urls'] as String)
                  .replaceAll(RegExp(r'^{|}$'), '') // Hapus karakter { dan }
                  .split(',')
                  .map((e) => e.trim())
                  .toList()
              : [],
      isFavorite:
          map['is_favorite'] ?? false, // Ambil is_favorite, default false
      createdAt: DateTime.parse(
        map['created_at'],
      ), // Parse created_at ke DateTime
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(
                map['updated_at'],
              ) // Parse updated_at jika ada
              : null,
    ); // Kembalikan instance DiaryEntry
  }

  // Method untuk mengubah DiaryEntry menjadi Map<String, dynamic> (untuk disimpan ke database atau dikirim ke API)
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Sertakan id
      'user_id': userId, // Sertakan user_id
      'title': title, // Sertakan title
      'content': content, // Sertakan content
      'emoji': emoji, // Sertakan emoji
      'background':
          background ?? '', // Sertakan background, jika null jadi string kosong
      'text_color': textColor, // Sertakan text_color, bisa null
      'content_below': contentBelow, // Sertakan content_below, bisa null
      'image_urls': imageUrls, // Sertakan image_urls, bisa null
      'is_favorite': isFavorite, // Sertakan is_favorite
      'created_at':
          createdAt.toIso8601String(), // Format created_at ke ISO string
      'updated_at':
          updatedAt
              ?.toIso8601String(), // Format updated_at ke ISO string, bisa null
    };
  }
}
// Penjelasan:

// Setiap field pada kelas ini merepresentasikan atribut dari satu entri diary.
// Konstruktor digunakan untuk membuat objek baru dengan data yang sudah ditentukan.
// fromMap digunakan untuk mengonversi data dari Map (misal dari database) ke objek DiaryEntry.
// toMap digunakan untuk mengonversi objek DiaryEntry ke Map agar bisa disimpan ke database atau dikirim ke API.
// Komentar pada setiap baris menjelaskan fungsi dan kegunaan setiap bagian kode.
