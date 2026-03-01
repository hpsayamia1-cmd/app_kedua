import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

class ArticleReader extends StatefulWidget {
  final String id;
  final String title;
  final String content;
  final String url;
  final List<String> labels; 
  final VoidCallback onClose;
  final VoidCallback onLoadStart;
  final VoidCallback onLoadEnd;

  ArticleReader({
    required this.id,
    required this.title,
    required this.content,
    required this.url,
    required this.labels,
    required this.onClose,
    required this.onLoadStart,
    required this.onLoadEnd,
  });

  @override
  State<ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<ArticleReader> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final bool isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(isDark ? const Color(0xFF0F0F0F) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => widget.onLoadStart(),
          onPageFinished: (url) {
            widget.onLoadEnd();
          },
        ),
      )
      ..loadHtmlString(_buildHtml(isDark));
  }

  String _buildHtml(bool isDark) {
    final lirikBg = isDark ? "#1a1a1a" : "#f5f5f5";
    final textColor = isDark ? "#ffffff" : "#0F0F0F";
    final bgColor = isDark ? "#0F0F0F" : "#ffffff";

    return """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body {
    font-family: 'Roboto', sans-serif;
    line-height: 1.6;
    color: $textColor;
    background: $bgColor;
    margin: 0;
    padding: 10px; /* Padding lebih kecil agar lebih lega */
    overflow-x: hidden;
  }
  /* POIN: Judul H1 dihapus dari sini agar tampilan clean */
  .lirik, pre {
    background-color: $lirikBg;
    color: $textColor;
    padding: 15px;
    border-left: 5px solid #FF0000;
    margin: 15px 0;
    font-size: 15px;
    white-space: pre-wrap;
    word-break: break-word;
    border-radius: 4px;
  }
  svg { max-width: 100% !important; height: auto !important; display: block; margin: 10px auto; }
  ${isDark ? 'svg { filter: invert(1) hue-rotate(180deg); }' : ''}
  img { max-width: 100%; height: auto; border-radius: 8px; }
  /* Menghilangkan elemen blogger yang mungkin ikut terbawa */
  .header-outer, .nav-outer, .footer-outer, .post-title, .entry-title { display: none !important; }
</style>
</head>
<body>
  ${widget.content}
  <div style="height: 80px;"></div> 
</body>
</html>
""";
  }

  Future<void> _saveOffline() async {
    try {
      final dbPath = await getDatabasesPath();
      final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 3);
      
      await db.insert('offline_posts', {
        'id': widget.id,
        'title': widget.title,
        'content': widget.content,
        'url': widget.url,
        'labels': json.encode(widget.labels)
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Berhasil disimpan ke Koleksi"), 
          backgroundColor: Colors.red, // Samakan dengan tema YouTube
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      // POIN: AppBar dihilangkan agar Header di main.dart yang mengambil alih
      body: WebViewWidget(
        controller: controller,
        gestureRecognizers: {
          Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveOffline,
        backgroundColor: Colors.red,
        mini: true, // Ukuran mini agar tidak mengganggu notasi
        child: const Icon(Icons.download_for_offline, color: Colors.white),
      ),
    );
  }
}