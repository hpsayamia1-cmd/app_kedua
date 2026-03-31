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
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

void main() async {
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
    _initUnityAds();
  }

Future<void> _initUnityAds() async {
  await UnityAds.init(
    gameId: '6070447',
    testMode: true,
    onComplete: () {
      debugPrint('semua siap!..'); 
    },
    onFailed: (error, message) => debugPrint('gagal load!...: $message'),
  );
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
  final String id, title, content, url, label, imageUrl, localImagePath;
  final String? lirik;
  Article({
    required this.id, 
    required this.title, 
    required this.content, 
    required this.url, 
    required this.label,
    this.imageUrl = "",
    this.localImagePath = "",
    this.lirik,
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
  int? _previousTab;
  Article? selectedArticle;
  List<Article>? dualArticles;
  
  bool isSplashing = true;
  double _splashOpacity = 0.0;
  
  List<Article> feedArticles = [], searchResults = [], offlineArticles = [];
  List<Map<String, dynamic>> _userNotes = [];
  List<Map<String, dynamic>> _filteredNotes = []; // Untuk menampung hasil pencarian catatan
  final TextEditingController _noteSearchController = TextEditingController(); // Controller khusus kolom cari catatan
  List<Map<String, String>> sitemapSuggestions = [], filteredSuggestions = [];
  bool isInitialLoading = true, isSearching = false, isOffline = false, isMoreLoading = false;
  
  int _currentStartIndex = 1;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  Timer? _networkTimer; // Tambahkan variabel untuk Timer jaringan
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final BloggerService _bloggerService = BloggerService();
  final List<String> gendingLabels = ["Tayub", "Ladrang", "Slendro", "Pelog", "Ketawang", "Ayak"];

  @override
  void initState() {
    super.initState();
    _initApp();
    _scrollController.addListener(_scrollListener);

    // --- FITUR AUTO-ONLINE ---
    // Cek status internet setiap 5 detik
    _networkTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Jika saat ini terdeteksi offline DAN daftar artikel masih kosong DAN sedang di Tab Beranda
      if (isOffline && feedArticles.isEmpty && _currentTab == 0 && !isSearching) {
        bool online = await _hasInternet();
        if (online) {
          debugPrint("Sinyal Sinsangnot kembali! Mengambil data...");
          _fetchInitialFeed();
          _fetchSitemap();
          
          // Opsional: Kasih tahu user kalau sudah online
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Anda kembali online! Memperbarui daftar gending..."),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    });
  }

  // Fungsi pengecek internet asli
  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

@override
void dispose() {
  _networkTimer?.cancel(); // Menghentikan timer otomatis saat keluar
  _scrollController.dispose();
  _debounce?.cancel();
  _searchController.dispose(); // Tambahkan ini juga biar bersih
  _searchFocusNode.dispose();  // Tambahkan ini juga
  super.dispose();
}

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!isMoreLoading && _searchController.text.isEmpty && _currentTab == 0 && !isOffline) {
        _fetchMoreFeed();
      }
    }
  }

Future<void> _initApp() async {
  // Efek Splash Screen
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted) setState(() => _splashOpacity = 1.0);
  });
  
  await Future.delayed(const Duration(seconds: 3));
  if (mounted) setState(() => isSplashing = false);

  // Muat data lokal dulu (cepat)
  await _loadOfflineData();
  await _loadSavedSitemap(); // Muat sitemap cadangan dari memori HP

  // Baru coba ambil data online
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

// 1. UNTUK DAFTAR BERANDA (Sangat Ringan & Cepat)
  String _getLowResThumbnail(String url) {
    if (url.isEmpty) return "";
    // Mengubah resolusi apa pun menjadi s320 (lebar 320px saja)
    return url.replaceAll(RegExp(r'\/s[0-9]+(-c)?\/'), '/s320/');
  }

  // 2. UNTUK SAAT ARTIKEL DIBUKA (Jernih & Tajam)
  String _getHighResThumbnail(String url) {
    if (url.isEmpty) return "";
    // Mengubah resolusi menjadi s1600 (resolusi asli/tinggi)
    return url.replaceAll(RegExp(r'\/s[0-9]+(-c)?\/'), '/s1600/');
  }

