import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    // Background color awal tetap diatur, tapi akan diupdate di build
  }

  // Fungsi buildHtml sekarang menerima context untuk cek tema
  String _buildHtml(BuildContext context) {
    // Deteksi apakah sedang Mode Gelap atau Terang
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Variabel warna dinamis
    String bgColor = isDark ? "#010A01" : "#F5F5F5";
    String textColor = isDark ? "#eeeeee" : "#222222";
    String cardBg = isDark ? "#08230dff" : "#dfe3e4ff"; // Hijau gelap vs Kuning krem
    String cardText = isDark ? "#e4dcdcff" : "#333333";
    String imgFilter = isDark ? "invert(1) brightness(1.5)" : "none";
    String accentColor = isDark ? "#69F0AE" : "#2E7D32";

    return """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  body { 
    background: $bgColor; 
    color: $textColor; 
    font-family: sans-serif; 
    padding: 15px; 
    line-height: 1.6; 
    transition: background 0.3s, color 0.3s;
  }
  h2 { color: $accentColor; }
  img, svg { 
    max-width: 100% !important; 
    height: auto !important; 
    filter: $imgFilter; 
    margin: 10px 0; 
  }
  .table-responsive, .table-responsive-2 { overflow-x: auto; margin-bottom: 15px; }
  table { width: 100%; border-collapse: collapse; color: #000; }
  td, th { border: 1px solid #bbb; padding: 8px; background: #f3f5ef; }
  
  .lirik { 
    border: #d37f0a 3px solid; 
    border-radius: 10px; 
    background: $cardBg; 
    color: $cardText; 
    padding: 10px; 
    white-space: pre-wrap; 
    text-align: center; 
  }
</style>
</head>
<body>
  <h2>${widget.title}</h2>
  ${widget.content}
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    // Update isi WebView setiap kali widget build (saat tema berubah)
    controller.loadHtmlString(_buildHtml(context));
    
    return Column(
      children: [
        Container(
          // Warna header reader mengikuti tema aplikasi
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent), 
                onPressed: widget.onClose
              ),
              Expanded(
                child: Text(
                  widget.title, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
                  ), 
                  overflow: TextOverflow.ellipsis
                )
              ),
            ],
          ),
        ),
        Expanded(
          child: WebViewWidget(
            controller: controller,
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
            },
          ),
        ),
      ],
    );
  }
}