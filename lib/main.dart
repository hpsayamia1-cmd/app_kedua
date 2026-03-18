import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;
import 'article_view.dart';
import 'database_helper.dart';
import 'blogger_service.dart';
import 'header_widget.dart';
import 'footer_widget.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PuskarajaApp());
}

class PuskarajaApp extends StatefulWidget {
  @override
  State<PuskarajaApp> createState() => _PuskarajaAppState();
}

class _PuskarajaAppState extends State<PuskarajaApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default Langsung Gelap

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bool isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _updateTheme(bool isDark) async {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
      final prefs = await SharedPreferences.getInstance();
        prefs.setBool('isDarkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light, 
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.red
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: const Color(0xFF0F0F0F)
      ),
      home: RootNavigation(updateTheme: _updateTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

// Model Artikel yang mendukung WebP
class Article {
  final String id, title, content, url, label, imageUrl, localImagePath; // Tambah localImagePath
  Article({
    required this.id, 
    required this.title, 
    required this.content, 
    required this.url, 
    required this.label,
    this.imageUrl = "",
    this.localImagePath = "",
  });
}

class RootNavigation extends StatefulWidget {
  final Function(bool) updateTheme;
  final bool isDarkMode;
  RootNavigation({required this.updateTheme, required this.isDarkMode});
  @override
  _RootNavigationState createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentTab = 0;
  Article? selectedArticle;
  List<Article>? dualArticles; // Untuk Mode Tayub (2 Artikel)
  
  bool isSplashing = true;
  double _splashOpacity = 0.0;
  
  List<Article> feedArticles = [], searchResults = [], offlineArticles = [];
  List<Map<String, String>> sitemapSuggestions = [], filteredSuggestions = [];
  bool isInitialLoading = true, isSearching = false, isOffline = false, isMoreLoading = false;
  
  int _currentStartIndex = 1;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final BloggerService _bloggerService = BloggerService();
  final List<String> gendingLabels = ["Tayub", "Ladrang", "Slendro", "Pelog", "Ketawang", "Ayak"];

  @override
  void initState() {
    super.initState();
    _initApp();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isMoreLoading && _searchController.text.isEmpty && _currentTab == 0 && !isOffline) {
        _fetchMoreFeed();
      }
    }
  }

  Future<void> _initApp() async {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _splashOpacity = 1.0);
    });
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => isSplashing = false);
    await _loadOfflineData();
    _fetchInitialFeed();
    _fetchSitemap();
  }

 // LOGIKA PINTAR: Mencari URL gambar dengan metode yang lebih ringan (Efisiensi RAM)
  String _extractImageUrl(String content) {
    if (content.isEmpty) return "";
    final RegExp regExp = RegExp(
      "src=['\"]([^'\"]+\\.(?:jpg|jpeg|png|webp|gif|bmp))['\"]", 
      caseSensitive: false
    );
    
    final match = regExp.firstMatch(content);
    
    if (match != null) {
      String url = match.group(1) ?? "";
      return url.contains('?') ? url.split('?').first : url;
    } 
    return "";
  }

Future<void> _fetchSitemap() async {
    try {
      final res = await _bloggerService.fetchSitemap();
      if (res.statusCode == 200) {
        final document = xml.XmlDocument.parse(res.body);
        final locs = document.findAllElements('loc');
        List<Map<String, String>> temp = [];
        for (var element in locs) {
          String url = element.innerText;
          if (url.contains(".html")) {
            String slug = url.split('/').last.replaceAll(".html", "");
            temp.add({
              'title': slug.split('_').first.replaceAll('-', ' ').toUpperCase(), 
              'url': url
            });
          }
        }
        setState(() => sitemapSuggestions = temp);
        
        // SIMPAN KE HP: Agar saat offline nanti data ini bisa dibandingkan
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('saved_sitemap', temp.map((e) => "${e['title']}|${e['url']}").join("||"));
      }
    } catch (e) { 
      debugPrint("Sitemap error: $e"); 
      _loadSavedSitemap(); // Jika gagal ambil online, muat yang tersimpan
    }
  }

  // Fungsi tambahan untuk muat sitemap yang tersimpan di HP
  Future<void> _loadSavedSitemap() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString('saved_sitemap');
    if (saved != null) {
      setState(() {
        sitemapSuggestions = saved.split("||").map((e) {
          var part = e.split("|");
          return {'title': part[0], 'url': part[1]};
        }).toList();
      });
    }
  }

