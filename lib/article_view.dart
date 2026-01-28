import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class ArticleReader extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onClose;

  ArticleReader({required this.title, required this.content, required this.onClose});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Filter warna hijau neon persis template blog Anda
    String svgFilter = isDarkMode 
        ? "invert(48%) sepia(100%) saturate(5000%) hue-rotate(90deg) brightness(1.5) contrast(1)" 
        : "none";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onClose),
        title: const Text("Detail Notasi", style: TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.greenAccent : Colors.blue[900],
              ),
            ),
            const Divider(height: 30),
            HtmlWidget(
              content,
              // INI ADALAH KUNCI AGAR TAMPILAN SAMA PERSIS DENGAN BLOG
              customStylesBuilder: (element) {
                // 1. Perbaikan SVG agar tidak lonjong dan berubah warna
                if (element.localName == 'svg' || element.localName == 'img') {
                  return {
                    'width': '100% !important',
                    'height': 'auto !important',
                    'filter': svgFilter,
                    'display': 'block',
                    'margin': '10px auto',
                    'object-fit': 'contain', // Menjaga proporsi agar tidak lonjong
                  };
                }

                // 2. Perbaikan Tabel agar rapi seperti di Blog
                if (element.localName == 'table') {
                  return {
                    'width': '100% !important',
                    'border-collapse': 'collapse',
                    'border': '1px solid ${isDarkMode ? "#333" : "#ccc"}',
                    'margin': '10px 0',
                  };
                }
                if (element.localName == 'td' || element.localName == 'th') {
                  return {
                    'border': '1px solid ${isDarkMode ? "#444" : "#eee"}',
                    'padding': '8px',
                    'text-align': 'center',
                  };
                }

                // 3. Perbaikan Lirik (Gaya Georgia & Border Oranye)
                if (element.classes.contains('lirik') || element.localName == 'pre') {
                  return {
                    'font-family': 'Georgia, serif',
                    'font-style': 'italic',
                    'color': isDarkMode ? '#ddd' : '#333',
                    'background-color': isDarkMode ? '#0a1a0a' : '#fff9f0',
                    'padding': '15px',
                    'border-left': '4px solid #ff9800', // Border oranye khas blog Anda
                    'margin': '15px 0',
                    'white-space': 'pre-wrap',
                    'line-height': '1.6',
                  };
                }

                return null;
              },
              textStyle: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}