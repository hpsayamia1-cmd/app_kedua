import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p; // Menggunakan alias 'p' untuk menghindari konflik context
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

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
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'content': content};
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
      // URL sudah diganti ke sinsangnot.blogspot.com
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
        elevation: 0,
        title: Image.asset(
          'assets/logo.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => 
            Icon(Icons.menu_book, color: Colors.greenAccent),
        ),
        actions: [
          if (isLoading) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ) 
          else 
            IconButton(
              icon: Icon(Icons.sync, color: Colors.greenAccent), 
              onPressed: syncData
            )
        ],
      ),
      body: allArticles.isEmpty && !isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Silahkan klik tombol sinkron (🔄) diatas untuk download notasi atau update notasi terbaru",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 16),
                ),
              ),
            )
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

  @override
  Widget build(BuildContext context) {
    List<Article> filtered = widget.articles
        .where((a) => a.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.greenAccent.withOpacity(0.05), width: 1))
      ),
      child: widget.selected != null 
        ? _buildReader(widget.selected!) 
        : Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: "Cari di ${widget.label}...",
                    prefixIcon: Icon(Icons.search, color: Colors.greenAccent, size: 20),
                    filled: true, 
                    fillColor: Colors.greenAccent.withOpacity(0.05),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (c, i) => Divider(color: Colors.white10, height: 1),
                  itemBuilder: (c, i) => ListTile(
                    title: Text(filtered[i].title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.greenAccent.withOpacity(0.5)),
                    onTap: () => widget.onSelect(filtered[i]),
                  ),
                ),
              ),
            ],
          ),
    );
  }

Widget _buildReader(Article art) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.greenAccent.withOpacity(0.05),
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.close, color: Colors.redAccent), onPressed: () => widget.onSelect(null)),
              Expanded(child: Text(art.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: HtmlWidget(
              art.content,
              customStylesBuilder: (element) {
                // SOLUSI SVG RESPONSIF & INVERT WARNA
                if (element.localName == 'img' || element.localName == 'svg') {
                  return {
                    'max-width': '100%', // Memaksa gambar tidak melebihi lebar layar
                    'height': 'auto',    // Menjaga proporsi agar tidak gepeng
                    'display': 'block',
                    'margin': '10px auto',
                    // Membalik warna: Hitam jadi Putih, tanpa latar belakang putih
                    'filter': 'invert(100%) hue-rotate(180deg) brightness(1.5)',
                  };
                }
                
                // CSS Tambahan untuk tabel agar responsif juga
                if (element.localName == 'table') {
                  return {
                    'border': '1px solid #333',
                    'width': '100%',
                    'table-layout': 'fixed', // Mencegah tabel meluap ke samping
                  };
                }

                return null;
              },
              textStyle: TextStyle(fontSize: 16, height: 1.6, color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
      ],
    );
  }