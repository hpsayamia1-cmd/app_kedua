import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
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

  Future<void> _toggleTheme() async {
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
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Biru sangat muda
        primaryColor: Colors.blue[800],
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010A01),
        primaryColor: Colors.blueAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      ),
      home: RootNavigation(toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class Article {
  final String id, title, content;
  Article({required this.id, required this.title, required this.content});
}

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
  bool isPanelMode = false;
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
      int maxResultsPerRequest = 5; // Kembali ke 5 agar stabil
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
              await Future.delayed(const Duration(seconds: 1)); // Delay biar gak diblokir
            }
          }
        } else { hasMore = false; }
      }
      await _refreshLocal();
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

  Widget _buildMainHome() {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        leadingWidth: 120,
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (c,e,s) => const Icon(Icons.menu_book)),
        ),
        actions: [_buildSettingsMenu()],
      ),
      body: HomeContentView(
        articles: allArticles,
        onArticleTap: _openArticle,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  Widget _buildPanelLayout() {
    Color btnColor = widget.isDarkMode ? Colors.blueAccent : Colors.blue[800]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPage == 0 ? (leftSelected?.title ?? "Panel 1") : (rightSelected?.title ?? "Beranda Panel 2"), style: const TextStyle(fontSize: 14)),
        leading: IconButton(icon: const Icon(Icons.home), onPressed: () => setState(() => isPanelMode = false)),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () {
            if (_currentPage == 0) setState(() => isPanelMode = false);
            else setState(() => rightSelected = null);
          })
        ],
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            children: [
              ArticleReader(title: leftSelected!.title, content: leftSelected!.content, onClose: () {}),
              rightSelected != null 
                  ? ArticleReader(title: rightSelected!.title, content: rightSelected!.content, onClose: () {})
                  : HomeContentView(articles: allArticles, onArticleTap: (a) => setState(() => rightSelected = a), isDarkMode: widget.isDarkMode),
            ],
          ),
          // Tombol Navigasi Manual
          Positioned(
            top: 10,
            right: _currentPage == 0 ? 10 : null,
            left: _currentPage == 1 ? 10 : null,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: btnColor.withOpacity(0.9), foregroundColor: Colors.white),
              onPressed: () {
                if (_currentPage == 0) _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                else _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
              },
              icon: Icon(_currentPage == 0 ? Icons.arrow_forward : Icons.arrow_back, size: 16),
              label: Text(_currentPage == 0 ? "Ke Panel 2" : "Ke Panel 1", style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu() {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.settings, color: Colors.blue),
      onSelected: (item) async {
        if (item == 0) widget.toggleTheme();
        if (item == 1) syncData();
        if (item == 2) _showAbout();
        if (item == 3) _launchURL("https://sinsangnot.blogspot.com");
        if (item == 4) _launchURL("https://link.dana.id/minta?full_url=https://qr.dana.id/v1/281012012021032196591526");
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 0, child: ListTile(leading: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode), title: Text(widget.isDarkMode ? "Mode Terang" : "Mode Gelap"))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.sync), title: Text("Sinkronisasi Data"))),
        const PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.info), title: Text("Tentang Kami"))),
        const PopupMenuItem(value: 3, child: ListTile(leading: Icon(Icons.language), title: Text("Kunjungi Blog"))),
        const PopupMenuItem(value: 4, child: ListTile(leading: Icon(Icons.favorite, color: Colors.red), title: Text("Donasi"))),
      ],
    );
  }

  void _showAbout() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Tentang Sinsangnot"),
      content: const Text("Perpustakaan Digital Notasi Gending Jawa. Praktis, Cepat, dan Offline."),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
    ));
  }

  Widget _buildInitialDownload() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator()
            else ElevatedButton(onPressed: syncData, child: const Text("DOWNLOAD DATA")),
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
    if (q.isEmpty) { setState(() { isSearching = false; searchResults = []; }); return; }
    setState(() {
      isSearching = true;
      searchResults = widget.articles.where((a) => a.title.toLowerCase().contains(q.toLowerCase()) || a.content.toLowerCase().contains(q.toLowerCase())).toList();
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
              hintText: "Cari judul atau isi...",
              prefixIcon: const Icon(Icons.search, color: Colors.blue),
              filled: true,
              fillColor: widget.isDarkMode ? Colors.white10 : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(child: isSearching ? _buildList(searchResults) : _buildWelcome()),
      ],
    );
  }

  Widget _buildWelcome() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 10),
        const Center(child: Text("Welcome to Sinsangnot", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue))),
        const SizedBox(height: 15),
        const Text(
          "Sinsangnot adalah perpustakaan digital notasi gending Jawa. Wadah pelestarian budaya yang menyajikan koleksi notasi secara praktis dan akurat.",
          textAlign: TextAlign.justify,
          style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey),
        ),
        const SizedBox(height: 25),
        const Text("Notasi Terbaru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        _buildList(widget.articles.take(20).toList()),
      ],
    );
  }

  Widget _buildList(List<Article> list) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, i) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 5),
        title: Text(list[i].title, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.blue),
        onTap: () {
          _searchController.clear();
          _handleSearch("");
          widget.onArticleTap(list[i]);
        },
      ),
    );
  }
}