import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sqflite/sqflite.dart'; 
import 'main.dart'; 
import 'database_helper.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class ArticleReader extends StatefulWidget {
  final Article? article;
  final List<Article>? articles;
  final bool isDarkMode;
  final bool isDualMode;
  final VoidCallback onClose;
  final bool isSaved;        
  final VoidCallback onDownload; 

  const ArticleReader({
    super.key,
    this.article,
    this.articles,
    required this.isDarkMode,
    this.isDualMode = false,
    required this.onClose,
    this.isSaved = false,
    required this.onDownload,
  });

  @override
  State<ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<ArticleReader> {
  late bool _localIsSaved;

void _showAdsThenDownload() {
    UnityAds.showVideoAd(
      placementId: 'Rewarded_Android',
      onComplete: (placementId) {
        // Iklan selesai, langsung jalankan fungsi simpan Mas
        _saveToOffline(context, widget.article!);
      },
      onFailed: (placementId, error, message) {
        // Iklan gagal (misal sinyal buruk), tetap izinkan simpan
        _saveToOffline(context, widget.article!);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _localIsSaved = widget.isSaved; 
  }

  Map<String, String> _parseContent(String html) {
    String imageUrl = "";
    String lirik = "";

    RegExp imgRegExp = RegExp(r'src="([^"]+)"');
    var imgMatch = imgRegExp.firstMatch(html);
    if (imgMatch != null) imageUrl = imgMatch.group(1) ?? "";

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
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      body: Stack(
        children: [
          // Konten Notasi & Lirik
          widget.isDualMode ? _buildDualView() : _buildSingleView(widget.article!),

          // Tombol Download Mengambang (Floating Pojok Kanan Bawah)
          if (!widget.isDualMode)
            Positioned(
              bottom: 30, 
              right: 20,  
              child: FloatingActionButton(
                elevation: 6,
                backgroundColor: _localIsSaved ? Colors.green : Colors.red,
                onPressed: _localIsSaved ? null : () => _showAdsThenDownload(),
                child: Icon(
                  _localIsSaved ? Icons.check : Icons.download_for_offline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleView(Article art) {
    var data = _parseContent(art.content);
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4.0), 
        child: Column(
          children: [
            _buildNotasiImage(data['image']!),
            if (data['lirik']!.isNotEmpty) _buildLirikBox(data['lirik']!),
            const SizedBox(height: 120), // Beri jarak agar tidak tertutup tombol FAB
          ],
        ),
      ),
    );
  }

  Widget _buildDualView() {
    return ListView.builder(
      itemCount: widget.articles?.length ?? 0,
      itemBuilder: (context, index) {
        var data = _parseContent(widget.articles![index].content);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Gending ${index + 1}: ${widget.articles![index].title}",
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

  Widget _buildNotasiImage(String url) {
    if (url.isEmpty) return const SizedBox();

    const invertMatrix = ColorFilter.matrix([
      -1,  0,  0, 0, 255,
       0, -1,  0, 0, 255,
       0,  0, -1, 0, 255,
       0,  0,  0, 1,   0,
    ]);

    return RepaintBoundary( 
      child: ColorFiltered(
        // PERBAIKAN: Pakai widget.isDarkMode
        colorFilter: widget.isDarkMode ? invertMatrix : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          fit: BoxFit.contain,
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

  Widget _buildLirikBox(String lirik) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20, left: 15, right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        // PERBAIKAN: Pakai widget.isDarkMode
        color: widget.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        lirik,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          fontFamily: 'monospace', 
          // PERBAIKAN: Pakai widget.isDarkMode
          color: widget.isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }
  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa asal klik luar untuk nutup
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.red),
                const SizedBox(width: 20),
                Text(
                  "Menyimpan ke Koleksi...",
                  style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveToOffline(BuildContext context, Article art) async {
    _showLoading(context);
    try {
      var data = _parseContent(art.content);
      String imageUrl = data['image'] ?? "";
      String localPath = "";

      if (imageUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          String fileName = "img_${art.id.split('/').last}.webp"; 
          String filePath = p.join(directory.path, fileName);
          
          File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          localPath = filePath; 
        }
      }

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
          'localImagePath': localPath, 
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    if (context.mounted) Navigator.of(context).pop();

      setState(() => _localIsSaved = true);
      widget.onDownload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Berhasil simpan ke Koleksi Offline"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal simpan: $e"), backgroundColor: Colors.red),
      );
    }
  }
}