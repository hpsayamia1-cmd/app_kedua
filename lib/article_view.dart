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

    return ColorFiltered(
      // Logika Invert Warna: Jika Dark Mode, ubah Hitam jadi Putih
      colorFilter: isDarkMode 
          ? const ColorFilter.matrix([
              -1,  0,  0, 0, 255, // Red
               0, -1,  0, 0, 255, // Green
               0,  0, -1, 0, 255, // Blue
               0,  0,  0, 1,   0, // Alpha
            ])
          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity, // Paksa Full Layar
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
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
    final db = await DatabaseHelper.getDatabase();
    await db.insert('offline_posts', {
      'id': art.id,
      'title': art.title,
      'content': art.content,
      'url': art.url,
      'label': art.label
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Berhasil simpan ke Koleksi"), backgroundColor: Colors.red),
    );
  }
}