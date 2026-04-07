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
  final List<Map<String, String>> sitemap;
  final Function(Map<String, String>, Map<String, String>)? onTayubSubmit; 
  final Function(Map<String, String>)? onSitemapSelected;

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
    this.onSitemapSelected,
  });

  @override
  State<FooterWidget> createState() => _FooterWidgetState();

  // Fungsi-fungsi pembantu tampilan yang dipanggil dari main.dart
  Widget buildCatatan({required Widget child}) => _buildCatatanWrapper(child);
  Widget buildSetelan() => _buildSetelanContent();
  Widget buildTayubMode() => _TayubModeView(
    onTayubSubmit: onTayubSubmit, 
    isDarkMode: isDarkMode, 
    sitemap: sitemap,
    onSitemapSelected: onSitemapSelected,
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
          onTap: () => showInternalPage("Tentang", "Sinsangnot adalah aplikasi koleksi notasi gending Jawa yang dikembangkan untuk memudahkan akses dan eksplorasi musik tradisional. Aplikasi ini bersifat open-source dan terus dikembangkan dengan dukungan komunitas. Semua data notasi diambil dari sumber yang sah dan dihormati hak ciptanya. Pembuatan aplikasi ini dilakukan dengan tujuan untuk melestarikan dan memperluas akses terhadap warisan budaya musik Jawa. Dengan alat yang seadanya, saya sebagai Developer apk sangat berterimakasih atas penggunaan aplikasi yang sederhana ini. Komentar serta masukan anda sangat bermanfaat bagi kami untuk terus mengembangkan aplikasi ini. Saya akan terus menambah notasi baru. Anda juga bisa Request lirik gending atau notasi di blog Sinsangnot (Cari di Google dengan query 'Sinsangnot'). Terima kasih telah menggunakan Sinsangnot!"),
        ),

        ListTile(
          leading: const Icon(Icons.policy_outlined, color: Colors.orange),
          title: Text("Kebijakan Privasi", style: TextStyle(color: primaryTextColor)),
          subtitle: Text("Privacy Policy penggunaan aplikasi", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
          onTap: () async {
            final Uri url = Uri.parse("https://sinsangnot.blogspot.com/p/privacy-policy.html");
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
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
        ListTile(
          leading: const Icon(Icons.public, color: Colors.blue), // Ikon bola dunia warna biru
          title: const Text("Kunjungi Blog Resmi"),
          subtitle: const Text("Baca notasi terbaru & request gending di sinsangnot.blogspot.com"),
          onTap: () async {
            final Uri url = Uri.parse("https://sinsangnot.blogspot.com");
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_center_outlined, color: Colors.green),
          title: const Text("Petunjuk Penggunaan & Update"),
          subtitle: const Text("panduan aplikasi, Cara simpan offline & unduh aplikasi versi terbaru."),
          onTap: () async {
            final Uri url = Uri.parse("https://sinsangnot.blogspot.com/p/download-aplikasi-notasi-gamelan.html");
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
        ),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              Text(
                "SinsangNot Versi 1.0.0",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Digital Gamelan Library",
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color:isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
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
        BottomNavigationBarItem(icon: Icon(Icons.compare_arrows), label: 'Komparasi'),
        BottomNavigationBarItem(icon: Icon(Icons.download_done), label: 'Koleksi'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
      ],
    );
  }
}

// --- WIDGET KHUSUS MODE TAYUB DENGAN VALIDASI ---
class _TayubModeView extends StatefulWidget {
  final Function(Map<String, String>, Map<String, String>)? onTayubSubmit;
  final Function(Map<String, String>)? onSitemapSelected;
  final bool isDarkMode;
  final List<Map<String, String>> sitemap;

  const _TayubModeView({
    this.onTayubSubmit, required 
    this.isDarkMode, required 
    this.sitemap,
    this.onSitemapSelected,});

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
      final lowercaseQuery = query.toLowerCase().trim();
      
      var allSitemap = widget.sitemap.where((s) {
        final title = s['title']?.toLowerCase() ?? "";
        return title.contains(lowercaseQuery);
      }).toList();
      
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
    if (widget.onSitemapSelected != null) {
    widget.onSitemapSelected!(item);
  }
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
                const Text("Buka 2 Notasi", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Text("Anda harus memilih 2 notasi yang muncul di saran pencarian.", style: TextStyle(color: Colors.grey)),
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