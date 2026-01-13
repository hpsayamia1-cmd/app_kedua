import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'article_view.dart'; 

void main() => runApp(PuskarajaApp());

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
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010A01),
        primaryColor: Colors.greenAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
        cardColor: const Color(0xFF0A140A),
      ),
      home: HomePage(toggleTheme: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class Article {
  final String id, title, content;
  Article({required this.id, required this.title, required this.content});
}

class HomePage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  HomePage({required this.toggleTheme, required this.isDarkMode});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Article> allArticles = [];
  bool isLoading = false;
  Article? leftSelected;
  Article? rightSelected;
  
  // Controller untuk memantau perpindahan halaman
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
      final res = await http.get(Uri.parse('https://sinsangnot.blogspot.com/feeds/posts/default?alt=json&max-results=500'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List entries = data['feed']['entry'] ?? [];
        final dbPath = await getDatabasesPath();
        final db = await openDatabase(p.join(dbPath, 'puska.db'));
        await db.delete('posts'); 
        for (var e in entries) {
          await db.insert('posts', {'id': e['id']['\$t'], 'title': e['title']['\$t'], 'content': e['content']['\$t']});
        }
        _refreshLocal();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sinkronisasi Berhasil!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal Sinkron.")));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor = widget.isDarkMode ? Colors.greenAccent : Colors.green[800]!;
    Color btnBg = widget.isDarkMode ? Colors.white10 : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        leadingWidth: 100,
        // Tombol Tema Modern
        leading: Center(
          child: InkWell(
            onTap: widget.toggleTheme,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: btnBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 18, color: accentColor),
                  const SizedBox(width: 4),
                  Text("Tema", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)),
                ],
              ),
            ),
          ),
        ),
        title: Image.asset('assets/logo.png', height: 35, errorBuilder: (c, e, s) => Text("PUSKARAJA", style: TextStyle(fontSize: 16, color: accentColor, fontWeight: FontWeight.bold))),
        actions: [
          if (isLoading) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else 
            // Tombol Sinkronisasi Modern
            Center(
              child: InkWell(
                onTap: syncData,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: btnBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Sinkronisasi", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)),
                      const SizedBox(width: 4),
                      Icon(Icons.sync, color: accentColor, size: 18),
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
      body: allArticles.isEmpty && !isLoading
          ? const Center(child: Text("Klik sinkron untuk data terbaru"))
          : Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (int page) => setState(() => _currentPage = page),
                    children: [
                      ArticlePanelView(articles: allArticles, selected: leftSelected, onSelect: (a) => setState(() => leftSelected = a)),
                      ArticlePanelView(articles: allArticles, selected: rightSelected, onSelect: (a) => setState(() => rightSelected = a)),
                    ],
                  ),
                ),
                // INDIKATOR TAB BAWAH MODERN
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTabIndicator(0, "PANEL 1", accentColor),
                      const SizedBox(width: 20),
                      _buildTabIndicator(1, "PANEL 2", accentColor),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildTabIndicator(int index, String label, Color accentColor) {
    bool isActive = _currentPage == index;
    return GestureDetector(
      onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? accentColor : Colors.grey)),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            width: isActive ? 40 : 10,
            decoration: BoxDecoration(color: isActive ? accentColor : Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
          )
        ],
      ),
    );
  }
}

class ArticlePanelView extends StatefulWidget {
  final List<Article> articles;
  final Article? selected;
  final Function(Article?) onSelect;

  ArticlePanelView({required this.articles, required this.selected, required this.onSelect});

  @override
  _ArticlePanelViewState createState() => _ArticlePanelViewState();
}

class _ArticlePanelViewState extends State<ArticlePanelView> {
  String query = "";
  final TextEditingController _searchController = TextEditingController();

  void _closeAndReset() {
    setState(() { query = ""; _searchController.clear(); });
    widget.onSelect(null);
  }

  @override
  Widget build(BuildContext context) {
    List<Article> filtered = widget.articles
        .where((a) => a.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return PopScope(
      canPop: widget.selected == null,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _closeAndReset(); },
      child: widget.selected != null 
          ? ArticleReader(title: widget.selected!.title, content: widget.selected!.content, onClose: _closeAndReset)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: "Cari Gending...", // Teks pencarian disederhanakan
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (c, i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        elevation: 1,
                        borderRadius: BorderRadius.circular(10),
                        color: Theme.of(context).cardColor,
                        child: ListTile(
                          dense: true,
                          title: Text(filtered[i].title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.greenAccent, size: 16),
                          onTap: () => widget.onSelect(filtered[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}