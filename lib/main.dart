import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'article_view.dart'; 
import 'package:flutter/services.dart';

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

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        prefs.setBool('isDarkMode', true);
      } else {
        _themeMode = ThemeMode.light;
        prefs.setBool('isDarkMode', false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: Colors.green[800],
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010A01),
        primaryColor: Colors.greenAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
        cardColor: const Color(0xFF0A140A),
      ),
      home: RootNavigation(toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class Article {
  final String id, title, content;
  Article({required this.id, required this.title, required this.content});
}

// --- ROOT NAVIGATION ---
class RootNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  RootNavigation({required this.toggleTheme, required this.isDarkMode});

  @override
  _RootNavigationState createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  List<Article> allArticles = [];
  bool isLoading = false;
  bool isPanelMode = false; // Menentukan apakah sedang di mode baca (Panel) atau Beranda Utama
  
  Article? leftSelected;
  Article? rightSelected;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _refreshLocal();
  }

  Future<void> _refreshLocal() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 1, onCreate: (db, v) {
      db.execute("CREATE TABLE posts(id TEXT PRIMARY KEY, title TEXT, content TEXT)");
    });
    final List<Map<String, dynamic>> maps = await db.query('posts');
    setState(() {
      allArticles = maps.map((e) => Article(id: e['id'], title: e['title'], content: e['content'])).toList();
    });
  }

  Future<void> syncData() async {
    setState(() => isLoading = true);
    try {
      final dbPath = await getDatabasesPath();
      final db = await openDatabase(p.join(dbPath, 'puska.db'));
      int startIndex = 1;
      int maxResultsPerRequest = 10; 
      bool hasMore = true;

      await db.delete('posts'); 

      while (hasMore) {
        final url = 'https://sinsangnot.blogspot.com/feeds/posts/default?alt=json&start-index=$startIndex&max-results=$maxResultsPerRequest&orderby=published';
        final res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final List entries = data['feed']['entry'] ?? [];
          if (entries.isEmpty) {
            hasMore = false; 
          } else {
            for (var e in entries) {
              String fullContent = e['content'] != null ? e['content']['\$t'] : "";
              if (fullContent.isEmpty && e['summary'] != null) fullContent = e['summary']['\$t'];
              await db.insert('posts', {'id': e['id']['\$t'], 'title': e['title']['\$t'], 'content': fullContent}, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            if (entries.length < maxResultsPerRequest) {
              hasMore = false;
            } else {
              startIndex += maxResultsPerRequest;
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        } else { hasMore = false; }
      }
      await _refreshLocal();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sinkronisasi Berhasil!")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal Sinkron.")));
    }
    setState(() => isLoading = false);
  }

  void _openArticle(Article article) {
    setState(() {
      leftSelected = article;
      isPanelMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Jika data kosong, tampilkan layar download awal
    if (allArticles.isEmpty) return _buildInitialDownload();

    return PopScope(
      canPop: !isPanelMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_currentPage == 1) {
            if (rightSelected != null) {
              setState(() => rightSelected = null);
            } else {
              _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            }
          } else {
            setState(() => isPanelMode = false);
          }
        }
      },
      child: isPanelMode ? _buildPanelLayout() : _buildMainHome(),
    );
  }

  // --- LAYAR BERANDA UTAMA (Layar Tunggal) ---
  Widget _buildMainHome() {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo.png', height: 40, errorBuilder: (c,e,s) => const Text("SINSANGNOT")),
        actions: [_buildSettingsMenu()],
      ),
      body: HomeContentView(
        articles: allArticles,
        onArticleTap: _openArticle,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  // --- LAYAR PANEL (Mode Baca) ---
  Widget _buildPanelLayout() {
    Color accentColor = widget.isDarkMode ? Colors.greenAccent : Colors.green[800]!;

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            children: [
              // Panel 1: Selalu isi Artikel
              _buildSliverReader(leftSelected!, true),
              // Panel 2: Artikel jika ada, jika tidak tampilkan Beranda
              rightSelected != null 
                  ? _buildSliverReader(rightSelected!, false)
                  : Scaffold(
                      appBar: AppBar(
                        title: const Text("Beranda Panel 2", style: TextStyle(fontSize: 14)),
                        automaticallyImplyLeading: false,
                        actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.ease))],
                      ),
                      body: HomeContentView(
                        articles: allArticles,
                        onArticleTap: (a) => setState(() => rightSelected = a),
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
            ],
          ),
          // Tombol Navigasi Melayang
          if (_currentPage == 0)
            Positioned(
              top: 100, right: 10,
              child: FloatingActionButton.extended(
                heroTag: "btn1",
                onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                label: const Text("Panel 2"), icon: const Icon(Icons.arrow_forward),
                backgroundColor: accentColor.withOpacity(0.8), sizeConstraints: const BoxConstraints.tightFor(height: 40),
              ),
            ),
          if (_currentPage == 1)
            Positioned(
              top: 100, left: 10,
              child: FloatingActionButton.extended(
                heroTag: "btn2",
                onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                label: const Text("Panel 1"), icon: const Icon(Icons.arrow_back),
                backgroundColor: accentColor.withOpacity(0.8), sizeConstraints: const BoxConstraints.tightFor(height: 40),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverReader(Article article, bool isLeft) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          floating: true, snap: true, pinned: false,
          leading: IconButton(icon: const Icon(Icons.home), onPressed: () => setState(() => isPanelMode = false)),
          title: Text(article.title, style: const TextStyle(fontSize: 14)),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => isLeft ? setState(() => isPanelMode = false) : setState(() => rightSelected = null),
            )
          ],
        ),
      ],
      body: ArticleReader(title: article.title, content: article.content, onClose: () {}),
    );
  }

  Widget _buildSettingsMenu() {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.settings),
      onSelected: (item) {
        if (item == 0) widget.toggleTheme();
        if (item == 1) syncData();
        if (item == 2) _launchURL("https://link.dana.id/minta?full_url=https://qr.dana.id/v1/281012012021032196591526");
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 0, child: ListTile(leading: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode), title: Text(widget.isDarkMode ? "Mode Terang" : "Mode Gelap"))),
        PopupMenuItem(value: 1, child: ListTile(leading: const Icon(Icons.sync), title: const Text("Sinkronisasi Data"))),
        PopupMenuItem(value: 2, child: ListTile(leading: const Icon(Icons.favorite, color: Colors.red), title: const Text("Donasi DANA"))),
      ],
    );
  }

  Widget _buildInitialDownload() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator()
            else ElevatedButton(onPressed: syncData, child: const Text("DOWNLOAD DATA NOTASI")),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw 'Could not launch $url';
  }
}

