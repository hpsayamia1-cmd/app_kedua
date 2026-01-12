import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
// PENTING: Import file viewer yang baru
import 'article_view.dart'; 

void main() => runApp(PuskarajaApp());

class PuskarajaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010A01),
        primaryColor: Colors.greenAccent,
        colorScheme: ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.greenAccent[700]!,
        ),
      ),
      home: HomePage(),
    );
  }
}

class Article {
  final String id, title, content;
  Article({required this.id, required this.title, required this.content});
}

class HomePage extends StatefulWidget {
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sinkronisasi Berhasil!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal Sinkron. Cek koneksi.")));
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.black,
        title: Image.asset('assets/logo.png', height: 40, errorBuilder: (c, e, s) => Icon(Icons.menu_book, color: Colors.greenAccent)),
        actions: [
          if (isLoading) 
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else 
            IconButton(icon: Icon(Icons.sync, color: Colors.greenAccent), onPressed: syncData)
        ],
      ),
      body: allArticles.isEmpty && !isLoading
          ? Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Silahkan klik tombol sinkron diatas untuk download notasi terbaru", textAlign: TextAlign.center, style: TextStyle(color: Colors.greenAccent.withOpacity(0.7)))))
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

  // Fungsi untuk menutup artikel sekaligus reset pencarian
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

    // Membungkus dengan PopScope agar tombol back HP tidak langsung keluar aplikasi
    return PopScope(
      canPop: widget.selected == null, // Jika artikel terbuka, jangan keluar aplikasi
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeAndReset();
      },
      child: Container(
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white10))),
        child: widget.selected != null 
          ? ArticleReader(
              title: widget.selected!.title,
              content: widget.selected!.content,
              onClose: _closeAndReset, // Gunakan fungsi reset
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController, // Tambahkan controller
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: "Cari di ${widget.label}...",
                      prefixIcon: Icon(Icons.search, color: Colors.greenAccent),
                      suffixIcon: query.isNotEmpty 
                        ? IconButton(icon: Icon(Icons.clear), onPressed: () {
                            setState(() { query = ""; _searchController.clear(); });
                          }) 
                        : null,
                      filled: true, fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (c, i) => Divider(color: Colors.white10, height: 1),
                    itemBuilder: (c, i) => ListTile(
                      title: Text(filtered[i].title, style: TextStyle(fontSize: 15)),
                      onTap: () => widget.onSelect(filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}