import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart'; // Library baru
import 'article_view.dart'; 

void main() => runApp(PuskarajaApp());

class PuskarajaApp extends StatefulWidget {
  @override
  State<PuskarajaApp> createState() => _PuskarajaAppState();
}

class _PuskarajaAppState extends State<PuskarajaApp> {
  // Default tema terang sesuai permintaan
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings(); // Muat tema yang disimpan saat aplikasi dibuka
  }

  // Fungsi untuk memuat pengaturan tema dari memori HP
  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bool isDark = prefs.getBool('isDarkMode') ?? false; // Default false (terang)
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // Fungsi untuk ganti tema dan menyimpannya
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
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
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

// ... (Class Article tetap sama) ...
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
    Color accentColor = widget.isDarkMode ? Colors.greenAccent : Colors.green[700]!;

    return Scaffold(
      appBar: AppBar(
        // Bagian Leading: Label Tema + Icon
        leadingWidth: 110,
        leading: InkWell(
          onTap: widget.toggleTheme,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20, color: accentColor),
              const SizedBox(width: 4),
              Text("Tema", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor)),
            ],
          ),
        ),
        title: Image.asset('assets/logo.png', height: 35, errorBuilder: (c, e, s) => Text("PUSKARAJA", style: TextStyle(fontSize: 16, color: accentColor))),
        actions: [
          if (isLoading) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else 
            // Bagian Action: Label Sinkronisasi + Icon
            InkWell(
              onTap: syncData,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Text("Sinkronisasi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor)),
                    const SizedBox(width: 4),
                    Icon(Icons.sync, color: accentColor, size: 20),
                  ],
                ),
              ),
            )
        ],
      ),
      body: allArticles.isEmpty && !isLoading
          ? Center(child: Text("Klik sinkron untuk data terbaru", style: TextStyle(color: Colors.grey)))
          : PageView(
              children: [
                ArticlePanelView(articles: allArticles, selected: leftSelected, onSelect: (a) => setState(() => leftSelected = a), label: "PANEL KIRI"),
                ArticlePanelView(articles: allArticles, selected: rightSelected, onSelect: (a) => setState(() => rightSelected = a), label: "PANEL KANAN"),
              ],
            ),
    );
  }
}

// ... (Class ArticlePanelView sisanya tetap sama dengan sebelumnya) ...
class ArticlePanelView extends StatefulWidget {
  final List<Article> articles;
  final Article? selected;
  final Function(Article?) onSelect;
  final String label;

  ArticlePanelView({required this.articles, required this.selected, required this.onSelect, required this.label});

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
      child: Container(
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)))),
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
                      hintText: "Cari di ${widget.label}...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (c, i) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        elevation: 1,
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                        child: ListTile(
                          title: Text(filtered[i].title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.greenAccent, size: 18),
                          onTap: () => widget.onSelect(filtered[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}