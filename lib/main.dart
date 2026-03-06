import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

// Import file mesin Anda
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

// Model Article yang lebih ringan
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
  List<Article> feedArticles = [], searchResults = [], offlineArticles = [];
  List<Map<String, String>> sitemapSuggestions = [], filteredSuggestions = [];
  bool isInitialLoading = true, isSearching = false, isOffline = false;
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final BloggerService _bloggerService = BloggerService();
  final List<String> gendingLabels = ["Tayub", "Ladrang", "Slendro", "Pelog", "Ketawang", "Ayak"];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
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
            temp.add({'title': slug.split('_').first.replaceAll('-', ' '), 'url': url});
          }
        }
        setState(() => sitemapSuggestions = temp);
      }
    } catch (e) { debugPrint("Sitemap error: $e"); }
  }

  // Pengambilan Feed Tanpa API (RSS/Atom) - Jauh lebih enteng
  Future<void> _fetchInitialFeed() async {
    setState(() { isInitialLoading = true; isOffline = false; });
    try {
      final data = await _bloggerService.fetchInitialFeed();
      setState(() {
        feedArticles = data.map((i) => Article(
          id: i['url'], // Gunakan URL sebagai ID unik
          title: i['title'],
          content: i['content'],
          url: i['url'],
          label: i['label']
        )).toList()..shuffle(); // Acak daftar artikel sesuai permintaan
      });
    } catch (e) { isOffline = true; }
    setState(() => isInitialLoading = false);
  }

  Future<void> _handleSearch(String q) async {
    if (q.isEmpty) return;
    _searchFocusNode.unfocus(); 
    setState(() { isSearching = true; filteredSuggestions = []; selectedArticle = null; _searchController.text = q; });
    try {
      final data = await _bloggerService.searchPosts(q);
      if (data.isNotEmpty) {
        setState(() {
          searchResults = data.map((i) => Article(
            id: i['url'], title: i['title'], content: i['content'], url: i['url'], label: i['label']
          )).toList();
          _currentTab = 0; isOffline = false;
        });
      } else { _searchOfflineLocally(q); }
    } catch (e) { _searchOfflineLocally(q); }
    setState(() => isSearching = false);
  }

  void _searchOfflineLocally(String q) async {
    await _loadOfflineData();
    List<Article> local = offlineArticles.where((a) => a.title.toLowerCase().contains(q.toLowerCase())).toList();
    setState(() { searchResults = local; _currentTab = 0; });
  }

  // Membuka artikel langsung (On-Demand)
  void _openArticle(Article a) {
    setState(() => selectedArticle = a);
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
        label: e['label']?.toString() ?? "Gending"
      )).toList(); 
    });
  }

  void _resetSearch() { _searchController.clear(); _searchFocusNode.unfocus(); setState(() { searchResults = []; filteredSuggestions = []; isSearching = false; }); }

  void _showInternalPage(String title, String content) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(padding: const EdgeInsets.all(24), height: MediaQuery.of(context).size.height * 0.5, child: Column(children: [Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 15), Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)))), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Tutup", style: TextStyle(color: Colors.white))))])));
  }

  @override
  Widget build(BuildContext context) {
    if (isSplashing) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white, 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              Image.asset('assets/logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.play_circle_fill, size: 100, color: Colors.red)), 
              const SizedBox(height: 20), 
              const Text("SinsangNot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24))
            ]
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
          if (val.isEmpty) { setState(() => filteredSuggestions = []); } 
          else { 
            setState(() => filteredSuggestions = sitemapSuggestions
              .where((s) => s['title']!.toLowerCase().contains(val.toLowerCase()))
              .take(5).toList()); 
          }
        });
      },
      onSitemapTap: (url) { /* Sitemap diarahkan ke pencarian atau viewer */ },
      onResetSearch: _resetSearch,
      onLogoTap: () { _resetSearch(); setState(() { _currentTab = 0; selectedArticle = null; }); },
    );

    return WillPopScope(
      onWillPop: () async { if (selectedArticle != null) { setState(() => selectedArticle = null); return false; } if (_searchController.text.isNotEmpty) { _resetSearch(); return false; } if (_currentTab != 0) { setState(() => _currentTab = 0); return false; } return true; },
      child: Scaffold(
        appBar: header,
        body: Stack(children: [
          RefreshIndicator(color: Colors.red, onRefresh: _fetchInitialFeed, child: selectedArticle != null ? ArticleReader(id: selectedArticle!.id, title: selectedArticle!.title, content: selectedArticle!.content, url: selectedArticle!.url, labels: [selectedArticle!.label], isDarkMode: widget.isDarkMode, onClose: () => setState(() => selectedArticle = null), onLoadStart: () => {}, onLoadEnd: () => {}) : _buildTabContent()),
          header.buildFloatingSuggestions(context),
        ]),
        bottomNavigationBar: FooterWidget(
          currentTab: _currentTab,
          isDarkMode: widget.isDarkMode,
          onTabTap: (i) { _resetSearch(); setState(() { _currentTab = i; selectedArticle = null; }); if (i == 2) _loadOfflineData(); },
          onThemeChanged: (v) => widget.updateTheme(v),
          showInternalPage: _showInternalPage,
          gendingLabels: gendingLabels,
          onLabelTap: _handleSearch,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (isInitialLoading || isSearching) return _buildSkeletonList();
    if (isOffline && _currentTab == 0 && feedArticles.isEmpty) return _buildOfflineError();
    
    final footerUI = FooterWidget(currentTab: _currentTab, isDarkMode: widget.isDarkMode, onTabTap: (i){}, onThemeChanged: widget.updateTheme, showInternalPage: _showInternalPage, gendingLabels: gendingLabels, onLabelTap: _handleSearch);

    switch (_currentTab) {
      case 0: return _buildArticleList(_searchController.text.isNotEmpty ? searchResults : feedArticles);
      case 1: return footerUI.buildJelajah();
      case 2: return _buildArticleList(offlineArticles, isOfflineTab: true);
      case 3: return footerUI.buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
  }

  Widget _buildSkeletonList() => ListView.builder(itemCount: 5, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.all(20), child: Container(height: 150, color: widget.isDarkMode ? Colors.white10 : Colors.grey[200])));
  Widget _buildOfflineError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.wifi_off, size: 80, color: Colors.grey), const Text("Maaf anda sedang offline."), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => setState(() => _currentTab = 2), child: const Text("Buka Koleksi", style: TextStyle(color: Colors.white)))]));
  
  Widget _buildArticleList(List<Article> list, {bool isOfflineTab = false}) {
    if (list.isEmpty) return Center(child: Text(isOfflineTab ? "Belum ada koleksi." : "Hasil tidak ditemukan."));
    return ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
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
    });
  }

  // LOGIKA THUMBNAIL AKURAT SESUAI LABEL ANDA (Gong-1 sampai Gong-6, Ladrang, Ketawang)
  Widget _getThumbnailOptimized(Article a) {
    String assetPath = 'assets/gong6.png'; // Default
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
      width: double.infinity, 
      height: 180, 
      color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain, 
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_video, size: 50, color: Colors.red),
      ),
    );
  }

  void _confirmDelete(Article a) { showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Hapus Koleksi?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")), TextButton(onPressed: () async { final db = await DatabaseHelper.getDatabase(); await db.delete('offline_posts', where: 'id = ?', whereArgs: [a.id]); Navigator.pop(c); _loadOfflineData(); }, child: const Text("Hapus", style: TextStyle(color: Colors.red)))])); }
}