String _getHighResThumbnail(String url) {
    if (url.isEmpty) return "";
    // Mengubah kode ukuran Blogger (s72, s320, s640) menjadi s1600 (Resolusi Tinggi)
    return url.replaceAll(RegExp(r'\/s[0-9]+(-c)?\/'), '/s1600/');
  }

Future<void> _fetchInitialFeed() async {
    setState(() { isInitialLoading = true; isOffline = false; _currentStartIndex = 1; });
    try {
      final data = await _bloggerService.fetchFeed(startIndex: 1, maxResults: 8);
      if (data.isNotEmpty) {
        setState(() {
          // OPTIMASI: Proses data secara massal agar loading lebih cepat
          feedArticles = data.map((i) {
            String rawImg = _extractImageUrl(i['content']);
            return Article(
              id: i['url'], 
              title: i['title'], 
              content: i['content'], 
              url: i['url'], 
              label: i['label'], 
              // PAKAI FUNGSI ANTI-BLUR DI SINI
              imageUrl: _getHighResThumbnail(rawImg) 
            );
          }).toList();
          isOffline = false;
        });
      } else {
        setState(() => isOffline = true);
      }
    } catch (e) { setState(() => isOffline = true); }
    setState(() => isInitialLoading = false);
  }

  Future<void> _fetchMoreFeed() async {
    if (isMoreLoading) return;
    setState(() => isMoreLoading = true);
    _currentStartIndex += 8;
    try {
      final data = await _bloggerService.fetchFeed(startIndex: _currentStartIndex, maxResults: 8);
      if (data.isNotEmpty) {
        setState(() {
          // OPTIMASI: Gunakan addAll dengan map untuk efisiensi
          feedArticles.addAll(data.map((i) {
            String rawImg = _extractImageUrl(i['content']);
            return Article(
              id: i['url'], 
              title: i['title'], 
              content: i['content'], 
              url: i['url'], 
              label: i['label'], 
              imageUrl: _getHighResThumbnail(rawImg)
            );
          }).toList());
        });
      }
    } catch (e) { debugPrint("Load more error"); }
    setState(() => isMoreLoading = false);
  }

Future<void> _handleSearch(String q) async {
    if (q.isEmpty) return;
    _searchFocusNode.unfocus(); 
    setState(() { isSearching = true; filteredSuggestions = []; selectedArticle = null; dualArticles = null; });
    
    try {
      final data = await _bloggerService.searchPosts(q);
      setState(() {
        searchResults = data.map((i) {
          String rawImg = _extractImageUrl(i['content']);
          return Article(
            id: i['url'], 
            title: i['title'], 
            content: i['content'], 
            url: i['url'], 
            label: i['label'], 
            imageUrl: _getHighResThumbnail(rawImg) // TETAP JERNIH SAAT CARI
          );
        }).toList();
        _currentTab = 0;
        isOffline = false;
      });
    } catch (e) { 
      _searchOfflineLocally(q);
    }
    setState(() => isSearching = false);
  }

void _searchOfflineLocally(String q) {
    List<Article> local = offlineArticles.where((a) => a.title.toLowerCase().contains(q.toLowerCase())).toList();
    setState(() { searchResults = local; });
  }

  void _openArticle(Article a) {
    setState(() {
      selectedArticle = a;
      dualArticles = null;
    });
  }

  // Fungsi khusus untuk Mode Tayub (Membuka 2 Artikel Sekaligus)
  void _openDualArticle(Article a1, Article a2) {
    setState(() {
      dualArticles = [a1, a2];
      selectedArticle = null;
    });
  }

  // INI FUNGSI BARU UNTUK TOMBOL "BUKA 2 NOTASI"
