import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'main.dart'; // Untuk akses model Article
import 'database_helper.dart';

class ArticleReader extends StatelessWidget {
  final Article? article; // Untuk mode tunggal
  final List<Article>? articles; // Untuk mode Tayub (Dual)
  final bool isDarkMode;
  final bool isDualMode;
  final VoidCallback onClose;

  const ArticleReader({
    super.key,
    this.article,
    this.articles,
    required this.isDarkMode,
    this.isDualMode = false,
    required this.onClose,
  });

  // Fungsi untuk memisahkan gambar WebP dan Lirik dari konten HTML blogger
  Map<String, String> _parseContent(String html) {
    String imageUrl = "";
    String lirik = "";

    // Ambil URL Gambar
    RegExp imgRegExp = RegExp(r'src="([^"]+)"');
    var imgMatch = imgRegExp.firstMatch(html);
    if (imgMatch != null) imageUrl = imgMatch.group(1) ?? "";

    // Ambil isi di dalam <pre class="lirik">
    RegExp lirikRegExp = RegExp(r'<pre class="lirik">([\s\S]*?)<\/pre>');
    var lirikMatch = lirikRegExp.firstMatch(html);
    if (lirikMatch != null) {
      lirik = lirikMatch.group(1)?.replaceAll('&nbsp;', ' ').trim() ?? "";
    }

    return {"image": imageUrl, "lirik": lirik};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: onClose,
        ),
        title: Text(
          isDualMode ? "Mode Tayub" : (article?.title ?? ""),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16),
        ),
        actions: [
          if (!isDualMode) IconButton(
            icon: const Icon(Icons.download_for_offline, color: Colors.red),
            onPressed: () => _saveToOffline(context, article!),
          )
        ],
      ),
      body: isDualMode ? _buildDualView() : _buildSingleView(article!),
    );
  }

  // Tampilan 1 Gending
  Widget _buildSingleView(Article art) {
    var data = _parseContent(art.content);
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4.0), // Padding Tipis sesuai permintaan
        child: Column(
          children: [
            _buildNotasiImage(data['image']!),
            if (data['lirik']!.isNotEmpty) _buildLirikBox(data['lirik']!),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Tampilan 2 Gending Vertikal (Mode Tayub)
  Widget _buildDualView() {
    return ListView.builder(
      itemCount: articles?.length ?? 0,
      itemBuilder: (context, index) {
        var data = _parseContent(articles![index].content);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Gending ${index + 1}: ${articles![index].title}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ),
            _buildNotasiImage(data['image']!),
            if (data['lirik']!.isNotEmpty) _buildLirikBox(data['lirik']!),
            const Divider(height: 40, thickness: 2, color: Colors.red),
          ],
        );
      },
    );
  }

  // Widget Penampil Gambar dengan Filter Mode Gelap
Widget _buildNotasiImage(String url) {
    if (url.isEmpty) return const SizedBox();

    // Matriks Invert (Pembalik Warna)
    const invertMatrix = ColorFilter.matrix([
      -1,  0,  0, 0, 255,
       0, -1,  0, 0, 255,
       0,  0, -1, 0, 255,
       0,  0,  0, 1,   0,
    ]);

    return RepaintBoundary( // Memisahkan proses render gambar agar scroll lirik jadi enteng
      child: ColorFiltered(
        // AKTIFKAN filter HANYA di Mode Gelap
        colorFilter: isDarkMode ? invertMatrix : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          fit: BoxFit.contain,
          // OPTIMASI: Batasi lebar gambar di RAM (misal 1000px saja)
          // Ini kunci agar scroll di Mode Terang tidak ngadat
          memCacheWidth: 1000, 
          placeholder: (context, url) => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: Colors.red),
            ),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
        ),
      ),
    );
  }

  // Widget Penampil Lirik dari tag <pre>
  Widget _buildLirikBox(String lirik) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lirik,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          fontFamily: 'monospace', // Agar spasi lirik tetap presisi
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

 Future<void> _saveToOffline(BuildContext context, Article art) async {
  try {
    // 1. Ambil data konten (Gambar & Lirik)
    var data = _parseContent(art.content);
    String imageUrl = data['image'] ?? "";
    String localPath = "";

    // 2. Proses Download Gambar jika ada linknya
    if (imageUrl.isNotEmpty) {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Cari folder privat aplikasi
        final directory = await getApplicationDocumentsDirectory();
        // Beri nama file unik berdasarkan ID artikel (ambil bagian terakhir URL)
        String fileName = "img_${art.id.split('/').last}.webp"; 
        String filePath = p.join(directory.path, fileName);
        
        // Simpan file ke memori HP
        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        localPath = filePath; // Simpan alamat lokalnya
      }
    }

    // 3. Simpan ke Database (Termasuk localImagePath)
    final db = await DatabaseHelper.getDatabase();
    await db.insert(
      'offline_posts',
      {
        'id': art.id,
        'title': art.title,
        'content': art.content,
        'url': art.url,
        'label': art.label,
        'imageUrl': imageUrl,
        'localImagePath': localPath, // Ini kunci agar thumbnail muncul offline
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Berhasil simpan ke Koleksi Offline"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gagal simpan: $e"), backgroundColor: Colors.red),
    );
  }
}