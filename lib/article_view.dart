import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class ArticleReader extends StatefulWidget {
  final String id;
  final String title;
  final String content;
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            widget.onLoadStart();
          },
          onPageFinished: (url) {
            _applyStylesAndTheme();
            setState(() => _isLoading = false);
            widget.onLoadEnd();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // --- KUNCI SINKRONISASI TEMA & PEMBERSIHAN ---
  void _applyStylesAndTheme() {
    // 1. Atur atribut tema sesuai APK
    String themeValue = widget.isDarkMode ? 'dark' : 'light';
    
    // 2. CSS untuk menyembunyikan header dan judul sesuai template blog Anda
    String css = """
      /* Sembunyikan Header, Navigasi, dan Footer blog */
      header, .nav-content, .theme-wrapper, .footer-content, #header, .post-title, .entry-title { 
        display: none !important; 
      }
      /* Hilangkan margin/padding berlebih agar pas di layar APK */
      body, .main-content { 
        padding-top: 0 !important; 
        margin-top: 0 !important; 
      }
      .post-body { padding: 10px !important; }
    """;

    // Eksekusi JavaScript di dalam WebView
    controller.runJavaScript("""
      (function() {
        // Terapkan Tema
        if ('$themeValue' === 'light') {
          document.documentElement.setAttribute('data-theme', 'light');
        } else {
          document.documentElement.removeAttribute('data-theme');
        }
        
        // Suntikkan CSS Pembersih
        var style = document.createElement('style');
        style.innerHTML = `$css`;
        document.head.appendChild(style);
      })();
    """);
  }

  @override
  void didUpdateWidget(ArticleReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _applyStylesAndTheme();
    }
  }

  Future<void> _saveOffline() async {
    try {
      // Kita ambil HTML saat ini untuk simpan offline
      final String? html = await controller.runJavaScriptReturningResult("document.documentElement.outerHTML") as String?;
      
      final dbPath = await getDatabasesPath();
      final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 3);
      
      await db.insert('offline_posts', {
        'id': widget.id,
        'title': widget.title,
        'content': html ?? "", 
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
          if (_isLoading)
            Container(
              color: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
              child: const Center(child: CircularProgressIndicator(color: Colors.red)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _saveOffline,
        backgroundColor: Colors.red,
        mini: true, 
        child: const Icon(Icons.download_for_offline, color: Colors.white),
      ),
    );
  }
}