Future<void> _handleDualSearch(Map<String, String> s1, Map<String, String> s2) async {
    setState(() { isSearching = true; });
    
    try {
      // 1. FUNGSI CEK LOKAL: Kita cari di koleksi offline dulu
      Article? a1 = _findInOffline(s1['title']!);
      Article? a2 = _findInOffline(s2['title']!);

      // 2. Jika salah satu atau keduanya TIDAK ADA di offline, baru cari ke internet
      if (a1 == null || a2 == null) {
        final results = await Future.wait([
          a1 == null ? _bloggerService.searchPosts(s1['title']!) : Future.value([]),
          a2 == null ? _bloggerService.searchPosts(s2['title']!) : Future.value([]),
        ]);

        if (a1 == null && results[0].isNotEmpty) {
          var i = results[0][0];
          a1 = Article(id: i['url'], title: i['title'], content: i['content'], url: i['url'], label: i['label'], imageUrl: _extractImageUrl(i['content']));
        }
        if (a2 == null && results[1].isNotEmpty) {
          var i = results[1][0];
          a2 = Article(id: i['url'], title: i['title'], content: i['content'], url: i['url'], label: i['label'], imageUrl: _extractImageUrl(i['content']));
        }
      }

      // 3. Tampilkan hasilnya jika keduanya berhasil ditemukan (baik lokal maupun online)
      if (a1 != null && a2 != null) {
        setState(() {
          dualArticles = [a1!, a2!];
          selectedArticle = null;
          _currentTab = 0; // Pindah ke home untuk melihat notasi
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat dual gending: $e");
    }
    setState(() { isSearching = false; });
  }

  // Fungsi pembantu untuk mencari artikel di daftar offlineArticles
  Article? _findInOffline(String title) {
    try {
      return offlineArticles.firstWhere(
        (a) => a.title.toLowerCase() == title.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }

Future<void> _loadOfflineData() async {
    final db = await DatabaseHelper.getDatabase();
    final maps = await db.query('offline_posts');
    setState(() { 
      offlineArticles = maps.map((e) => Article(
        id: e['id'].toString(), 
        title: e['title'].toString(), 
        content: e['content'].toString(), 
        url: e['url'].toString(), 
        label: e['label']?.toString() ?? "Gending",
        imageUrl: e['imageUrl']?.toString() ?? "", // Pastikan imageUrl terbaca
        localImagePath: e['localImagePath']?.toString() ?? "", // Tambahkan ini
      )).toList(); 
    });
  }

  void _resetSearch() { 
    _searchController.clear(); 
    _searchFocusNode.unfocus(); 
    setState(() { searchResults = []; filteredSuggestions = []; isSearching = false; }); 
  }

  void _showInternalPage(String title, String content) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (context) => Container(
        padding: const EdgeInsets.all(24), 
        height: MediaQuery.of(context).size.height * 0.6, 
        child: Column(children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)), 
          const SizedBox(height: 15), 
          Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)))), 
          const SizedBox(height: 20), 
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Tutup", style: TextStyle(color: Colors.white))))
        ])
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSplashing) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white, 
        body: Center(
          child: AnimatedOpacity(
            opacity: _splashOpacity, duration: const Duration(seconds: 1),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset('assets/logo.png', height: 120, errorBuilder: (c,e,s) => const Icon(Icons.play_circle_fill, size: 100, color: Colors.red)), 
              const SizedBox(height: 20), 
              const Text("SinsangNot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 3))
            ]),
          )
        )
      );
    }

