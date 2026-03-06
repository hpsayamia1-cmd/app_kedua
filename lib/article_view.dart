import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class ArticleReader extends StatefulWidget {
  final String id, title, content, url;
  final List<String> labels; 
  final bool isDarkMode;
  final VoidCallback onClose, onLoadStart, onLoadEnd;

  ArticleReader({
    required this.id, required this.title, required this.content, 
    required this.url, required this.labels, required this.isDarkMode,
    required this.onClose, required this.onLoadStart, required this.onLoadEnd,
  });

  @override
  State<ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<ArticleReader> {
  late final WebViewController controller;
  bool _isLoading = true;
  bool _isOfflineContent = false;

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
            _applyThemeImmediately(); // Suntik tema SEGERA saat mulai loading
          },
          onPageFinished: (url) {
            _applyThemeImmediately(); // Suntik lagi saat selesai
            setState(() => _isLoading = false);
            widget.onLoadEnd();
          },
          onWebResourceError: (error) {
            // Jika error koneksi, coba muat dari database
            _loadFromDatabase();
          },
        ),
      );
    
    _checkConnectivityAndLoad();
  }

  Future<void> _checkConnectivityAndLoad() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        controller.loadRequest(Uri.parse(widget.url));
      } else {
        _loadFromDatabase();
      }
    } catch (_) {
      _loadFromDatabase();
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final db = await openDatabase(p.join(dbPath, 'puska.db'));
      final List<Map<String, dynamic>> maps = await db.query(
        'offline_posts', where: 'id = ?', whereArgs: [widget.id]
      );

      if (maps.isNotEmpty) {
        String savedHtml = maps.first['content'];
        setState(() { _isOfflineContent = true; _isLoading = false; });
        controller.loadHtmlString(savedHtml);
      } else {
        // Jika di DB pun tidak ada
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // KUNCI: Suntikan CSS Brutal agar tema tidak mental
  void _applyThemeImmediately() {
    String themeValue = widget.isDarkMode ? 'dark' : 'light';
    String bgColor = widget.isDarkMode ? "#0F0F0F" : "#ffffff";
    String textColor = widget.isDarkMode ? "#ffffff" : "#000000";

    String jsCode = """
      (function() {
        // 1. Ubah Atribut data-theme
        if ('$themeValue' === 'light') {
          document.documentElement.setAttribute('data-theme', 'light');
        } else {
          document.documentElement.removeAttribute('data-theme');
        }
        
        // 2. Paksa Style Dasar agar tidak putih kedip
        var style = document.getElementById('apk-theme-fix');
        if (!style) {
          style = document.createElement('style');
          style.id = 'apk-theme-fix';
          document.head.appendChild(style);
        }
        style.innerHTML = `
          body, html { background-color: $bgColor !important; color: $textColor !important; }
          header, .nav-content, .footer-content, .post-title { display: none !important; }
          svg { filter: ${widget.isDarkMode ? 'invert(0)' : 'invert(1)'}; } 
        `;
      })();
    """;
    controller.runJavaScript(jsCode);
  }

  @override
  void didUpdateWidget(ArticleReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _applyThemeImmediately();
    }
  }

  Future<void> _saveOffline() async {
    try {
      final String html = await controller.runJavaScriptReturningResult("document.documentElement.outerHTML") as String;
      // Bersihkan tanda kutip dari hasil JS
      String cleanHtml = html;
      if (html.startsWith('"') && html.endsWith('"')) {
        cleanHtml = html.substring(1, html.length - 1).replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
      }

      final dbPath = await getDatabasesPath();
      final db = await openDatabase(p.join(dbPath, 'puska.db'));
      
      await db.insert('offline_posts', {
        'id': widget.id, 'title': widget.title, 'content': cleanHtml, 
        'url': widget.url, 'label': widget.labels.first
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Disimpan ke Koleksi"), backgroundColor: Colors.red)
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
            gestureRecognizers: { Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()) },
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
        backgroundColor: Colors.red, mini: true, 
        child: const Icon(Icons.download_for_offline, color: Colors.white),
      ),
    );
  }
}