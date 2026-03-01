import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class ArticleReader extends StatefulWidget {
  final String title;
  final String content;
  final String url; // URL asli blog untuk tracking view
  final VoidCallback onClose;
  final VoidCallback onLoadStart;
  final VoidCallback onLoadEnd;

  ArticleReader({
    required this.title, 
    required this.content, 
    required this.url,
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
    final bool isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(isDark ? const Color(0xFF0F0F0F) : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => widget.onLoadStart(),
          onPageFinished: (url) {
            widget.onLoadEnd();
            // Injeksi CSS untuk hapus header/footer blog jika memuat URL asli
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
    overscroll-behavior-y: contain; 
  }
  
  /* Hilangkan divider dan judul karena sudah ada di header aplikasi */
  
  .lirik, pre {
    background-color: $lirikBg;
    color: $textColor;
    padding: 15px;
    border-left: 4px solid #FF0000; /* Merah YouTube */
    margin: 10px 0;
    font-size: 14px;
    white-space: pre-wrap;
    word-break: break-word;
    border-radius: 2px;
  }
  
  img { max-width: 100%; height: auto; border-radius: 4px; margin: 10px 0; }
  iframe { max-width: 100%; height: auto; }
</style>
</head>
<body>
  ${widget.content}
  <div style="height: 100px;"></div> 
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      // Kita tidak pakai AppBar di sini karena sudah ada Header di main.dart
      body: WebViewWidget(
        controller: controller,
        gestureRecognizers: {
          Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Berhasil disimpan ke Koleksi Offline")),
          );
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.download, color: Colors.white),
        label: const Text("Download", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}