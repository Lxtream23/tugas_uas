class DiaryEntry {
  final String id; // Tambahkan field id
  final String userId; // Tambahkan field userId
  final String title; // Tambahkan field title
  final String content; // Tambahkan field content
  final String emoji; // Tambahkan field emoji
  final String? background; // Tambahkan field background
  final String? textColor; // Tambahkan field textColor
  final String? contentBelow; // Tambahkan field contentBelow
  final List<String>? imageUrls; // Tambahkan field imageUrl
  final DateTime createdAt; // Tambahkan field createdAt
  final DateTime? updatedAt; // Tambahkan field updatedAt

  DiaryEntry({
    required this.id, // Tambahkan id sebagai parameter
    required this.userId, // Tambahkan userId sebagai parameter
    required this.title, // Tambahkan title sebagai parameter
    required this.content, // Tambahkan content sebagai parameter
    required this.emoji, // Tambahkan emoji sebagai parameter
    required this.background, // Tambahkan background sebagai parameter
    this.textColor, // Tambahkan textColor sebagai parameter opsional
    this.contentBelow, // Tambahkan contentBelow sebagai parameter opsional
    this.imageUrls, // Tambahkan imageUrl sebagai parameter opsional
    required this.createdAt, // Tambahkan createdAt sebagai parameter
    this.updatedAt, // Tambahkan updatedAt sebagai parameter opsional
  });

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'], // Ambil id dari map
      userId: map['user_id'], // Ambil user_id dari map
      title: map['title'] ?? '', // Ambil title dari map
      content: map['content'] ?? '', // Ambil content dari map
      emoji: map['emoji'] ?? '', // Ambil emoji dari map
      background: map['background'] ?? '', // Ambil background dari map
      textColor: map['text_color'], // Ambil text_color dari map
      contentBelow: map['content_below'], // Ambil content_below dari map
      imageUrls:
          (map['image_urls'] is List)
              ? (map['image_urls'] as List).map((e) => e.toString()).toList()
              : (map['image_urls'] != null && map['image_urls'] is String)
              ? (map['image_urls'] as String)
                  .replaceAll(RegExp(r'^{|}$'), '') // hapus { dan }
                  .split(',')
                  .map((e) => e.trim())
                  .toList()
              : [],
      // Ambil image_url dari map
      createdAt: DateTime.parse(map['created_at']), // Ambil created_at dari map
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(map['updated_at'])
              : null,
    ); // Buat instance DiaryEntry dari map
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Sertakan id dalam map
      'user_id': userId, // Sertakan user_id dalam map
      'title': title, // Sertakan title dalam map
      'content': content, // Sertakan content dalam map
      'emoji': emoji, // Sertakan emoji dalam map
      'background':
          background ??
          '', // Sertakan background dalam map, jika null gunakan string kosong
      'text_color': textColor, // Sertakan text_color dalam map
      'content_below':
          contentBelow, // Sertakan content_below dalam map, jika null gunakan null
      'image_urls': imageUrls, // Sertakan image_url dalam map
      'created_at':
          createdAt.toIso8601String(), // Sertakan created_at dalam map
      'updated_at':
          updatedAt
              ?.toIso8601String(), // Sertakan updated_at dalam map, jika null gunakan null
    };
  }
}
