import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml; // Tambahkan package xml di pubspec.yaml
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
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bool isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _updateTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      prefs.setBool('isDarkMode', isDark);
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
        appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black)
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark, 
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F0F0F), foregroundColor: Colors.white)
      ),
      home: RootNavigation(updateTheme: _updateTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}

class Article {
  final String id, title, content, url;
  final List<String> labels;
  Article({required this.id, required this.title, required this.content, required this.url, this.labels = const []});
}

class RootNavigation extends StatefulWidget {
  final Function(bool) updateTheme;
  final bool isDarkMode;
  RootNavigation({required this.updateTheme, required this.isDarkMode});

  @override
  _RootNavigationState createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentTab = 0;
  Article? selectedArticle;
  
  List<Article> feedArticles = [];
  List<Article> searchResults = [];
  List<Article> offlineArticles = [];
  List<Map<String, String>> sitemapSuggestions = [];
  List<Map<String, String>> filteredSuggestions = [];
  
  bool isLoadingMore = false;
  bool isInitialLoading = true;
  bool isSearching = false; 
  bool isOffline = false;
  String? nextPageToken;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final String blogId = "1371452320359744712";
  final String apiKey = "AIzaSyAiBqwqM8EwffLlkslJyLBjSkCWF8DpwDQ";
  final List<String> gendingLabels = ["Gong-1", "Gong-2", "Gong-3", "Gong-5", "Gong-6"];

