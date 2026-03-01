import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';
import 'article_view.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PuskarajaApp());
}

class PuskarajaApp extends StatefulWidget {
  @override
  State<PuskarajaApp> createState() => _PuskarajaAppState();
}

class _PuskarajaAppState extends State<PuskarajaApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bool isDark = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
      prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F0F0F), elevation: 0),
      ),
      home: RootNavigation(toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class Article {
  final String id, title, content, url;
  Article({required this.id, required this.title, required this.content, required this.url});
}
class RootNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  RootNavigation({required this.toggleTheme, required this.isDarkMode});

  @override
  _RootNavigationState createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentTab = 0; // 0: Home, 1: Jelajah, 2: Koleksi, 3: Setelan, 99: Search
  Article? selectedArticle;
  List<Article> allArticles = [];
  List<Article> searchSuggestions = [];
  bool isPageLoading = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final ScrollController _scrollController = ScrollController();
  double _headerOffset = 0.0;
  final double _headerHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _refreshLocal();
    _scrollController.addListener(_updateHeaderOffset);
  }

  void _updateHeaderOffset() {
    if (!_scrollController.hasClients) return;
    double delta = _scrollController.position.userScrollDirection == ScrollDirection.reverse ? 1.5 : -1.5;
    setState(() {
      _headerOffset = (_headerOffset + delta).clamp(0.0, _headerHeight);
    });
  }

  Future<void> _refreshLocal() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 1);
    final List<Map<String, dynamic>> maps = await db.query('posts');
    setState(() {
      allArticles = maps.map((e) => Article(
        id: e['id'], title: e['title'], content: e['content'],
        url: e['url'] ?? "https://sinsangnot.blogspot.com"
      )).toList();
    });
  }

  void _onSearchChanged(String q) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (q.isEmpty) { setState(() => searchSuggestions = []); return; }
      setState(() {
        _currentTab = 0; // Reset tab ke home saat mengetik saran
        searchSuggestions = allArticles
            .where((a) => a.title.toLowerCase().contains(q.toLowerCase()))
            .take(5).toList();
      });
    });
  }

  void _performFullSearch(String query) {
    if (query.isEmpty) return;
    setState(() {
      searchSuggestions = [];
      _currentTab = 99; // Masuk ke mode hasil pencarian penuh
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: selectedArticle != null ? 0 : (_headerHeight - _headerOffset)),
            child: selectedArticle != null 
              ? ArticleReader(
                  title: selectedArticle!.title, 
                  content: selectedArticle!.content,
                  url: selectedArticle!.url,
                  onClose: () => setState(() => selectedArticle = null),
                  onLoadStart: () => setState(() => isPageLoading = true),
                  onLoadEnd: () => setState(() => isPageLoading = false),
                )
              : _buildTabContent(),
          ),
          Positioned(
            top: -_headerOffset,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _buildYouTubeHeader(),
                if (isPageLoading) 
                  const LinearProgressIndicator(backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(Colors.red), minHeight: 2),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildYouTubeFooter(),
    );
  }

  Widget _buildYouTubeHeader() {
    return Container(
      height: _headerHeight,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.language, color: Colors.grey), 
            onPressed: () => launchUrl(Uri.parse("https://sinsangnot.blogspot.com"), mode: LaunchMode.externalApplication)),
          Image.asset('assets/logo.png', height: 26, errorBuilder: (c,e,s) => const Icon(Icons.play_circle_fill, color: Colors.red)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: _performFullSearch,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(hintText: "Cari...", prefixIcon: Icon(Icons.search, size: 18), border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 10)),
              ),
            ),
          ),
          IconButton(icon: Icon(widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20), onPressed: widget.toggleTheme),
        ],
      ),
    );
  }

  Widget _buildYouTubeFooter() {
    return BottomNavigationBar(
      currentIndex: _currentTab == 99 ? 0 : _currentTab,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 10, unselectedFontSize: 10,
      selectedItemColor: widget.isDarkMode ? Colors.white : Colors.black,
      unselectedItemColor: Colors.grey,
      onTap: (index) => setState(() { _currentTab = index; _searchController.clear(); }),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Jelajah'),
        BottomNavigationBarItem(icon: Icon(Icons.library_add_check_outlined), label: 'Koleksi'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Setelan'),
      ],
    );
  }
  Widget _buildTabContent() {
    if (_searchController.text.isNotEmpty && _currentTab != 99) {
      return ListView.builder(
        controller: _scrollController,
        itemCount: searchSuggestions.length,
        itemBuilder: (c, i) => ListTile(
          leading: const Icon(Icons.history, color: Colors.grey, size: 20),
          title: Text(searchSuggestions[i].title),
          onTap: () {
            setState(() { selectedArticle = searchSuggestions[i]; _searchController.clear(); });
          },
        ),
      );
    }

    if (_currentTab == 99) return _buildFullSearchResults();

    switch (_currentTab) {
      case 0: return _buildBeranda();
      case 1: return const Center(child: Text("Jelajah Kategori"));
      case 2: return const Center(child: Text("Koleksi Offline"));
      case 3: return _buildSetelan();
      default: return _buildBeranda();
    }
  }

  Widget _buildFullSearchResults() {
    final query = _searchController.text.toLowerCase();
    final results = allArticles.where((a) => a.title.toLowerCase().contains(query) || a.content.toLowerCase().contains(query)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.all(16), child: Text("Hasil untuk: \"${_searchController.text}\"", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        Expanded(
          child: results.isEmpty ? const Center(child: Text("Tidak ditemukan.")) : ListView.builder(
            controller: _scrollController,
            itemCount: results.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.music_note, color: Colors.red),
              title: Text(results[i].title),
              onTap: () => setState(() => selectedArticle = results[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBeranda() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(15),
      children: [
        const Center(child: Text("Welcome to Sinsangnot", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        const Text("Perpustakaan Digital Notasi Gending Jawa. Praktis dan Lengkap.", textAlign: TextAlign.justify, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 25),
        const Text("Notasi Terbaru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        ...allArticles.take(20).map((a) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.play_arrow_outlined, color: Colors.red),
          title: Text(a.title, style: const TextStyle(fontSize: 14)),
          onTap: () => setState(() => selectedArticle = a),
        )),
      ],
    );
  }

  Widget _buildSetelan() {
    return ListView(
      controller: _scrollController,
      children: [
        ListTile(leading: const Icon(Icons.sync), title: const Text("Sinkronisasi"), onTap: () {}),
        ListTile(leading: const Icon(Icons.info_outline), title: const Text("Tentang"), onTap: () {}),
        ListTile(leading: const Icon(Icons.favorite, color: Colors.red), title: const Text("Donasi"), onTap: () {}),
      ],
    );
  }
} // Penutup Class _RootNavigationState
