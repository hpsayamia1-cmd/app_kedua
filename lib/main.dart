import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; 
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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _refreshLocal();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Tentang Kami"),
        content: const Text(
          "Sinsangnot adalah aplikasi perpustakaan notasi gending Jawa yang praktis dan portabel. "
          "Dibuat untuk memudahkan akses notasi secara cepat dan offline.\n\n"
          "Seluruh data bersumber dari sinsangnot.blogspot.com."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchURL("https://sinsangnot.blogspot.com");
            }, 
            child: const Text("Kunjungi Blog", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
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
      int maxResultsPerRequest = 5; 
      bool hasMore = true;
      int totalSaved = 0;

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
              totalSaved++;
            }
            if (entries.length < maxResultsPerRequest) {
              hasMore = false;
            } else {
              startIndex += maxResultsPerRequest;
              await Future.delayed(const Duration(seconds: 3));
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

  @override
  Widget build(BuildContext context) {
    Color accentColor = widget.isDarkMode ? Colors.greenAccent : Colors.green[800]!;

    if (allArticles.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_music, size: 80, color: accentColor),
                const SizedBox(height: 20),
                const Text("Unduh Notasi Gamelan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                if (isLoading) ...[
                  CircularProgressIndicator(color: accentColor),
                  const SizedBox(height: 20),
                  const Text("Tunggu proses download selesai...", textAlign: TextAlign.center),
                  const Text("Kecepatan download bergantung pada koneksi internet anda.", 
                    style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    onPressed: syncData,
                    icon: const Icon(Icons.download),
                    label: const Text("DOWNLOAD SEKARANG"),
                  ),
                ]
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        leadingWidth: 110, 
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => Icon(Icons.menu_book, color: accentColor, size: 35)),
        ),
        actions: [
          if (isLoading) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else 
            IconButton(icon: Icon(Icons.sync, color: accentColor, size: 28), onPressed: syncData),

          PopupMenuButton<int>(
            icon: Icon(Icons.settings, color: accentColor, size: 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (item) {
              switch (item) {
                case 0: widget.toggleTheme(); break;
                case 1: _showAboutDialog(); break;
                case 2: _launchURL("https://sinsangnot.blogspot.com"); break;
                case 3: _launchURL("https://link.dana.id/minta?full_url=https://qr.dana.id/v1/281012012021032196591526"); break; 
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20, color: Colors.amber),
                    const SizedBox(width: 12),
                    Text(widget.isDarkMode ? "Mode Terang" : "Mode Gelap"),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 1,
                child: Row(children: [Icon(Icons.info_outline, size: 20), SizedBox(width: 12), Text("Tentang Kami")]),
              ),
              const PopupMenuItem(
                value: 2,
                child: Row(children: [Icon(Icons.language, size: 20), SizedBox(width: 12), Text("Kunjungi Blog")]),
              ),
              const PopupMenuItem(
                value: 3,
                child: Row(children: [Icon(Icons.favorite, size: 20, color: Colors.redAccent), SizedBox(width: 12), Text("Donasi")]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
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
                const SizedBox(width: 25),
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
      onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? accentColor : Colors.grey)),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4, width: isActive ? 45 : 12,
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

  @override
  Widget build(BuildContext context) {
    List<Article> filtered = widget.articles.where((a) => a.title.toLowerCase().contains(query.toLowerCase())).toList();
    
    return PopScope(
      canPop: widget.selected == null,
      onPopInvokedWithResult: (didPop, result) { 
        if (!didPop) {
          setState(() {
            query = "";
            _searchController.clear();
          });
          widget.onSelect(null); 
        }
      },
      child: widget.selected != null 
          ? ArticleReader(
              title: widget.selected!.title, 
              content: widget.selected!.content, 
              onClose: () {
                setState(() {
                  query = "";
                  _searchController.clear();
                });
                widget.onSelect(null);
              }
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(
                      hintText: "Cari Gending...", 
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              query = "";
                            }),
                          )
                        : null,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}