final header = HeaderWidget(
      isDarkMode: widget.isDarkMode,
      isLoading: isInitialLoading || isSearching,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      filteredSuggestions: filteredSuggestions,
      onSearchSubmitted: _handleSearch,
      onSearchChanged: (val) {
        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          if (val.isEmpty) { 
            setState(() => filteredSuggestions = []); 
          } else {
            // LOGIKA PINTAR UNTUK HEADER:
            // Jika sitemapSuggestions kosong (Offline), cari saran dari offlineArticles
            var source = sitemapSuggestions.isNotEmpty 
                ? sitemapSuggestions 
                : offlineArticles.map((a) => {'title': a.title, 'url': a.url}).toList();

            setState(() { 
              filteredSuggestions = source
                  .where((s) => s['title']!.toLowerCase().contains(val.toLowerCase()))
                  .take(6) // Ambil 6 saran saja agar tidak penuh layarnya
                  .toList(); 
            });
          }
        });
      },
      onSitemapTap: (suggestion) {
        setState(() => filteredSuggestions = []);
        // Jika offline, panggil _openArticle langsung dari data lokal
        Article? localMatch = _findInOffline(suggestion['title']!);
        if (localMatch != null) {
          _openArticle(localMatch);
        } else {
          // Jika online, buat artikel sementara lalu ambil datanya
          _openArticle(Article(id: suggestion['url']!, title: suggestion['title']!, content: "", url: suggestion['url']!, label: "Gending"));
          _handleSearch(suggestion['title']!); // Picu pencarian konten lengkap
        }
      },
      onResetSearch: _resetSearch,
      onLogoTap: () { _resetSearch(); setState(() { _currentTab = 0; selectedArticle = null; dualArticles = null; }); },
    );

return WillPopScope(
  onWillPop: () async { 
    // 1. Jika sedang buka artikel, tutup artikelnya (Balik ke Tab yang aktif sebelumnya)
    if (selectedArticle != null || dualArticles != null) { 
      setState(() { selectedArticle = null; dualArticles = null; }); 
      return false; 
    } 
    // 2. Jika sedang di tab selain Beranda (0), balikkan ke Beranda dulu
    if (_currentTab != 0) { 
      setState(() { _currentTab = 0; _resetSearch(); }); 
      return false; 
    } 
    return true; // Keluar aplikasi
  },
      child: Scaffold(
        appBar: header,
        body: Stack(children: [
          selectedArticle != null 
            ? ArticleReader(
                article: selectedArticle!, 
                isDarkMode: widget.isDarkMode, 
                onClose: () => setState(() => selectedArticle = null)
              )
            : dualArticles != null
                ? ArticleReader(
                    articles: dualArticles!, 
                    isDarkMode: widget.isDarkMode, 
                    isDualMode: true,
                    onClose: () => setState(() => dualArticles = null)
                  )
                : RefreshIndicator(color: Colors.red, onRefresh: _fetchInitialFeed, child: _buildTabContent()),
          header.buildFloatingSuggestions(context),
        ]),
bottomNavigationBar: FooterWidget(
  currentTab: _currentTab,
  isDarkMode: widget.isDarkMode,
  sitemap: sitemapSuggestions.isNotEmpty 
      ? sitemapSuggestions 
      : offlineArticles.map((a) => {'title': a.title, 'url': a.url}).toList(),

onTabTap: (i) { 
  _resetSearch(); 
  setState(() { 
    _currentTab = i;
  }); 
  if (i == 3) _loadOfflineData(); 
},
  onThemeChanged: widget.updateTheme,
  showInternalPage: _showInternalPage,
  gendingLabels: gendingLabels,
  onLabelTap: _handleSearch,
  onTayubSubmit: (s1, s2) => _handleDualSearch(s1, s2), 
),
      ),
    );
  }

