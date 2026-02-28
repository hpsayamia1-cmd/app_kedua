import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ArticleReader extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback onClose;

  // Kita biarkan main.dart memberi tahu apakah sekarang lagi mode gelap atau tidak
  ArticleReader({required this.title, required this.content, required this.onClose});

  @override
  State<ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<ArticleReader> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller kosong dulu
    controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
  }

  // Fungsi ini dipanggil setiap kali widget dibangun ulang (termasuk saat ganti tema)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    controller.setBackgroundColor(isDark ? const Color(0xFF0A0A0A) : Colors.white);
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
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    color: $textColor;
    background: $bgColor;
    padding: 18px;
    margin: 0;
  }
  h1 { color: $accentColor; font-size: 22px; margin-bottom: 5px; font-weight: bold; }
  .divider { height: 1px; background: orange; margin-bottom: 20px; opacity: 0.7; }
  
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
    font-size: 15px;
  }
  
  /* Supaya SVG Responsif dan Licin */
  svg {
    max-width: 100%;
    height: auto !important;
    display: block;
    margin: 20px auto;
  }

  /* Trik Mode Gelap untuk SVG agar warnanya balik jadi putih */
  ${isDark ? 'svg { filter: invert(1) hue-rotate(180deg) brightness(1.2); }' : ''}
  
  img { max-width: 100%; height: auto; border-radius: 8px; }
</style>
</head>
<body>
  <h1>${widget.title}</h1>
  <div class="divider"></div>
  <div class="content-body">
    ${widget.content}
  </div>
  <div style="height: 50px;"></div>
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
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onClose,
        ),
        title: const Text("Detail Notasi", style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      // WebViewWidget inilah yang merender konten dengan mesin browser
      body: WebViewWidget(controller: controller),
    );
  }
}