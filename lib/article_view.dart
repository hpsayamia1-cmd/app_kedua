import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF010A01)) // Warna BG aplikasi
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    return """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  /* TEMA GELAP SUPAYA SVG ITEM JADI PUTIH */
  body { 
    background: #010A01; 
    color: #eeeeee; 
    font-family: sans-serif; 
    padding: 15px;
    line-height: 1.6;
  }
  
  /* MEMBALIK WARNA GAMBAR/SVG AGAR TERLIHAT DI BG HITAM */
  img, svg { 
    max-width: 100% !important; 
    height: auto !important; 
    filter: invert(1) brightness(1.5); 
    margin: 10px 0;
  }

  /* CSS TABEL ANDA */
  .table-responsive, .table-responsive-2 { overflow-x: auto; margin-bottom: 15px; }
  table { width: 100%; border-collapse: collapse; color: #000; } /* Tabel tetap terang agar mudah baca notasi */
  td, th { border: 1px solid #bbb; padding: 8px; background: #f3f5ef; }
  
  /* CSS LIRIK ANDA */
  .lirik {
    border: #d37f0a 3px solid;
    border-radius: 10px;
    background: #ffffff;
    color: #000000;
    padding: 10px;
    white-space: pre-wrap;
    text-align: center;
    font-family: Tahoma;
  }
</style>
</head>
<body>
  <h2 style="color: #69F0AE;">${widget.title}</h2>
  ${widget.content}
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black,
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.close, color: Colors.redAccent), onPressed: widget.onClose),
              Expanded(child: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        Expanded(child: WebViewWidget(controller: controller)),
      ],
    );
  }
}