Widget _buildTabContent() {
    // 1. Jika memang sedang proses tarik data dari internet, tampilkan loading (skeleton)
    if (isInitialLoading || isSearching) return _buildSkeletonList();
    
    if (_currentTab == 0 && isOffline && feedArticles.isEmpty) return _buildOfflineError();
    
    final footerContent = FooterWidget(
      currentTab: _currentTab,
      isDarkMode: widget.isDarkMode,
      onTabTap: (i) {}, 
      onThemeChanged: widget.updateTheme,
      showInternalPage: _showInternalPage,
      gendingLabels: gendingLabels,
      onLabelTap: _handleSearch,
      sitemap: sitemapSuggestions,
      onTayubSubmit: (s1, s2) => _handleDualSearch(s1, s2),
    );

    switch (_currentTab) {
      case 0: 
        // LOGIKA PERBAIKAN:
        // Cek searchResults.isNotEmpty DULU. Jangan cuma cek teks controller-nya.
        // Jika hasil cari ada, tampilkan. Jika tidak ada hasil TAPI sedang ngetik, 
        // tetap tampilkan feedArticles (Beranda) sampai user tekan Enter/Sitemap.
        List<Article> displayList = searchResults.isNotEmpty ? searchResults : feedArticles;
        return _buildArticleList(displayList);
        
      case 1: return footerContent.buildJelajah();
      case 2: return footerContent.buildTayubMode();
      case 3: 
        List<Article> offlineList = searchResults.isNotEmpty ? searchResults : offlineArticles;
        return _buildArticleList(offlineList, isOfflineTab: true);
      case 4: return footerContent.buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
}

  Widget _buildSkeletonList() => ListView.builder(itemCount: 5, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.all(20), child: Container(height: 150, decoration: BoxDecoration(color: widget.isDarkMode ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(15)))));
  
  Widget _buildOfflineError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 100, color: Colors.grey), 
      const Text("Maaf, Anda Sedang Offline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
      const SizedBox(height: 24), 
      ElevatedButton(onPressed: () => setState(() => _currentTab = 3), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Buka Koleksi Offline", style: TextStyle(color: Colors.white)))
    ]));
  }
  
  Widget _buildArticleList(List<Article> list, {bool isOfflineTab = false}) {
    if (isInitialLoading || isSearching) {
      return _buildSkeletonList(); 
    }
    if (list.isEmpty) return Center(child: Text(isOfflineTab ? "Belum ada koleksi." : "Hasil tidak ditemukan."));
    return ListView.builder(
      controller: isOfflineTab ? null : _scrollController,
      itemCount: list.length + (isMoreLoading ? 1 : 0), 
      itemBuilder: (c, i) {
        if (i == list.length) return const Center(child: CircularProgressIndicator(color: Colors.red));
        final a = list[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: InkWell(
            onTap: () => _openArticle(a),
            child: Column(children: [
              _buildThumbnail(a),
              ListTile(
                title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Sinsangnot • ${a.label}"),
                trailing: isOfflineTab ? IconButton(icon: const Icon(Icons.delete), onPressed: () => _confirmDelete(a)) : const Icon(Icons.chevron_right),
              )
            ]),
          ),
        );
      }
    );
  }

Widget _buildThumbnail(Article a) {
    // Matriks Invert untuk Mode Gelap
    const ColorFilter invert = ColorFilter.matrix(<double>[
      -1.0,  0.0,  0.0, 0.0, 255.0,
       0.0, -1.0,  0.0, 0.0, 255.0,
       0.0,  0.0, -1.0, 0.0, 255.0,
       0.0,  0.0,  0.0, 1.0,   0.0,
    ]);

    Widget imageWidget;

    // LOGIKA PINTAR: Cek apakah ada file lokal hasil download
    if (a.localImagePath.isNotEmpty && File(a.localImagePath).existsSync()) {
      imageWidget = Image.file(
        File(a.localImagePath),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (a.imageUrl.isNotEmpty) {
      imageWidget = Image.network(
        a.imageUrl, 
        height: 180, 
        width: double.infinity, 
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    } else {
      return _buildPlaceholder();
    }

    return ColorFiltered(
      colorFilter: widget.isDarkMode ? invert : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
      child: imageWidget,
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(height: 180, width: double.infinity, color: Colors.grey[800], child: const Icon(Icons.music_note, size: 50, color: Colors.white24));
  }

void _confirmDelete(Article a) { 
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Hapus Koleksi?"), actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")), 
      TextButton(onPressed: () async { 
        // 1. Hapus file gambar fisiknya dari memori HP
        if (a.localImagePath.isNotEmpty) {
          final file = File(a.localImagePath);
          if (await file.exists()) {
            await file.delete();
          }
        }

        // 2. Hapus data dari Database
        final db = await DatabaseHelper.getDatabase(); 
        await db.delete('offline_posts', where: 'id = ?', whereArgs: [a.id]); 
        
        Navigator.pop(c); 
        _loadOfflineData(); // Refresh tampilan
      }, child: const Text("Hapus", style: TextStyle(color: Colors.red)))
    ])); 
  }
}