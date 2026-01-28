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

    // Filter Hijau Neon sesuai Blog
    String svgFilter = isDarkMode 
        ? "invert(48%) sepia(100%) saturate(5000%) hue-rotate(90deg) brightness(1.5)" 
        : "none";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onClose),
        title: const Text("Baca Notasi"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.greenAccent : Colors.blue[900]
              ),
            ),
            const Divider(height: 40),
            HtmlWidget(
              content,
              textStyle: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
              // PERBAIKAN SVG LONJONG & UKURAN
              customStylesBuilder: (element) {
                if (element.localName == 'svg' || element.localName == 'img') {
                  return {
                    'width': '100% !important',
                    'height': 'auto !important',
                    'filter': svgFilter,
                    'display': 'block',
                    'margin': '15px auto',
                    // Kunci agar tidak lonjong:
                    'object-fit': 'contain', 
                  };
                }
                if (element.localName == 'table') {
                  return {
                    'width': '100%',
                    'border': '1px solid ${isDarkMode ? "#333" : "#ccc"}',
                    'font-size': '14px',
                  };
                }
                return null;
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}