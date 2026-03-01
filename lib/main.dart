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
  // SETELAN AWAL: TEMA GELAP (DARK MODE)
  ThemeMode _themeMode = ThemeMode.dark; 

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Jika belum pernah setting, default-nya Dark (true)
      bool isDark = prefs.getBool('isDarkMode') ?? true; 
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
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Hitam YouTube
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
  int _currentTab = 0; 
  Article? selectedArticle;
  List<Article> allArticles = [];
  List<Article> searchSuggestions = [];
  bool isPageLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _headerOffset = 0.0;
  final double _headerHeight = 60.0;
  Timer? _debounce;

  // KONFIGURASI BLOGGER (ISI DI SINI)
  final String blogId = "1371452320359744712"; 
  final String apiKey = "AIzaSyAiBqwqM8EwffLlkslJyLBjSkCWF8DpwDQ";

  @override
  void initState() {
    super.initState();
    _initAppData();
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      double delta = _scrollController.position.userScrollDirection == ScrollDirection.reverse ? 1.5 : -1.5;
      setState(() { _headerOffset = (_headerOffset + delta).clamp(0.0, _headerHeight); });
    });
  }

  Future<void> _initAppData() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 1,
      onCreate: (db, version) => db.execute('CREATE TABLE posts (id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT)'));
    
    List<Map> count = await db.rawQuery('SELECT COUNT(*) as total FROM posts');
    if (count[0]['total'] == 0) {
      await _fetchFromBlogger(db);
    } else {
      _loadFromLocal(db);
    }
  }

  Future<void> _fetchFromBlogger(Database db) async {
    setState(() => isPageLoading = true);
    try {
      final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=50";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final items = json.decode(res.body)['items'] as List;
        for (var item in items) {
          await db.insert('posts', {
            'id': item['id'], 'title': item['title'], 
            'content': item['content'], 'url': item['url']
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        _loadFromLocal(db);
      }
    } catch (e) { print(e); }
    setState(() => isPageLoading = false);
  }

  void _loadFromLocal(Database db) async {
    final maps = await db.query('posts');
    setState(() {
      // Ganti baris 145 yang error tadi dengan ini:
allArticles = maps.map((e) => Article(
  id: e['id'].toString(), 
  title: e['title'].toString(), 
  content: e['content'].toString(), 
  url: e['url'].toString()
)).toList();
      allArticles.shuffle(); 
    });
  }

  void _onSearchChanged(String q) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (q.isEmpty) { setState(() => searchSuggestions = []); return; }
      setState(() {
        searchSuggestions = allArticles.where((a) => a.title.toLowerCase().contains(q.toLowerCase())).take(5).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: selectedArticle != null ? 0 : (_headerHeight - _headerOffset)),
              child: selectedArticle != null 
                ? ArticleReader(
                    title: selectedArticle!.title, content: selectedArticle!.content,
                    url: selectedArticle!.url, onClose: () => setState(() => selectedArticle = null),
                    onLoadStart: () => setState(() => isPageLoading = true),
                    onLoadEnd: () => setState(() => isPageLoading = false))
                : _buildTabContent(),
            ),
            Positioned(
              top: -_headerOffset, left: 0, right: 0,
              child: Column(
                children: [
                  _buildYouTubeHeader(),
                  if (isPageLoading) const LinearProgressIndicator(color: Colors.red, minHeight: 2, backgroundColor: Colors.transparent),
                ],
              ),
            ),
          ],
        ),
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
          const Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
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
                onSubmitted: (v) => setState(() => _currentTab = 99),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(hintText: "Cari...", prefixIcon: Icon(Icons.search, size: 18), border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 12)),
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
        itemCount: searchSuggestions.length,
        itemBuilder: (c, i) => ListTile(
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text(searchSuggestions[i].title),
          onTap: () => setState(() { selectedArticle = searchSuggestions[i]; _searchController.clear(); }),
        ),
      );
    }
    if (_currentTab == 99) return _buildFullSearch();

    switch (_currentTab) {
      case 0: return _buildBeranda();
      case 1: return const Center(child: Text("Halaman Jelajah"));
      case 2: return const Center(child: Text("Halaman Koleksi"));
      case 3: return _buildSetelan();
      default: return _buildBeranda();
    }
  }

  Widget _buildBeranda() {
    if (allArticles.isEmpty) return const Center(child: CircularProgressIndicator(color: Colors.red));
    return ListView.builder(
      controller: _scrollController,
      itemCount: allArticles.length,
      itemBuilder: (context, index) {
        final a = allArticles[index];
        return InkWell(
          onTap: () => setState(() => selectedArticle = a),
          child: Column(
            children: [
              Container(width: double.infinity, height: 200, color: Colors.black12, child: const Icon(Icons.music_video, size: 80, color: Colors.red)),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.play_arrow, color: Colors.white)),
                title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Sinsangnot • Notasi Gending"),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullSearch() {
    final results = allArticles.where((a) => a.title.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (c, i) => ListTile(
        leading: const Icon(Icons.music_note, color: Colors.red),
        title: Text(results[i].title),
        onTap: () => setState(() => selectedArticle = results[i]),
      ),
    );
  }

  Widget _buildSetelan() {
    return ListView(
      children: [
        ListTile(leading: const Icon(Icons.info_outline), title: const Text("Tentang Sinsangnot"), onTap: () {}),
        ListTile(leading: const Icon(Icons.favorite, color: Colors.red), title: const Text("Donasi Kreator"), onTap: () {}),
      ],
    );
  }
}