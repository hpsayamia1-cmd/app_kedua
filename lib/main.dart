import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'article_view.dart'; 

void main() => runApp(PuskarajaApp());

// Mengubah menjadi StatefulWidget untuk menyimpan status Tema
class PuskarajaApp extends StatefulWidget {
  @override
  State<PuskarajaApp> createState() => _PuskarajaAppState();
}

class _PuskarajaAppState extends State<PuskarajaApp> {
  // 1. Variabel status tema (default: dark)
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      // Konfigurasi Tema Terang
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black),
        cardColor: Colors.white,
      ),
      // Konfigurasi Tema Gelap (Warna Hijau Gelap kamu tetap di sini)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010A01),
        primaryColor: Colors.greenAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
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
          await db.insert('posts', {
            'id': e['id']['\$t'],
            'title': e['title']['\$t'],
            'content': e['content']['\$t'],
          });
        }
        _refreshLocal();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sinkronisasi Berhasil!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal Sinkron. Cek koneksi.")));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        // 2. Tombol pengatur tema di sebelah kiri (leading)
        leading: IconButton(
          icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: widget.toggleTheme,
        ),
        title: Image.asset('assets/logo.png', height: 40, errorBuilder: (c, e, s) => const Icon(Icons.menu_book, color: Colors.greenAccent)),
        actions: [
          if (isLoading) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else 
            IconButton(icon: const Icon(Icons.sync, color: Colors.greenAccent), onPressed: syncData)
        ],
      ),
      body: allArticles.isEmpty && !isLoading
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Silahkan klik tombol sinkron diatas untuk download notasi terbaru", textAlign: TextAlign.center, style: TextStyle(color: Colors.greenAccent.withOpacity(0.7)))))
          : PageView(
              children: [
                ArticlePanelView(
                  articles: allArticles, 
                  selected: leftSelected, 
                  onSelect: (a) => setState(() => leftSelected = a),
                  label: "PANEL KIRI",
                ),
                ArticlePanelView(
                  articles: allArticles, 
                  selected: rightSelected, 
                  onSelect: (a) => setState(() => rightSelected = a),
                  label: "PANEL KANAN",
                ),
              ],
            ),
    );
  }
}

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
    setState(() {
      query = "";
      _searchController.clear();
    });
    widget.onSelect(null);
  }

  @override
  Widget build(BuildContext context) {
    List<Article> filtered = widget.articles
        .where((a) => a.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return PopScope(
      canPop: widget.selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeAndReset();
      },
      child: Container(
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)))),
        child: widget.selected != null 
          ? ArticleReader(
              title: widget.selected!.title,
              content: widget.selected!.content,
              onClose: _closeAndReset,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: "Cari di ${widget.label}...",
                      prefixIcon: const Icon(Icons.search, color: Colors.greenAccent),
                      suffixIcon: query.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                            setState(() { query = ""; _searchController.clear(); });
                          }) 
                        : null,
                      filled: true, 
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder( // Menggunakan builder untuk efisiensi Card
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (c, i) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      // 3. Membungkus Daftar dengan Box ber-radius (Card)
                      child: Material(
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        color: Theme.of(context).cardColor,
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          title: Text(filtered[i].title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.greenAccent),
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