  @override
  void initState() {
    super.initState();
    _fetchInitialFeed();
    _loadOfflineData();
    _fetchSitemap();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    // Memperbaiki deteksi scroll agar tidak macet di artikel 30
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && nextPageToken != null && _searchController.text.isEmpty && _currentTab == 0 && selectedArticle == null) {
        _fetchMoreFeed();
      }
    }
  }

  // --- LOGIKA DATA ---

  Future<void> _fetchSitemap() async {
    try {
      final res = await http.get(Uri.parse("https://sinsangnot.blogspot.com/sitemap.xml"));
      if (res.statusCode == 200) {
        final document = xml.XmlDocument.parse(res.body);
        final locs = document.findAllElements('loc');
        List<Map<String, String>> temp = [];
        for (var element in locs) {
          String url = element.innerText;
          if (url.contains(".html")) {
            String slug = url.split('/').last.replaceAll(".html", "");
            // LOGIKA REVISI: Hapus _ dan angka setelahnya, ganti - jadi spasi
            String cleanTitle = slug.split('_').first.replaceAll('-', ' ');
            temp.add({'title': cleanTitle, 'url': url});
          }
        }
        setState(() => sitemapSuggestions = temp);
      }
    } catch (e) { debugPrint("Sitemap error: $e"); }
  }

  Future<void> _fetchInitialFeed() async {
    setState(() { isInitialLoading = true; isOffline = false; });
    // Poin 8: Turunkan maxResults ke 8 agar enteng
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=8"; 
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<Article> fetched = _parseArticles(data['items']);
        setState(() {
          feedArticles = fetched;
          nextPageToken = data['nextPageToken'];
        });
      }
    } catch (e) { 
      setState(() => isOffline = true); 
    }
    setState(() => isInitialLoading = false);
  }

  Future<void> _fetchMoreFeed() async {
    if (nextPageToken == null) return;
    setState(() => isLoadingMore = true);
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=8&pageToken=$nextPageToken";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<Article> fetched = _parseArticles(data['items']);
        setState(() {
          feedArticles.addAll(fetched);
          nextPageToken = data['nextPageToken'];
        });
      } else {
        setState(() => nextPageToken = null);
      }
    } catch (e) { setState(() => nextPageToken = null); }
    setState(() => isLoadingMore = false);
  }

  Future<void> _handleSearch(String q, {String? label}) async {
    if (q.isEmpty && label == null) return;
    setState(() {
      isSearching = true; 
      filteredSuggestions = []; // Tutup rekomendasi
      selectedArticle = null;
    });

    try {
      // Poin 7: Gunakan query label yang lebih tepat
      String url = label != null 
          ? "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?q=label:\"$label\"&key=$apiKey"
          : "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts/search?q=${Uri.encodeComponent(q)}&key=$apiKey";
          
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => searchResults = _parseArticles(data['items']));
      } else {
        setState(() => searchResults = []);
      }
    } catch (e) {
      setState(() {
        searchResults = offlineArticles.where((a) {
          final matchTitle = a.title.toLowerCase().contains(q.toLowerCase());
          final matchLabel = label != null && a.labels.contains(label);
          return label != null ? matchLabel : matchTitle;
        }).toList();
      });
    }
    setState(() => isSearching = false);
  }

  // Fungsi untuk buka artikel dari sitemap (instan)
  Future<void> _openFromSitemap(String url) async {
    setState(() { isSearching = true; filteredSuggestions = []; });
    try {
      final res = await http.get(Uri.parse("https://www.googleapis.com/blogger/v3/blogs/$blogId/posts/bypath?path=${Uri.parse(url).path}&key=$apiKey"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          selectedArticle = _parseArticles([data]).first;
          _searchController.clear();
        });
      }
    } catch (e) { debugPrint("Direct open error: $e"); }
    setState(() => isSearching = false);
  }

  List<Article> _parseArticles(dynamic items) {
    if (items == null) return [];
    return List<Article>.from(items.map((i) => Article(
      id: i['id'], title: i['title'], content: i['content'] ?? "", url: i['url'],
      labels: List<String>.from(i['labels'] ?? [])
    )));
  }

  Future<void> _loadOfflineData() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(p.join(dbPath, 'puska.db'), version: 3);
    final List<Map<String, dynamic>> maps = await db.query('offline_posts');
    setState(() {
      offlineArticles = maps.map((e) => Article(
        id: e['id'].toString(), title: e['title'].toString(),
        content: e['content'].toString(), url: e['url'].toString(),
        labels: List<String>.from(json.decode(e['labels']?.toString() ?? "[]"))
      )).toList();
    });
  }

  void _resetSearch() {
    _searchController.clear();
    setState(() {
      searchResults = [];
      filteredSuggestions = [];
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedArticle != null) { 
          _resetSearch(); // Poin 1 & 11: Pastikan bersih saat back
          setState(() => selectedArticle = null); 
          return false; 
        }
        if (_searchController.text.isNotEmpty) {
          _resetSearch();
          return false;
        }
        if (_currentTab != 0) {
          setState(() => _currentTab = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        // Poin 3: Hapus NestedScrollView agar tidak lag
        appBar: AppBar(
          title: _buildYouTubeHeader(),
          elevation: 0,
          bottom: filteredSuggestions.isNotEmpty 
            ? PreferredSize(
                preferredSize: const Size.fromHeight(200),
                child: _buildSitemapSuggestions(),
              ) 
            : null,
        ),
        body: RefreshIndicator(
          color: Colors.red,
          onRefresh: _fetchInitialFeed, 
          child: selectedArticle != null 
            ? ArticleReader(
                id: selectedArticle!.id, title: selectedArticle!.title,
                content: selectedArticle!.content, url: selectedArticle!.url,
                labels: selectedArticle!.labels,
                onClose: () {
                  _resetSearch(); // Bersihkan saat tutup lewat tombol close
                  setState(() => selectedArticle = null);
                },
                onLoadStart: () => {}, 
                onLoadEnd: () => {},
              )
            : _buildTabContent(),
        ),
        bottomNavigationBar: _buildYouTubeFooter(),
      ),
    );
  }

  Widget _buildYouTubeHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () { _resetSearch(); setState(() { _currentTab = 0; selectedArticle = null; }); },
          child: Image.asset('assets/logo.png', height: 28, 
            errorBuilder: (c, e, s) => const Icon(Icons.play_circle_fill, color: Colors.red)),
        ),
        const SizedBox(width: 4),
        const Text("SinsangNot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -1)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
              borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  if (val.isEmpty) {
                    filteredSuggestions = [];
                  } else {
                    filteredSuggestions = sitemapSuggestions
                        .where((s) => s['title']!.toLowerCase().contains(val.toLowerCase()))
                        .take(5).toList();
                  }
                });
              },
              onSubmitted: (val) => _handleSearch(val),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Cari...",
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), 
                      onPressed: _resetSearch) 
                  : null,
                border: InputBorder.none, 
                contentPadding: const EdgeInsets.only(bottom: 12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSitemapSuggestions() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: filteredSuggestions.length,
        itemBuilder: (c, i) => ListTile(
          dense: true, // Poin 14: Kecil aja
          leading: const Icon(Icons.history, size: 18),
          title: Text(filteredSuggestions[i]['title']!, style: const TextStyle(fontSize: 13)),
          onTap: () => _openFromSitemap(filteredSuggestions[i]['url']!),
        ),
      ),
    );
  }

  Widget _buildYouTubeFooter() {
    return BottomNavigationBar(
      currentIndex: _currentTab,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: widget.isDarkMode ? Colors.white : Colors.black,
      unselectedItemColor: Colors.grey,
      onTap: (i) {
        // Poin 2: Klik menu bawah otomatis tutup artikel & bersih-bersih
        _resetSearch();
        setState(() {
          _currentTab = i;
          selectedArticle = null;
        });
        if (i == 2) _loadOfflineData();
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
        BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Jelajah'),
        BottomNavigationBarItem(icon: Icon(Icons.download_done), label: 'Koleksi'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'), 
      ],
    );
  }

  Widget _buildTabContent() {
    if (isInitialLoading || isSearching) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(50),
        child: CircularProgressIndicator(color: Colors.red),
      ));
    }
    
    // Poin 8: Handling Offline
    if (isOffline && _currentTab == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "Maaf anda sedang offline. Silakan periksa koneksi internet anda atau buka KOLEKSI untuk melihat notasi yang anda download",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => setState(() => _currentTab = 2),
                child: const Text("Buka Koleksi", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    switch (_currentTab) {
      case 0: 
        final list = _searchController.text.isNotEmpty ? searchResults : feedArticles;
        return _buildArticleList(list);
      case 1: return _buildJelajah();
      case 2: return _buildArticleList(offlineArticles, isOfflineTab: true);
      case 3: return _buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
  }

  Widget _buildArticleList(List<Article> list, {bool isOfflineTab = false}) {
    if (list.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(isOfflineTab ? Icons.cloud_off : Icons.search_off, size: 60, color: Colors.grey),
                const SizedBox(height: 10),
                Text(
                  isOfflineTab 
                    ? "Belum ada koleksi tersimpan." 
                    : "Tidak ditemukan hasil.",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _currentTab == 0 ? _scrollController : null,
      padding: EdgeInsets.zero,
      itemCount: list.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (c, i) {
        if (i == list.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.red)));
        final a = list[i];
        return Column(
          children: [
            InkWell(
              onTap: () => setState(() => selectedArticle = a),
              child: _getThumbnail(a.content),
            ),
            ListTile(
              onTap: () => setState(() => selectedArticle = a),
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.music_note, color: Colors.white, size: 20)),
              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(isOfflineTab ? "Tersedia Offline" : "Sinsangnot • ${a.labels.isNotEmpty ? a.labels.first : 'Gending'}"),
              trailing: isOfflineTab 
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _confirmDelete(a), // Poin 9: Hapus koleksi
                  )
                : const Icon(Icons.more_vert, size: 18),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // Fungsi konfirmasi hapus
  void _confirmDelete(Article a) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Hapus Koleksi?"),
        content: Text("Hapus '${a.title}' dari penyimpanan offline?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              final dbPath = await getDatabasesPath();
              final db = await openDatabase(p.join(dbPath, 'puska.db'));
              await db.delete('offline_posts', where: 'id = ?', whereArgs: [a.id]);
              Navigator.pop(c);
              _loadOfflineData();
            }, 
            child: const Text("Hapus", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  Widget _getThumbnail(String content) {
    RegExp exp = RegExp(r"<svg[\s\S]*?<\/svg>");
    Iterable<RegExpMatch> matches = exp.allMatches(content);
    return Container(
      width: double.infinity, height: 200,
      color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
      child: matches.isNotEmpty 
        ? ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter, maxHeight: 600,
              child: SvgPicture.string(matches.first.group(0)!, 
                width: MediaQuery.of(context).size.width,
                colorFilter: widget.isDarkMode ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null,
              ),
            ),
          )
        : const Icon(Icons.music_video, size: 50, color: Colors.red),
    );
  }

  // --- UI LAINNYA ---
  Widget _buildJelajah() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kategori Gending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: gendingLabels.map((label) => InkWell(
                onTap: () => _handleSearch("", label: label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetelan() {
    return ListView(
      children: [
        SwitchListTile(
          title: const Text("Tema Gelap"),
          value: widget.isDarkMode,
          onChanged: (v) => widget.updateTheme(v),
        ),
        // ... (sisanya tetap sama)
      ],
    );
  }

  void _showInternalPage(String title, String content) { /* Tetap sama seperti kodemu */ }
}