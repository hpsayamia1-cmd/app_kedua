import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

import 'article_view.dart';
import 'database_helper.dart';
import 'blogger_service.dart';
import 'header_widget.dart';
import 'footer_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PuskarajaApp());
}

class PuskarajaApp extends StatefulWidget {
  @override
  State<PuskarajaApp> createState() => _PuskarajaAppState();
}

class _PuskarajaAppState extends State<PuskarajaApp> {
  ThemeMode _themeMode = ThemeMode.dark;
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      prefs.setBool('isDarkMode', isDark);
    });
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: Colors.white),
      darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0F0F0F)),
      home: RootNavigation(updateTheme: _updateTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class Article {
  final String id, title, content, url, label;
  Article({required this.id, required this.title, required this.content, required this.url, required this.label});
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
  bool isSplashing = true;
  double _splashOpacity = 0.0;
  double _splashScale = 0.8;
  
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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() { _splashOpacity = 1.0; _splashScale = 1.0; });
    });
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => isSplashing = false);
    await _loadOfflineData();
    _fetchInitialFeed();
    _fetchSitemap();
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
      }
    } catch (e) { debugPrint("Sitemap error: $e"); }
  }

  Future<void> _fetchInitialFeed() async {
    setState(() { isInitialLoading = true; isOffline = false; _currentStartIndex = 1; });
    try {
      final data = await _bloggerService.fetchFeed(startIndex: 1, maxResults: 8);
      if (data.isNotEmpty) {
        setState(() {
          feedArticles = data.map((i) => Article(
            id: i['url'], title: i['title'], content: i['content'], url: i['url'], label: i['label']
          )).toList()..shuffle();
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
          feedArticles.addAll(data.map((i) => Article(
            id: i['url'], title: i['title'], content: i['content'], url: i['url'], label: i['label']
          )).toList());
        });
      }
    } catch (e) { debugPrint("Load more error"); }
    setState(() => isMoreLoading = false);
  }

  // PERBAIKAN: Fungsi Handle Search untuk Online/Offline
  Future<void> _handleSearch(String q) async {
    if (q.isEmpty) return;
    _searchFocusNode.unfocus(); 
    setState(() { isSearching = true; filteredSuggestions = []; selectedArticle = null; });
    
    // Jika sedang di Tab Koleksi, cari di lokal saja
    if (_currentTab == 2) {
      _searchOfflineLocally(q);
      setState(() => isSearching = false);
      return;
    }

    try {
      final data = await _bloggerService.searchPosts(q);
      if (data.isNotEmpty) {
        setState(() {
          searchResults = data.map((i) => Article(
            id: i['url'], title: i['title'], content: i['content'], url: i['url'], label: i['label']
          )).toList();
          _currentTab = 0;
          isOffline = false;
        });
      } else {
        _searchOfflineLocally(q); // Jika online zonk, coba cari di koleksi
      }
    } catch (e) { 
      _searchOfflineLocally(q); // Jika error (offline), cari di koleksi
    }
    setState(() => isSearching = false);
  }

  void _searchOfflineLocally(String q) {
    List<Article> local = offlineArticles.where((a) => a.title.toLowerCase().contains(q.toLowerCase())).toList();
    setState(() { 
      searchResults = local; 
      // Jangan paksa pindah tab 0 agar user tetap di konteks tab koleksi
    });
  }

  void _openArticle(Article a) {
    setState(() => selectedArticle = a);
  }

  Future<void> _loadOfflineData() async {
    final db = await DatabaseHelper.getDatabase();
    final maps = await db.query('offline_posts');
    setState(() { 
      offlineArticles = maps.map((e) => Article(
        id: e['id'].toString(), title: e['title'].toString(), content: e['content'].toString(), 
        url: e['url'].toString(), label: e['label']?.toString() ?? "Gending"
      )).toList(); 
    });
  }

  void _resetSearch() { 
    _searchController.clear(); 
    _searchFocusNode.unfocus(); 
    setState(() { 
      searchResults = []; 
      filteredSuggestions = []; 
      isSearching = false; 
    }); 
  }

  void _showInternalPage(String title, String content) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(padding: const EdgeInsets.all(24), height: MediaQuery.of(context).size.height * 0.5, child: Column(children: [Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 15), Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)))), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Tutup", style: TextStyle(color: Colors.white))))])));
  }

  @override
  Widget build(BuildContext context) {
    if (isSplashing) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white, 
        body: Center(
          child: AnimatedScale(
            scale: _splashScale, duration: const Duration(seconds: 2), curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _splashOpacity, duration: const Duration(seconds: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image.asset('assets/logo.png', height: 110, errorBuilder: (c,e,s) => const Icon(Icons.play_circle_fill, size: 100, color: Colors.red)), 
                const SizedBox(height: 20), 
                Text("SinsangNot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: 2, color: widget.isDarkMode ? Colors.white : Colors.black))
              ]),
            ),
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
        
        // Debounce 4 detik hanya di Tab Koleksi
        if (_currentTab == 2) {
          _debounce = Timer(const Duration(seconds: 4), () { 
            if (val.isNotEmpty) _searchOfflineLocally(val); 
            else setState(() => searchResults = []);
          });
        } else {
          // Pencarian sitemap cepat (500ms)
          _debounce = Timer(const Duration(milliseconds: 500), () {
            if (val.isEmpty) { 
              setState(() => filteredSuggestions = []); 
            } else { 
              setState(() => filteredSuggestions = sitemapSuggestions
                .where((s) => s['title']!.toLowerCase().contains(val.toLowerCase()))
                .take(6).toList()); 
            }
          });
        }
      },
      // PERBAIKAN: Klik Sitemap langsung buka artikel
      onSitemapTap: (suggestion) {
        setState(() => filteredSuggestions = []);
        _openArticle(Article(
          id: suggestion['url']!, title: suggestion['title']!, 
          content: "", url: suggestion['url']!, label: "Gending"
        ));
      },
      onResetSearch: _resetSearch,
      onLogoTap: () { _resetSearch(); setState(() { _currentTab = 0; selectedArticle = null; }); },
    );

    return WillPopScope(
      onWillPop: () async { 
        if (selectedArticle != null) { setState(() => selectedArticle = null); return false; } 
        if (filteredSuggestions.isNotEmpty) { setState(() => filteredSuggestions = []); return false; }
        if (_searchController.text.isNotEmpty) { _resetSearch(); return false; } 
        if (_currentTab != 0) { setState(() { _currentTab = 0; _resetSearch(); }); return false; } 
        return true; 
      },
      child: Scaffold(
        appBar: header,
        body: Stack(children: [
          RefreshIndicator(
            color: Colors.red, 
            onRefresh: _fetchInitialFeed, 
            child: selectedArticle != null 
              ? ArticleReader(
                  id: selectedArticle!.id, title: selectedArticle!.title, content: selectedArticle!.content, 
                  url: selectedArticle!.url, labels: [selectedArticle!.label], isDarkMode: widget.isDarkMode, 
                  onClose: () => setState(() => selectedArticle = null), onLoadStart: () => {}, onLoadEnd: () => {}
                ) 
              : _buildTabContent()
          ),
          // Memanggil build dari HeaderWidget agar nempel di AppBar
          header.buildFloatingSuggestions(context),
        ]),
        bottomNavigationBar: FooterWidget(
          currentTab: _currentTab,
          isDarkMode: widget.isDarkMode,
          onTabTap: (i) { 
            _resetSearch(); 
            setState(() { _currentTab = i; selectedArticle = null; }); 
            if (i == 2) _loadOfflineData(); 
          },
          onThemeChanged: widget.updateTheme,
          showInternalPage: _showInternalPage,
          gendingLabels: gendingLabels,
          onLabelTap: _handleSearch,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (isInitialLoading || isSearching) return _buildSkeletonList();
    
    // PERBAIKAN: Logika Offline Error hanya muncul di Beranda (Tab 0)
    if (_currentTab == 0 && isOffline && feedArticles.isEmpty && _searchController.text.isEmpty) {
      return _buildOfflineError();
    }
    
    switch (_currentTab) {
      case 0: 
        return _buildArticleList(_searchController.text.isNotEmpty ? searchResults : feedArticles);
      case 1: 
        return FooterWidget(currentTab: _currentTab, isDarkMode: widget.isDarkMode, onTabTap: (i){}, onThemeChanged: widget.updateTheme, showInternalPage: _showInternalPage, gendingLabels: gendingLabels, onLabelTap: _handleSearch).buildJelajah();
      case 2: 
        // Di tab koleksi, tampilkan hasil cari lokal jika ada teks, jika tidak tampilkan semua koleksi
        return _buildArticleList(_searchController.text.isNotEmpty ? searchResults : offlineArticles, isOfflineTab: true);
      case 3: 
        return FooterWidget(currentTab: _currentTab, isDarkMode: widget.isDarkMode, onTabTap: (i){}, onThemeChanged: widget.updateTheme, showInternalPage: _showInternalPage, gendingLabels: gendingLabels, onLabelTap: _handleSearch).buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
  }

  Widget _buildSkeletonList() => ListView.builder(itemCount: 5, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.all(20), child: Container(height: 150, decoration: BoxDecoration(color: widget.isDarkMode ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(15)))));
  
  Widget _buildOfflineError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 100, color: Colors.grey), 
      const SizedBox(height: 16),
      const Text("Maaf, Anda Sedang Offline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8), child: Text("Periksa koneksi internet Anda atau buka koleksi notasi yang sudah Anda simpan.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
      const SizedBox(height: 24), 
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), 
        onPressed: () { _resetSearch(); setState(() => _currentTab = 2); _loadOfflineData(); }, 
        icon: const Icon(Icons.library_music, color: Colors.white), label: const Text("Buka Koleksi Anda", style: TextStyle(color: Colors.white))
      ),
      TextButton(onPressed: _fetchInitialFeed, child: const Text("Coba Lagi", style: TextStyle(color: Colors.red)))
    ]));
  }
  
  Widget _buildArticleList(List<Article> list, {bool isOfflineTab = false}) {
    if (list.isEmpty) return Center(child: Text(isOfflineTab ? "Belum ada koleksi." : "Hasil tidak ditemukan."));
    return ListView.builder(
      controller: isOfflineTab ? null : _scrollController,
      itemCount: list.length + (isMoreLoading ? 1 : 0), 
      itemBuilder: (c, i) {
        if (i == list.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.red)));
        final a = list[i];
        return Column(children: [
          InkWell(onTap: () => _openArticle(a), child: _getThumbnailOptimized(a)), 
          ListTile(
            onTap: () => _openArticle(a), 
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.music_note, color: Colors.white, size: 20)), 
            title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), 
            subtitle: Text(isOfflineTab ? "Tersedia Offline" : "Sinsangnot • ${a.label}"), 
            trailing: isOfflineTab ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(a)) : const Icon(Icons.more_vert, size: 18)
          ), 
          const SizedBox(height: 12)
        ]);
      }
    );
  }

  Widget _getThumbnailOptimized(Article a) {
    String assetPath = 'assets/gong6.png';
    String l = a.label.toLowerCase();
    if (l.contains('gong-1')) assetPath = 'assets/gong1.png';
    else if (l.contains('gong-2')) assetPath = 'assets/gong2.png';
    else if (l.contains('gong-3')) assetPath = 'assets/gong3.png';
    else if (l.contains('gong-4')) assetPath = 'assets/gong4.png';
    else if (l.contains('gong-5')) assetPath = 'assets/gong5.png';
    else if (l.contains('gong-6')) assetPath = 'assets/gong6.png';
    else if (l.contains('ladrang')) assetPath = 'assets/ladrang.png';
    else if (l.contains('ketawang')) assetPath = 'assets/ketawang.png';
    else if (l.contains('tayub')) assetPath = 'assets/gong1.png';
    else if (l.contains('slendro')) assetPath = 'assets/gong2.png';
    else if (l.contains('pelog')) assetPath = 'assets/gong3.png';
    else if (l.contains('ayak')) assetPath = 'assets/ayak.png';

    return Container(
      width: double.infinity, height: 180, color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
      child: Image.asset(assetPath, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_video, size: 50, color: Colors.red)),
    );
  }

  void _confirmDelete(Article a) { showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Hapus Koleksi?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")), TextButton(onPressed: () async { final db = await DatabaseHelper.getDatabase(); await db.delete('offline_posts', where: 'id = ?', whereArgs: [a.id]); Navigator.pop(c); _loadOfflineData(); }, child: const Text("Hapus", style: TextStyle(color: Colors.red)))])); }
}