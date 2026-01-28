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
    
    // Warna judul yang pasti kelihatan
    Color titleColor = isDarkMode ? Colors.greenAccent : Colors.blue[900]!;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF010A01) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.blue[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), 
          onPressed: onClose
        ),
        title: const Text("Detail Notasi", style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          // Optimasi scroll: Berikan physics agar lebih smooth
          physics: const BouncingScrollPhysics(), 
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: titleColor, // Paksa warna muncul
                ),
              ),
              const Divider(height: 30, thickness: 1, color: Colors.orange),
              
              HtmlWidget(
                content,
                // Mengurangi beban render agar tidak lag
                renderMode: RenderMode.column, 
                textStyle: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
                customStylesBuilder: (element) {
                  if (element.localName == 'svg') {
                    return {
                      'width': '100% !important',
                      'height': 'auto !important',
                      // Gunakan invert sederhana: Hitam jadi Putih/Hijau
                      'filter': isDarkMode ? 'invert(1) sepia(1) saturate(5) hue-rotate(90deg)' : 'none',
                      'display': 'block',
                      'margin': '10px auto',
                    };
                  }
                  if (element.classes.contains('lirik') || element.localName == 'pre') {
                    return {
                      'font-family': 'Georgia, serif',
                      'background-color': isDarkMode ? '#0a1a0a' : '#fff9f0',
                      'padding': '12px',
                      'border-left': '4px solid #ff9800',
                    };
                  }
                  return null;
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}