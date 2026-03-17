import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Import model Article dari main.dart jika diperlukan, 
// atau pastikan callback mengirimkan data yang sesuai.

class FooterWidget extends StatefulWidget {
  final int currentTab;
  final bool isDarkMode;
  final Function(int) onTabTap;
  final Function(bool) onThemeChanged;
  final Function(String, String) showInternalPage;
  final List<String> gendingLabels;
  final Function(String) onLabelTap;
  final Function(dynamic, dynamic)? onTayubSubmit; // Callback untuk kirim 2 gending

  const FooterWidget({
    super.key,
    required this.currentTab,
    required this.isDarkMode,
    required this.onTabTap,
    required this.onThemeChanged,
    required this.showInternalPage,
    required this.gendingLabels,
    required this.onLabelTap,
    this.onTayubSubmit,
  });

  @override
  State<FooterWidget> createState() => _FooterWidgetState();

  // Fungsi eksternal untuk dipanggil di main.dart
  Widget buildJelajah() => _buildJelajahContent();
  Widget buildSetelan() => _buildSetelanContent();
  Widget buildTayubMode() => _TayubModeView(onTayubSubmit: onTayubSubmit, isDarkMode: isDarkMode);

  // Helper untuk Jelajah (Tanpa Thumbnail/Aset)
  Widget _buildJelajahContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Eksplorasi Notasi", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("Cari berdasarkan kategori atau klasifikasi gending", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 25),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: gendingLabels.map((label) {
              return InkWell(
                onTap: () => onLabelTap(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white10 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: isDarkMode ? Colors.white24 : Colors.black12),
                  ),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Helper untuk Setelan
  Widget _buildSetelanContent() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        const Padding(
          padding: EdgeInsets.all(15),
          child: Text("Pengaturan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: const Text("Mode Gelap"),
          secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.red),
          value: isDarkMode,
          onChanged: onThemeChanged,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("Tentang Sinsangnot"),
          onTap: () => showInternalPage("Tentang", "Digitalisasi notasi gending Jawa untuk memudahkan para seniman dan akademisi."),
        ),
        ListTile(
          leading: const Icon(Icons.favorite, color: Colors.red),
          title: const Text("Dukungan Kreator"),
          subtitle: const Text("Donasi untuk pengembangan aplikasi"),
          onTap: () async {
            final Uri url = Uri.parse("https://link.dana.id/qr/MASUKKAN_ID_DANA_KAMU");
            if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }
}

class _FooterWidgetState extends State<FooterWidget> {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentTab,
      type: BottomNavigationBarType.fixed,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.grey,
      onTap: widget.onTabTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Jelajah'),
        BottomNavigationBarItem(icon: Icon(Icons.library_music, size: 30), label: 'Tayub'),
        BottomNavigationBarItem(icon: Icon(Icons.download_done), label: 'Koleksi'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
      ],
    );
  }
}

// Widget Khusus Mode Tayub (Dual Search)
class _TayubModeView extends StatefulWidget {
  final Function(dynamic, dynamic)? onTayubSubmit;
  final bool isDarkMode;
  const _TayubModeView({this.onTayubSubmit, required this.isDarkMode});

  @override
  State<_TayubModeView> createState() => _TayubModeViewState();
}

class _TayubModeViewState extends State<_TayubModeView> {
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons. theater_comedy, size: 60, color: Colors.red),
          const SizedBox(height: 10),
          const Text("Mode Tayub", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Buka 2 notasi sekaligus secara vertikal", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          _buildSearchBox(_c1, "Cari Gending 1..."),
          const SizedBox(height: 15),
          _buildSearchBox(_c2, "Cari Gending 2..."),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () {
                // Di sini nanti logika mengambil data Artikel berdasarkan judul di controller
                // Untuk sementara, kita kirimkan teksnya saja atau panggil fungsi pencarian
                if (_c1.text.isNotEmpty && _c2.text.isNotEmpty) {
                   // Callback ke main.dart untuk memproses dual view
                   // onTayubSubmit akan diisi logika pencarian di main.dart
                }
              },
              child: const Text("BUKA 2 NOTASI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: widget.isDarkMode ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}