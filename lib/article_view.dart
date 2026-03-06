import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'package:http/http.dart' as http;

class ArticleReader extends StatefulWidget {
  final String id;
  final String title;
  final String content; // Awalnya akan kosong dari main.dart
  final String url;
  final List<String> labels; 
  final bool isDarkMode;
  final VoidCallback onClose;
  final VoidCallback onLoadStart;
  final VoidCallback onLoadEnd;

  ArticleReader({
    required this.id,
    required this.title,
    required this.content,
    required this.url,
    required this.labels,
    required this.isDarkMode,
    required this.onClose,
    required this.onLoadStart,
    required this.onLoadEnd,
  });

  @override
  State<ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<ArticleReader> {
  late final WebViewController controller;
  String _currentContent = "";
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
    _initWebView();
    
    // Jika konten kosong (karena sistem RSS baru), kita download isinya sekarang
    if (_currentContent.isEmpty) {
      _downloadFullContent();
    }
  }

  // Fungsi untuk mengambil isi artikel secara utuh (On-Demand)
  Future<void> _downloadFullContent() async {
    setState(() => _isDownloading = true);
    widget.onLoadStart();
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        // Kita ambil HTML mentah dan biarkan WebView yang me-render
        // Ini jauh lebih ringan daripada parsing manual yang rumit
        setState(() {
          _currentContent = response.body;
          _isDownloading = false;
        });
        controller.loadHtmlString(_buildHtml(widget.isDarkMode));
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      debugPrint("Download error: $e");
    }
    widget.onLoadEnd();
  }

  @override
  void didUpdateWidget(ArticleReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.isDarkMode != widget.isDarkMode) {
      controller.setBackgroundColor(widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white);
      controller.loadHtmlString(_buildHtml(widget.isDarkMode));
    }
  }

  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => widget.onLoadStart(),
          onPageFinished: (url) => widget.onLoadEnd(),
        ),
      )
      ..loadHtmlString(_buildHtml(widget.isDarkMode));
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
    padding: 12px;
    overflow-x: hidden;
  }

  /* Menyembunyikan elemen blog yang tidak perlu */
  .header, .footer, .sidebar, .comments, #header, #footer { display: none !important; }

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

  svg { 
    max-width: 100% !important; 
    height: auto !important; 
    display: block; 
    margin: 10px auto; 
  }
  ${isDark ? 'svg { filter: invert(1) hue-rotate(180deg); }' : ''}
  img { max-width: 100%; height: auto; border-radius: 8px; }
</style>
</head>
<body>
  <h2 style="color: #FF0000;">${widget.title}</h2>
  $_currentContent
  <div style="height: 100px;"></div> 
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
        'content': _currentContent, // Simpan konten yang sudah lengkap
        'url': widget.url,
        'label': widget.labels.isNotEmpty ? widget.labels.first : "Gending"
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Berhasil disimpan ke Koleksi"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      body: Stack(
        children: [
          WebViewWidget(
            controller: controller,
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
            },
          ),
          if (_isDownloading)
            const Center(child: CircularProgressIndicator(color: Colors.red)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isDownloading ? null : _saveOffline,
        backgroundColor: Colors.red,
        mini: true, 
        child: const Icon(Icons.download_for_offline, color: Colors.white),
      ),
    );
  }
}