// --- KOMPONEN ISI BERANDA & PENCARIAN ---
class HomeContentView extends StatefulWidget {
  final List<Article> articles;
  final Function(Article) onArticleTap;
  final bool isDarkMode;

  HomeContentView({required this.articles, required this.onArticleTap, required this.isDarkMode});

  @override
  _HomeContentViewState createState() => _HomeContentViewState();
}

class _HomeContentViewState extends State<HomeContentView> {
  final TextEditingController _searchController = TextEditingController();
  List<Article> searchResults = [];
  bool isSearching = false;

  void _handleSearch(String q) {
    if (q.isEmpty) {
      setState(() { isSearching = false; searchResults = []; });
      return;
    }
    // Pencarian Full-Text (Judul + Isi)
    setState(() {
      isSearching = true;
      searchResults = widget.articles.where((a) => 
        a.title.toLowerCase().contains(q.toLowerCase()) || 
        a.content.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _handleSearch,
            decoration: InputDecoration(
              hintText: "Cari judul atau isi notasi...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _handleSearch(""); }) 
                  : null,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: isSearching ? _buildSearchResults() : _buildWelcomePage(),
        ),
      ],
    );
  }

  Widget _buildWelcomePage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text("Welcome to Sinsangnot", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.greenAccent : Colors.green[900])),
        const SizedBox(height: 10),
        const Text(
          "Sinsangnot adalah perpustakaan digital notasi gending Jawa. "
          "Temukan ribuan koleksi notasi yang bisa diakses secara cepat dan offline untuk melestarikan budaya karawitan.",
          style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey),
        ),
        const SizedBox(height: 30),
        const Text("Notasi Terbaru:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...widget.articles.take(10).map((a) => _articleTile(a)),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (searchResults.isEmpty) return const Center(child: Text("Tidak ada hasil ditemukan."));
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, i) => _articleTile(searchResults[i]),
    );
  }

  Widget _articleTile(Article a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _searchController.clear();
          _handleSearch("");
          widget.onArticleTap(a);
        },
      ),
    );
  }
}