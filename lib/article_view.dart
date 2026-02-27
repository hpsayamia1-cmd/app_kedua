import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class ArticleReader extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onClose;

  ArticleReader({required this.title, required this.content, required this.onClose});

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
          onPressed: onClose,
        ),
        title: const Text("Detail Notasi", style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(), // Tetap pilihan Anda
          padding: const EdgeInsets.all(18),      // Tetap padding 18
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.greenAccent : Colors.blue[900],
                ),
              ),
              const Divider(height: 30, thickness: 1, color: Colors.orange),

              HtmlWidget(
                content,
                customWidgetBuilder: (element) {
                  if (element.localName == 'svg') {
                    String svgCode = element.outerHtml;

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      // OPTIMASI 1: Matikan seleksi area khusus untuk SVG agar scroll licin
                      child: SelectionArea.disabled(
                        child: RepaintBoundary(
                          // OPTIMASI 2: ValueKey agar Flutter tidak build ulang saat scroll
                          key: ValueKey(svgCode.hashCode),
                          child: ColorFiltered(
                            colorFilter: isDarkMode
                                ? const ColorFilter.matrix([
                                    -1, 0, 0, 0, 255, 
                                    0, -1, 0, 0, 255, 
                                    0, 0, -1, 0, 255, 
                                    0, 0, 0, 1, 0,    
                                  ])
                                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                            child: FittedBox(
                              fit: BoxFit.contain, 
                              alignment: Alignment.center,
                              child: ClipRect(
                                child: HtmlWidget(svgCode),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
                customStylesBuilder: (element) {
                  if (element.classes.contains('lirik') || element.localName == 'pre') {
                    return {
                      'font-family': 'Georgia, serif',
                      'font-style': 'italic',
                      'background-color': isDarkMode ? '#1a1a1a' : '#fff9f0',
                      'padding': '15px',
                      'border-left': '4px solid #ff9800',
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