Future<void> _fetchInitialFeed() async {
    setState(() { isInitialLoading = true; isOffline = false; _currentStartIndex = 1; });
    try {
      final data = await _bloggerService.fetchFeed(startIndex: 1, maxResults: 15);
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
              imageUrl: _getLowResThumbnail(rawImg) 
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
    _currentStartIndex = feedArticles.length + 1;
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
              imageUrl: _getLowResThumbnail(rawImg)
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
            imageUrl: _getLowResThumbnail(rawImg)
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
      selectedArticle = Article(
        id: a.id,
        title: a.title,
        content: a.content,
        url: a.url,
        label: a.label,
        // PAKAI HIGH RES DI SINI:
        imageUrl: _getHighResThumbnail(a.imageUrl), 
        localImagePath: a.localImagePath,
      );
      dualArticles = null;
      _currentTab = 0;
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

bool _isDownloaded(String id) {
    // Mengecek apakah ID gending ini sudah ada di daftar offlineArticles
    return offlineArticles.any((a) => a.id == id);
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

// --- FITUR LOGIKA CATATAN (VERSI LENGKAP) ---
Future<void> _loadNotes() async {
    final db = await DatabaseHelper.getDatabase();
    final data = await db.query('notes', orderBy: 'id DESC');
    setState(() { 
      _userNotes = data; 
      _filteredNotes = data; // Saat pertama muat, tampilkan semua
    });
  }

  // ANTI-DUPLIKAT & VALIDASI JUDUL
  Future<void> _saveNote(String title, String content, {int? id}) async {
    String finalTitle = title.trim().isEmpty ? "Catatan Tanpa Judul" : title;
    if (content.trim().isEmpty) return; // Isi catatan wajib ada

    final db = await DatabaseHelper.getDatabase();
    final data = {
      'title': finalTitle,
      'content': content,
      'date': DateTime.now().toString(),
    };

    if (id == null) {
      await db.insert('notes', data);
    } else {
      // Update data yang sudah ada berdasarkan ID agar tidak dobel
      await db.update('notes', data, where: 'id = ?', whereArgs: [id]);
    }
    _loadNotes(); // Refresh daftar
  }

  // FUNGSI FILTER PENCARIAN CATATAN
  void _filterNotes(String query) {
    setState(() {
      _filteredNotes = _userNotes
          .where((n) => n['title'].toLowerCase().contains(query.toLowerCase()) || 
                        n['content'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

void _deleteNote(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        title: const Text("Hapus Catatan?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Apakah Anda yakin ingin menghapus catatan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final db = await DatabaseHelper.getDatabase();
              await db.delete('notes', where: 'id = ?', whereArgs: [id]);
              if (mounted) Navigator.pop(c);
              _loadNotes();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Catatan berhasil dihapus"),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text("Ya, Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
  if (FocusScope.of(context).hasFocus) {
    FocusScope.of(context).unfocus();
    return false;
  }
  if (selectedArticle != null || dualArticles != null) {
    setState(() {
      selectedArticle = null;
      dualArticles = null;
    });
    return false;
  }
  if (_currentTab == 1 && _noteSearchController.text.isNotEmpty) {
    setState(() {
      _noteSearchController.clear();
      _filterNotes("");
    });
    return false;
  }
  if (_currentTab == 0 && (_searchController.text.isNotEmpty || searchResults.isNotEmpty)) {
    _resetSearch();
    return false;
  }
  if (_currentTab != 0) {
    setState(() { _currentTab = 0; });
    return false;
  }
  bool? exitApp = await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      title: const Text("Keluar Aplikasi?"),
      content: const Text("Apakah Anda ingin menutup Sinsangnot?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal")),
        TextButton(
          onPressed: () => Navigator.pop(c, true), 
          child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        ),
      ],
    ),
  );
  return exitApp ?? false;
},
      child: Scaffold(
        appBar: header,
body: Stack(
        children: [
          if (selectedArticle == null && dualArticles == null)
            RefreshIndicator(
              color: Colors.red, 
              onRefresh: _fetchInitialFeed, 
              child: _buildTabContent(),
            ),

if (selectedArticle != null)
            ArticleReader(
              article: selectedArticle!, 
              isDarkMode: widget.isDarkMode, 
              // PASTIKAN DUA BARIS INI ADA:
              isSaved: _isDownloaded(selectedArticle!.id), 
              onDownload: () async {
                await _loadOfflineData();
              },
              onClose: () => setState(() => selectedArticle = null),
            ),

if (dualArticles != null)
  ArticleReader(
    articles: dualArticles!, 
    isDarkMode: widget.isDarkMode, 
    isDualMode: true,
    isSaved: false, // Tambahan formal
    onDownload: () {}, // Tambahan formal
    onClose: () => setState(() => dualArticles = null),
  ),

          if (_currentTab != 0)
            Container(
              color: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
              child: _buildTabContent(),
            ),
            
          header.buildFloatingSuggestions(context),
        ],
      ),
bottomNavigationBar: FooterWidget(
  currentTab: _currentTab,
  isDarkMode: widget.isDarkMode,
  sitemap: sitemapSuggestions.isNotEmpty 
      ? sitemapSuggestions 
      : offlineArticles.map((a) => {'title': a.title, 'url': a.url}).toList(),

onTabTap: (i) { 
  if (i == 0) {
    if (_currentTab == 0) {
      if (selectedArticle != null || dualArticles != null) {
        setState(() { 
          selectedArticle = null; 
          dualArticles = null; 
        });
      } else {
        _resetSearch();
      }
    } else {
      setState(() { _currentTab = 0; });
    }
  } else {
    _resetSearch(); 
    setState(() { 
      _previousTab = _currentTab;
      _currentTab = i; 
    }); 
    if (i == 1) _loadNotes(); 
    if (i == 3) _loadOfflineData(); 
  }
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
    // 1. Ganti skeleton yang sudah dihapus dengan Loading Spinner
    if (isInitialLoading || isSearching) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    
    // 2. Cek jika offline dan tidak ada data
    if (_currentTab == 0 && isOffline && feedArticles.isEmpty) return _buildOfflineError();
    
    // 3. FooterWidget di sini hanya untuk mengambil tampilan (bukan navigasi utama)
    final menuContent = FooterWidget(
      currentTab: _currentTab,
      isDarkMode: widget.isDarkMode,
      onTabTap: (i) {}, 
      onThemeChanged: widget.updateTheme,
      showInternalPage: _showInternalPage,
      gendingLabels: gendingLabels,
      onLabelTap: _handleSearch,
      sitemap: sitemapSuggestions.isNotEmpty 
          ? sitemapSuggestions 
          : offlineArticles.map((a) => {'title': a.title, 'url': a.url}).toList(),
      onTayubSubmit: (s1, s2) => _handleDualSearch(s1, s2),
    );

    switch (_currentTab) {
      case 0: 
        // Beranda & Hasil Cari
        List<Article> displayList = searchResults.isNotEmpty ? searchResults : feedArticles;
        return _buildArticleList(displayList);
        
      case 1: return menuContent.buildCatatan(
      child: _buildNotesUI(),);
      case 2: return menuContent.buildTayubMode(); // Ambil dari footer_widget.dart
      case 3: 
        // Koleksi Offline
        List<Article> offlineList = searchResults.isNotEmpty ? searchResults : offlineArticles;
        return _buildArticleList(offlineList, isOfflineTab: true);
      case 4: return menuContent.buildSetelan(); // Ambil dari footer_widget.dart
      default: return _buildArticleList(feedArticles);
    }
}
  
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
    return const Center(
      child: CircularProgressIndicator(color: Colors.red),
    );
  }
  if (list.isEmpty) return Center(child: Text(isOfflineTab ? "Silahkan download notasi untuk ditambahkan ke koleksi. Anda tetap bisa mengakses koleksi offline kapan saja." : "Hasil tidak ditemukan."));

  return Column(
    children: [
      // HEADER JUDUL UTAMA (TETAP DI TENGAH)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          children: [
            Text(
              isOfflineTab 
                  ? "KOLEKSI SAYA" 
                  : (_searchController.text.isNotEmpty ? "HASIL PENCARIAN" : "DAFTAR ISI"),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: widget.isDarkMode ? Colors.red[300] : Colors.red[900],
              ),
            ),
            Container(height: 2, width: 35, color: Colors.red, margin: const EdgeInsets.only(top: 5)),
          ],
        ),
      ),
      
      // DAFTAR GENDING 1 KOLOM (FLEKSIBEL)
      Expanded(
        child: ListView.builder(
          key: PageStorageKey(isOfflineTab ? 'offline_list' : 'beranda_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          controller: isOfflineTab ? null : _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: list.length + 1,
          itemBuilder: (context, index) {
          if (index == list.length) {
          if (isMoreLoading) {
          return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }
    return const SizedBox(height: 50); 
  }
  final a = list[index];

            return GestureDetector(
              onTap: () => _openArticle(a),
              onLongPress: isOfflineTab ? () => _confirmDelete(a) : null,
              child: Container(
                // KOTAK TANPA RADIUS DENGAN GARIS BAWAH
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: widget.isDarkMode ? Colors.white10 : Colors.grey[200]!, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Agar nomor tetap di atas jika teks panjang
                  children: [
                    // NOMOR URUT
                    Text("${index + 1}.", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 12),
                    
                    // JUDUL GENDING (WRAP OTOMATIS)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title.toUpperCase(), 
                            style: TextStyle(
                              fontSize: 14, // Ukuran huruf judul lebih jelas
                              fontWeight: FontWeight.bold,
                              height: 1.3, // Jarak antar baris biar enak dibaca
                              color: widget.isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(a.label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),

                    // IKON HAPUS (LEBIH BESAR UNTUK KOLEKSI)
                    if (isOfflineTab)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 24, color: Colors.redAccent), // Ukuran 24 & warna lebih tegas
                          onPressed: () => _confirmDelete(a),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
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
Widget _buildNotesUI() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _openNoteEditor(),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text("CATATAN SAYA", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),
          
          // --- KOLOM PENCARIAN KHUSUS CATATAN (DI BAWAH JUDUL) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: TextField(
  controller: _noteSearchController,
  onChanged: _filterNotes,
  textInputAction: TextInputAction.search,
  onSubmitted: (_) => FocusScope.of(context).unfocus(),
  decoration: InputDecoration(
    hintText: "Cari di catatan gending...",
    prefixIcon: const Icon(Icons.search, size: 20),
    suffixIcon: _noteSearchController.text.isNotEmpty 
      ? IconButton(
          icon: const Icon(Icons.clear, size: 20),
          onPressed: () {
            setState(() {
              _noteSearchController.clear();
              _filterNotes("");
              FocusScope.of(context).unfocus();
            });
          },
        )
      : null,
    filled: true,
    fillColor: widget.isDarkMode ? Colors.white10 : Colors.grey[100],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(vertical: 0),
  ),
),
          ),

          Expanded(
            child: _filteredNotes.isEmpty 
            ? const Center(child: Text("Tidak ada catatan ditemukan."))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: _filteredNotes.length,
                itemBuilder: (context, i) {
                  final n = _filteredNotes[i];
                  return Card(
                    color: widget.isDarkMode ? Colors.white10 : Colors.grey[100],
                    child: ListTile(
                      onTap: () => _viewNoteDetail(n), // Klik untuk baca (seperti permintaan Mas)
                      title: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(n['content'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                        onPressed: () => _deleteNote(n['id']),
                      ),
                    ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }

void _viewNoteDetail(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text("Detail Catatan"), backgroundColor: Colors.transparent),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column( // Tambahkan Column agar judul bisa tampil
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              const Divider(height: 30),
              Text(note['content'], style: const TextStyle(fontSize: 16, height: 1.6)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.edit),
          onPressed: () { Navigator.pop(context); _openNoteEditor(existingNote: note); },
        ),
      ),
    );
  }

 void _openNoteEditor({Map<String, dynamic>? existingNote}) {
    TextEditingController tC = TextEditingController(text: existingNote?['title'] ?? "");
    TextEditingController cC = TextEditingController(text: existingNote?['content'] ?? "");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // Melindungi dari area poni/notch HP
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 20, 
          right: 20, 
          top: 10 // Jarak sedikit dari lengkungan modal
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Mengikuti isi tapi bisa memanjang
          children: [
            // Handle garis kecil agar tampilan lebih manis
            Container(
              width: 40, height: 4, 
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            TextField(controller: tC, decoration: const InputDecoration(hintText: "Judul Catatan")),
            const SizedBox(height: 10),
            // MaxLines kita buat lebih besar agar area mengetik langsung luas ke atas
            TextField(
              controller: cC, 
              maxLines: 15, // Langsung membuat kotak tulisan tinggi ke atas
              decoration: const InputDecoration(hintText: "Isi catatan...")
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  _saveNote(tC.text, cC.text, id: existingNote?['id']);
                  Navigator.pop(context);
                },
                child: const Text("Simpan", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}