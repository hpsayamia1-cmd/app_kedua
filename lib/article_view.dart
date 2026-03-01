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
  final List<String> labels; // Tambahan untuk simpan label offline
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
            _injectCleanStyle();
          },
        ),
      )
      ..loadHtmlString(_buildHtml(isDark));
  }

  void _injectCleanStyle() {
    controller.runJavaScript("""
      var style = document.createElement('style');
      style.innerHTML = '.header-outer, .nav-outer, .footer-outer, #header, #footer, .sidebar, .post-title, .entry-title { display: none !important; } body { padding: 10px !important; }';
      document.head.appendChild(style);
    """);
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
    padding: 15px;
  }
  h1 { font-size: 22px; color: #FF0000; margin-bottom: 10px; padding-top: 10px; }
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
  svg { max-width: 100% !important; height: auto !important; display: block; margin: 20px auto; }
  ${isDark ? 'svg { filter: invert(1) hue-rotate(180deg); }' : ''}
  img { max-width: 100%; height: auto; border-radius: 8px; }
</style>
</head>
<body>
  <h1>${widget.title}</h1>
  ${widget.content}
  <div style="height: 100px;"></div> 
</body>
</html>
""";
  }

  Future<void> _saveOffline() async {
    try {
      final dbPath = await getDatabasesPath();
      // Pastikan versi database sesuai dengan main.dart (v3)
      final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 3);
      
      await db.insert('offline_posts', {
        'id': widget.id,
        'title': widget.title,
        'content': widget.content,
        'url': widget.url,
        'labels': json.encode(widget.labels) // Simpan label sebagai JSON string
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Berhasil disimpan ke Koleksi"), 
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal menyimpan")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
        ),
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
        centerTitle: false,
        elevation: 0,
      ),
      body: WebViewWidget(
        controller: controller,
        gestureRecognizers: {
          Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveOffline,
        backgroundColor: Colors.red,
        elevation: 4,
        icon: const Icon(Icons.download_for_offline, color: Colors.white),
        label: const Text("Simpan Offline", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}