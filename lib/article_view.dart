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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onClose),
        title: const Text("Detail Notasi", style: TextStyle(fontSize: 16)),
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.greenAccent : const Color(0xFF0D47A1),
                ),
              ),
              const Divider(height: 30, thickness: 1),
              
              HtmlWidget(
                content,
                // JURUS PAMUNGKAS: Ambil alih elemen SVG
                customWidgetBuilder: (element) {
                  if (element.localName == 'svg') {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 15),
                      // 1. PAKSA WARNA JADI HIJAU NEON (Hanya di Mode Gelap)
                      child: ColorFiltered(
                        colorFilter: isDarkMode 
                          ? const ColorFilter.matrix([
                              0, 0, 0, 0, 0,       // R
                              0, 1.5, 0, 0, 0,     // G (Hijau diperkuat)
                              0, 0, 0, 0, 0,       // B
                              -1, -1, -1, 1, 255,  // Invert warna hitam ke terang
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                        // 2. PAKSA AGAR TIDAK GEPENG
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: HtmlWidget(element.outerHtml),
                        ),
                      ),
                    );
                  }
                  return null;
                },
                
                customStylesBuilder: (element) {
                  // Styling Tabel
                  if (element.localName == 'table') {
                    return {
                      'width': '100% !important',
                      'border-collapse': 'collapse',
                      'border': '1px solid ${isDarkMode ? "#333" : "#ccc"}',
                    };
                  }
                  // Styling Lirik (Sudah bagus)
                  if (element.classes.contains('lirik') || element.localName == 'pre') {
                    return {
                      'font-family': 'Georgia, serif',
                      'font-style': 'italic',
                      'background-color': isDarkMode ? '#0a1a0a' : '#fff9f0',
                      'padding': '15px',
                      'border-left': '5px solid #ff9800',
                      'margin': '15px 0',
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
      ),
    );
  }
}