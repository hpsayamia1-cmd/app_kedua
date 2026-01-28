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
    // Ini akan mendeteksi apakah aplikasi sedang Mode Gelap atau Terang 
    // berdasarkan tombol yang kamu tekan di HomePage
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Sinkronkan warna dengan CSS Blog kamu
    String textColor = isDarkMode ? "#f0fdf4" : "#1e293b";
    String titleColor = isDarkMode ? "#00ff00" : "#0000ee";
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
          "Detail Notasi",
          style: TextStyle(color: isDarkMode ? Colors.greenAccent : Colors.black, fontSize: 16),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // JUDUL (Warna otomatis ganti Hijau/Biru saat tombol ditekan)
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
            
            HtmlWidget(
              content,
              textStyle: TextStyle(
                color: Color(int.parse(textColor.replaceFirst('#', '0xFF'))),
                fontSize: 16,
                fontFamily: 'Inter',
              ),
              // MEMPERBAIKI SVG GEDE & WARNA
              customStylesBuilder: (element) {
                // Targetkan elemen gambar atau SVG
                if (element.localName == 'svg' || 
                    element.localName == 'img' || 
                    (element.attributes['src']?.contains('.svg') ?? false)) {
                  return {
                    'width': '100%', // Agar tidak gede banget/meluber
                    'height': 'auto',
                    'display': 'block',
                    'margin': '10px auto',
                    // Filter hijau aktif jika isDarkMode true
                    if (isDarkMode) 
                      'filter': 'invert(48%) sepia(100%) saturate(5000%) hue-rotate(90deg) brightness(200%)'
                  };
                }

                // Styling Tabel
                if (element.localName == 'table') {
                  return {
                    'border': '1px solid $tableBorder',
                    'width': '100%',
                  };
                }

                // Styling Lirik
                if (element.className == 'lirik' || element.localName == 'pre') {
                  return {
                    'text-align': 'center',
                    'font-family': 'Georgia, serif',
                    'padding': '15px 0',
                    'border-top': '1px solid $tableBorder',
                    'border-bottom': '1px solid $tableBorder',
                  };
                }
                return null;
              },
            ),
            const SizedBox(height: 100), // Spasi bawah agar tidak mentok
          ],
        ),
      ),
    );
  }
}