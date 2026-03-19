import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FooterWidget extends StatefulWidget {
  final int currentTab;
  final bool isDarkMode;
  final Function(int) onTabTap;
  final Function(bool) onThemeChanged;
  final Function(String, String) showInternalPage;
  final List<String> gendingLabels;
  final Function(String) onLabelTap;
  final List<Map<String, String>> sitemap; // Data dari main.dart
  final Function(Map<String, String>, Map<String, String>)? onTayubSubmit; 

  const FooterWidget({
    super.key,
    required this.currentTab,
    required this.isDarkMode,
    required this.onTabTap,
    required this.onThemeChanged,
    required this.showInternalPage,
    required this.gendingLabels,
    required this.onLabelTap,
    required this.sitemap,
    this.onTayubSubmit,
  });

  @override
  State<FooterWidget> createState() => _FooterWidgetState();

  // Fungsi-fungsi pembantu tampilan yang dipanggil dari main.dart
  Widget buildCatatan({required Widget child}) => _buildCatatanWrapper(child);
  Widget buildSetelan() => _buildSetelanContent();
  Widget buildTayubMode() => _TayubModeView(
    onTayubSubmit: onTayubSubmit, 
    isDarkMode: isDarkMode, 
    sitemap: sitemap
  );

Widget _buildCatatanWrapper(Widget child) {
  return Container( 
    width: double.infinity,
    height: double.infinity,
    color: isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
    child: child, // Di sini nanti isi daftar catatannya tampil
  );
}

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
          onTap: () => showInternalPage("Tentang", "Sinsangnot adalah aplikasi koleksi notasi gending Jawa yang dikembangkan untuk memudahkan akses dan eksplorasi musik tradisional. Aplikasi ini bersifat open-source dan terus dikembangkan dengan dukungan komunitas. Semua data notasi diambil dari sumber yang sah dan dihormati hak ciptanya. Pembuatan aplikasi ini dilakukan dengan tujuan untuk melestarikan dan memperluas akses terhadap warisan budaya musik Jawa. Dengan alat yang seadanya saya sebagai Developer apk sangat berterimikasih atas penggunaan aplikasi yang sederhana ini. Komentar serta masukan anda sangat bermanfaat bagi kami dan Terima kasih telah menggunakan Sinsangnot!"),
        ),
        ListTile(
          leading: const Icon(Icons.favorite, color: Colors.red),
          title: const Text("Dukungan Kreator"),
          subtitle: const Text("Donasi seiklasnya lewat aplikasi Dana tanpa minimal transaksi"),
          onTap: () async {
            final Uri url = Uri.parse("https://link.dana.id/minta?full_url=https://qr.dana.id/v1/281012012021032196591526");
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
        BottomNavigationBarItem(icon: Icon(Icons.note_alt_outlined), label: 'Catatan'),
        BottomNavigationBarItem(icon: Icon(Icons.library_music, size: 30), label: 'Tayub'),
        BottomNavigationBarItem(icon: Icon(Icons.download_done), label: 'Koleksi'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
      ],
    );
  }
}

// --- WIDGET KHUSUS MODE TAYUB DENGAN VALIDASI ---
class _TayubModeView extends StatefulWidget {
  final Function(Map<String, String>, Map<String, String>)? onTayubSubmit;
  final bool isDarkMode;
  final List<Map<String, String>> sitemap;

  const _TayubModeView({this.onTayubSubmit, required this.isDarkMode, required this.sitemap});

  @override
  State<_TayubModeView> createState() => _TayubModeViewState();
}

class _TayubModeViewState extends State<_TayubModeView> {
  final TextEditingController _c1 = TextEditingController();
  final TextEditingController _c2 = TextEditingController();
  
  Map<String, String>? _selected1;
  Map<String, String>? _selected2;
  List<Map<String, String>> _suggestions = [];
  int _activeField = 0; 

void _filterSitemap(String query, int field) {
    setState(() {
      _activeField = field;
      if (query.isEmpty) {
        _suggestions = [];
      } else {
        // Ambil saran dari sitemap
        var allSitemap = widget.sitemap.where((s) => 
            s['title']!.toLowerCase().contains(query.toLowerCase())).toList();

        // LOGIKA FILTER: Jika Offline, hanya tampilkan yang judulnya ada di koleksi terunduh
        // (Asumsi: User hanya bisa pilih yang sudah ada datanya di HP)
        // Jika Mas ingin membatasi secara ketat, Mas bisa mengirim daftar judul offline dari main.dart
        
        _suggestions = allSitemap.take(5).toList();
      }
      
      if (field == 1) _selected1 = null;
      if (field == 2) _selected2 = null;
    });
  }

  void _selectSitemap(Map<String, String> item) {
    setState(() {
      if (_activeField == 1) {
        _c1.text = item['title']!;
        _selected1 = item;
      } else {
        _c2.text = item['title']!;
        _selected2 = item;
      }
      _suggestions = [];
      _activeField = 0;
    });
  }

  void _resetTayub() {
    FocusScope.of(context).unfocus();
    setState(() {
      _c1.clear();
      _c2.clear();
      _selected1 = null;
      _selected2 = null;
      _suggestions = [];
      _activeField = 0;
    });
  }

@override
  Widget build(BuildContext context) {
    bool isValid = _selected1 != null && _selected2 != null;

    // KUNCINYA: Membungkus Stack dengan Container agar Full Layar & Tidak Tembus
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                const Icon(Icons.theater_comedy, size: 60, color: Colors.red),
                const SizedBox(height: 10),
                const Text("Mode Tayub", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Pilih 2 notasi dari saran sitemap", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                _buildSearchBox(_c1, "Cari Gending 1...", 1, _selected1 != null),
                const SizedBox(height: 15),
                const Icon(Icons.link, color: Colors.red),
                const SizedBox(height: 15),
                _buildSearchBox(_c2, "Cari Gending 2...", 2, _selected2 != null),
                const SizedBox(height: 15),
                
                // Tombol Reset Pilihan
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: _resetTayub,
                      icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                      label: const Text("Reset Pilihan", 
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isValid ? Colors.red : Colors.grey[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: isValid ? () => widget.onTayubSubmit!(_selected1!, _selected2!) : null,
                    child: Text("BUKA 2 NOTASI", 
                      style: TextStyle(color: isValid ? Colors.white : Colors.white24, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // Floating Suggestions (Saran Sitemap) tetap aman di sini
          if (_suggestions.isNotEmpty)
            Positioned(
              left: 25,
              right: 25,
              top: _activeField == 1 ? 210 : 315, 
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(10),
                color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.map((s) => ListTile(
                    dense: true,
                    title: Text(s['title']!, style: const TextStyle(fontSize: 14)),
                    onTap: () => _selectSitemap(s),
                  )).toList(),
                ),
              ),
            ),
        ], // Penutup children Stack
      ), // Penutup Stack
    ); // Penutup Container
  }

  Widget _buildSearchBox(TextEditingController controller, String hint, int field, bool isSelected) {
    return TextField(
      controller: controller,
      onChanged: (val) => _filterSitemap(val, field),
      style: TextStyle(
        color: isSelected ? Colors.blue : (widget.isDarkMode ? Colors.white : Colors.black),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: isSelected 
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.cancel, color: Colors.red, size: 20),
        filled: true,
        fillColor: widget.isDarkMode ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}