import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Tambahkan import ini untuk menangani gesture
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class ArticleReader extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback onClose;

  ArticleReader({required this.title, required this.content, required this.onClose});

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
      // Tambahkan ini agar background transparan saat loading
      ..setBackgroundColor(isDark ? const Color(0xFF0A0A0A) : Colors.white)
      ..loadHtmlString(_buildHtml(isDark));
  }

  // Kita gunakan didChangeDependencies untuk memastikan tema terdeteksi dengan benar
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    controller.loadHtmlString(_buildHtml(isDark));
  }

  String _buildHtml(bool isDark) {
    final lirikBg = isDark ? "#1a1a1a" : "#fff9f0";
    final textColor = isDark ? "#ffffff" : "#222222";
    final bgColor = isDark ? "#0A0A0A" : "#ffffff";
    final accentColor = isDark ? "#69f0ae" : "#0d47a1";

    return """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    font-family: sans-serif;
    line-height: 1.6;
    color: $textColor;
    background: $bgColor;
    padding: 18px;
    margin: 0;
    /* Memastikan body bisa di-scroll secara internal */
    overflow-y: auto; 
    -webkit-overflow-scrolling: touch;
  }
  h1 { color: $accentColor; font-size: 24px; margin-bottom: 5px; }
  .divider { height: 1px; background: orange; margin-bottom: 20px; }
  .lirik, pre {
    background-color: $lirikBg;
    color: $textColor;
    padding: 15px;
    border-left: 5px solid #ff9800;
    margin: 15px 0;
    font-style: italic;
    white-space: pre-wrap;
    word-break: break-word;
    border-radius: 4px;
  }
  svg {
    max-width: 100%;
    height: auto;
    display: block;
    margin: 15px auto;
  }
  ${isDark ? 'svg { filter: invert(1) hue-rotate(180deg); }' : ''}
  img { max-width: 100%; height: auto; border-radius: 8px; }
</style>
</head>
<body>
  <h1>${widget.title}</h1>
  <div class="divider"></div>
  ${widget.content}
  <div style="height: 60px;"></div> 
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0A0A0A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.blue[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onClose,
        ),
        title: const Text("Detail Notasi", style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      // Membungkus dengan SafeArea dan memberikan GestureRecognizers
      body: SafeArea(
        child: WebViewWidget(
          controller: controller,
          // BAGIAN PENTING: Mengizinkan WebView menangani scroll secara vertikal
          gestureRecognizers: {
            Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
            Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
          },
        ),
      ),
    );
  }
}