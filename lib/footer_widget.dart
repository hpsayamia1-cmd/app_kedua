import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FooterWidget extends StatelessWidget {
  final int currentTab;
  final bool isDarkMode;
  final Function(int) onTabTap;
  final Function(bool) onThemeChanged;
  final Function(String, String) showInternalPage;
  final List<String> gendingLabels;
  final Function(String) onLabelTap;

  const FooterWidget({
    super.key,
    required this.currentTab,
    required this.isDarkMode,
    required this.onTabTap,
    required this.onThemeChanged,
    required this.showInternalPage,
    required this.gendingLabels,
    required this.onLabelTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentTab,
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      selectedItemColor: isDarkMode ? Colors.white : Colors.black,
      unselectedItemColor: Colors.grey,
      onTap: onTabTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Jelajah'),
        BottomNavigationBarItem(icon: Icon(Icons.download_done), label: 'Koleksi'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'), 
      ],
    );
  }

  // Tampilan Tab Jelajah - Optimal 2 Kolom 16:9 dengan Teks di Tengah
  Widget buildJelajah() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text("Kategori Gending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Scroll ditangani SingleChildScrollView
            itemCount: gendingLabels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,          // 2 Kolom
              crossAxisSpacing: 10,       // Jarak horizontal
              mainAxisSpacing: 10,        // Jarak vertikal
              childAspectRatio: 16 / 9,   // Rasio Foto 16:9
            ),
            itemBuilder: (context, index) {
              String label = gendingLabels[index];
              String assetPath = 'assets/gong6.png'; // Default

              // Logika pemilihan gambar (Sinkron dengan main.dart)
              String l = label.toLowerCase();
              if (l.contains('tayub')) assetPath = 'assets/gong1.png';
              else if (l.contains('slendro')) assetPath = 'assets/gong2.png';
              else if (l.contains('pelog')) assetPath = 'assets/gong3.png';
              else if (l.contains('ladrang')) assetPath = 'assets/ladrang.png';
              else if (l.contains('ketawang')) assetPath = 'assets/ketawang.png';
              else if (l.contains('ayak')) assetPath = 'assets/ayak.png';
              else if (l.contains('gending')) assetPath = 'assets/gong5.png';

              return InkWell(
                onTap: () => onLabelTap(label),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      // FOTO PNG BACKGROUND
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: isDarkMode ? Colors.white10 : Colors.grey[200],
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.cover, // Menutup area 16:9
                          errorBuilder: (c, e, s) => const Icon(Icons.music_video, color: Colors.red),
                        ),
                      ),
                      // Overlay Gelap Tipis agar teks lebih menonjol
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                        ),
                      ),
                      // TEKS DI TENGAH FOTO
                      Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1))
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Tampilan Tab Menu / Setelan
  Widget buildSetelan() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        SwitchListTile(
          title: const Text("Tema Gelap"), 
          secondary: const Icon(Icons.dark_mode),
          activeColor: Colors.red,
          value: isDarkMode, 
          onChanged: onThemeChanged,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline), 
          title: const Text("Tentang Sinsangnot"), 
          onTap: () => showInternalPage("Tentang", "Sinsangnot adalah perpustakaan digital notasi gending Jawa berkualitas tinggi."),
        ),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined), 
          title: const Text("Privacy Policy"), 
          onTap: () => showInternalPage("Privacy", "Kami menjamin data koleksi offline Anda tersimpan aman secara lokal."),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined), 
          title: const Text("Disclaimer"), 
          onTap: () => showInternalPage("Disclaimer", "Seluruh notasi adalah hasil digitalisasi kreatif untuk tujuan pelestarian budaya."),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.favorite, color: Colors.red), 
          title: const Text("Donasi Kreator"), 
          subtitle: const Text("Dukung pelestarian notasi Jawa"),
          onTap: () async {
            final Uri url = Uri.parse("https://link.dana.id/qr/MASUKKAN_ID_DANA_KAMU");
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          }, 
        ),
      ],
    );
  }
}