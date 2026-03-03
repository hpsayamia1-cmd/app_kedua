import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;

// Import file mesin
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
  final String id, title, content, url;
  final List<String> labels;
  String? cleanSvg;
  Article({required this.id, required this.title, required this.content, required this.url, this.labels = const [], this.cleanSvg});
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
  bool isLoadingMore = false, isInitialLoading = true, isSearching = false, isOffline = false;
  String? nextPageToken;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 400) {
      if (!isLoadingMore && nextPageToken != null && _searchController.text.isEmpty && _currentTab == 0 && selectedArticle == null) {
        _fetchMoreFeed();
      }
    }
  }

  String? _preProcessSvg(String content) {
    final RegExp svgExp = RegExp(r"<svg[\s\S]*?<\/svg>");
    final Match? match = svgExp.firstMatch(content);
    if (match != null) return match.group(0)!.replaceAll(RegExp(r"<(style|metadata|defs|desc|title)[\s\S]*?<\/\1>|[a-zA-Z0-9\-]+:attribute|"), "");
    return null;
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

  Future<void> _fetchInitialFeed() async {
    setState(() { isInitialLoading = true; isOffline = false; });
    try {
      final res = await _bloggerService.fetchInitialFeed();
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        feedArticles = _parseArticles(data['items'])..shuffle();
        nextPageToken = data['nextPageToken'];
      }
    } catch (e) { isOffline = true; }
    setState(() => isInitialLoading = false);
  }

  Future<void> _fetchMoreFeed() async {
    if (nextPageToken == null) return;
    setState(() => isLoadingMore = true);
    try {
      final url = "https://www.googleapis.com/blogger/v3/blogs/${_bloggerService.blogId}/posts?key=${_bloggerService.apiKey}&maxResults=8&pageToken=$nextPageToken";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        feedArticles.addAll(_parseArticles(data['items']));
        nextPageToken = data['nextPageToken'];
      }
    } catch (e) {}
    setState(() => isLoadingMore = false);
  }

  Future<void> _handleSearch(String q) async {
    if (q.isEmpty) return;
    _searchFocusNode.unfocus(); 
    setState(() { isSearching = true; filteredSuggestions = []; selectedArticle = null; _searchController.text = q; });
    try {
      final res = await _bloggerService.searchPosts(q);
      if (res.statusCode == 200) {
        final api = _parseArticles(json.decode(res.body)['items']);
        setState(() { searchResults = api; _currentTab = 0; isOffline = false; });
      } else { _searchOfflineLocally(q); }
    } catch (e) { _searchOfflineLocally(q); }
    setState(() => isSearching = false);
  }

  void _searchOfflineLocally(String q) async {
    await _loadOfflineData();
    List<Article> local = offlineArticles.where((a) => a.title.toLowerCase().contains(q.toLowerCase())).toList();
    setState(() { searchResults = local; _currentTab = 0; });
  }

  Future<void> _openFromSitemap(String url) async {
    setState(() { isSearching = true; filteredSuggestions = []; });
    try {
      final res = await http.get(Uri.parse("https://www.googleapis.com/blogger/v3/blogs/${_bloggerService.blogId}/posts/bypath?path=${Uri.parse(url).path}&key=${_bloggerService.apiKey}"));
      if (res.statusCode == 200) setState(() { selectedArticle = _parseArticles([json.decode(res.body)]).first; _searchController.clear(); _searchFocusNode.unfocus(); });
    } catch (e) {}
    setState(() => isSearching = false);
  }

  List<Article> _parseArticles(dynamic items) {
    if (items == null) return [];
    return List<Article>.from(items.map((i) => Article(id: i['id'], title: i['title'], content: i['content'] ?? "", url: i['url'], labels: List<String>.from(i['labels'] ?? []), cleanSvg: _preProcessSvg(i['content'] ?? ""))));
  }

  Future<void> _loadOfflineData() async {
    final db = await DatabaseHelper.getDatabase();
    final maps = await db.query('offline_posts');
    setState(() { offlineArticles = maps.map((e) => Article(id: e['id'].toString(), title: e['title'].toString(), content: e['content'].toString(), url: e['url'].toString(), labels: List<String>.from(json.decode(e['labels']?.toString() ?? "[]")), cleanSvg: _preProcessSvg(e['content'].toString()))).toList(); });
  }

  void _resetSearch() { _searchController.clear(); _searchFocusNode.unfocus(); setState(() { searchResults = []; filteredSuggestions = []; isSearching = false; }); }

  void _showInternalPage(String title, String content) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Container(padding: const EdgeInsets.all(24), height: MediaQuery.of(context).size.height * 0.5, child: Column(children: [Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 15), Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)))), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Tutup", style: TextStyle(color: Colors.white))))])));
  }

  @override
  Widget build(BuildContext context) {
    // KEMBALIKAN SPLASH SCREEN KE MAIN.DART
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
      isLoading: isInitialLoading || isSearching || isLoadingMore,
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
      onSitemapTap: _openFromSitemap,
      onResetSearch: _resetSearch,
      onLogoTap: () { _resetSearch(); setState(() { _currentTab = 0; selectedArticle = null; }); },
    );

    return WillPopScope(
      onWillPop: () async { if (selectedArticle != null) { setState(() => selectedArticle = null); return false; } if (_searchController.text.isNotEmpty) { _resetSearch(); return false; } if (_currentTab != 0) { setState(() => _currentTab = 0); return false; } return true; },
      child: Scaffold(
        appBar: header,
        body: Stack(children: [
          RefreshIndicator(color: Colors.red, onRefresh: _fetchInitialFeed, child: selectedArticle != null ? ArticleReader(id: selectedArticle!.id, title: selectedArticle!.title, content: selectedArticle!.content, url: selectedArticle!.url, labels: selectedArticle!.labels, isDarkMode: widget.isDarkMode, onClose: () => setState(() => selectedArticle = null), onLoadStart: () => {}, onLoadEnd: () => {}) : _buildTabContent()),
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
    if (isOffline && _currentTab == 0 && feedArticles.isEmpty && searchResults.isEmpty && _searchController.text.isEmpty) return _buildOfflineError();
    
    final footerUI = FooterWidget(currentTab: _currentTab, isDarkMode: widget.isDarkMode, onTabTap: (i){}, onThemeChanged: widget.updateTheme, showInternalPage: _showInternalPage, gendingLabels: gendingLabels, onLabelTap: _handleSearch);

    switch (_currentTab) {
      case 0: return _buildArticleList(_searchController.text.isNotEmpty ? searchResults : feedArticles);
      case 1: return footerUI.buildJelajah();
      case 2: return _buildArticleList(offlineArticles, isOfflineTab: true);
      case 3: return footerUI.buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
  }

  Widget _buildSkeletonList() => ListView.builder(itemCount: 5, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(children: [Container(height: 200, color: widget.isDarkMode ? Colors.white10 : Colors.grey[200]), ListTile(leading: CircleAvatar(backgroundColor: widget.isDarkMode ? Colors.white10 : Colors.grey[200]), title: Container(height: 15, color: widget.isDarkMode ? Colors.white10 : Colors.grey[200]))])));
  Widget _buildOfflineError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.wifi_off, size: 80, color: Colors.grey), const Text("Maaf anda sedang offline."), const SizedBox(height: 20), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => setState(() => _currentTab = 2), child: const Text("Buka Koleksi", style: TextStyle(color: Colors.white)))]));
  
  Widget _buildArticleList(List<Article> list, {bool isOfflineTab = false}) {
    if (list.isEmpty) return Center(child: Text(isOfflineTab ? "Belum ada koleksi." : "Hasil tidak ditemukan."));
    return ListView.builder(controller: _currentTab == 0 ? _scrollController : null, itemCount: list.length + (isLoadingMore && _currentTab == 0 ? 1 : 0), itemBuilder: (c, i) {
      if (i == list.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.red)));
      final a = list[i];
      return Column(children: [InkWell(onTap: () => setState(() => selectedArticle = a), child: _getThumbnailOptimized(a)), ListTile(onTap: () => setState(() => selectedArticle = a), leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.music_note, color: Colors.white, size: 20)), title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(isOfflineTab ? "Tersedia Offline" : "Sinsangnot • ${a.labels.isNotEmpty ? a.labels.first : 'Gending'}"), trailing: isOfflineTab ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(a)) : const Icon(Icons.more_vert, size: 18)), const SizedBox(height: 12)]);
    });
  }

  // LOGIKA THUMBNAIL BERBASIS LABEL (SESUAI PERMINTAAN)
  Widget _getThumbnailOptimized(Article a) {
    String assetPath = 'assets/gong6.png'; 
    String labelsText = a.labels.join(' ').toLowerCase();

    if (labelsText.contains('ketawang')) {
      assetPath = 'assets/ketawang.png';
    } else if (labelsText.contains('ladrang')) {
      assetPath = 'assets/ladrang.png';
    } else if (labelsText.contains('ayak')) {
      assetPath = 'assets/ayak.png';
    } else if (labelsText.contains('tayub')) {
      assetPath = 'assets/gong1.png';
    } else if (labelsText.contains('slendro')) {
      assetPath = 'assets/gong2.png';
    } else if (labelsText.contains('pelog')) {
      assetPath = 'assets/gong3.png';
    } else if (labelsText.contains('gending')) {
      assetPath = 'assets/gong5.png';
    }

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