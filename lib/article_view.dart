import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class ArticleReader extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onClose;

  ArticleReader({
    required this.title,
    required this.content,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // KONFIGURASI WARNA BERDASARKAN CSS BLOG (sinsangnot.blogspot.com)
    String textColor = isDarkMode ? "#f0fdf4" : "#1e293b";
    String titleColor = isDarkMode ? "#00ff00" : "#0000ee"; // Hijau di Gelap, Biru di Terang
    String tableBg = isDarkMode ? "#1a1a1a" : "#F3F5EF";
    String tableBorder = isDarkMode ? "#333333" : "#bbbbbb";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.greenAccent : Colors.black),
          onPressed: onClose,
        ),
        title: Text(
          "Baca Notasi",
          style: TextStyle(color: isDarkMode ? Colors.greenAccent : Colors.black, fontSize: 16),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // JUDUL ARTIKEL (Gaya .post-title-full di CSS Blog)
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Segoe UI',
                color: Color(int.parse(titleColor.replaceFirst('#', '0xFF'))),
              ),
            ),
            const SizedBox(height: 20),
            
            // RENDERING KONTEN HTML DENGAN FILTER CSS UNTUK SVG
            HtmlWidget(
              content,
              textStyle: TextStyle(
                color: Color(int.parse(textColor.replaceFirst('#', '0xFF'))),
                fontSize: 16,
              ),
              customStylesBuilder: (element) {
                // FILTER HIJAU UNTUK SVG (Sama persis dengan filter di CSS b:skin kamu)
                if (element.localName == 'svg' || (element.localName == 'img' && element.attributes['src']?.contains('.svg') == true)) {
                  return {
                    'max-width': '100%',
                    'height': 'auto',
                    if (isDarkMode) 
                      'filter': 'invert(48%) sepia(100%) saturate(5000%) hue-rotate(90deg) brightness(200%) contrast(100%)'
                  };
                }

                // STYLE TABEL (Sesuai .table-2 di blog)
                if (element.localName == 'table') {
                  return {
                    'width': '100%',
                    'border-collapse': 'collapse',
                    'background-color': tableBg,
                    'border': '1px solid $tableBorder',
                  };
                }
                
                if (element.localName == 'td' || element.localName == 'th') {
                  return {
                    'border': '1px solid $tableBorder',
                    'padding': '6px',
                    'text-align': 'center',
                    'font-size': '14px',
                  };
                }

                // STYLE LIRIK (Sesuai class .lirik di blog)
                if (element.className == 'lirik' || element.localName == 'pre') {
                  return {
                    'font-family': 'Georgia, serif',
                    'text-align': 'center',
                    'border-top': '1px solid $tableBorder',
                    'border-bottom': '1px solid $tableBorder',
                    'padding': '15px 0',
                    'margin': '15px 0',
                    'white-space': 'pre-wrap',
                    'font-style': 'italic',
                  };
                }

                return null;
              },
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}