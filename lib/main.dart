import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;
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

class _RootNavigationState extends State<RootNavigation> with SingleTickerProviderStateMixin {
  int _currentTab = 0;
  Article? selectedArticle;
  bool isSplashing = true;
  
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
  final FocusNode _searchFocusNode = FocusNode();

  final String blogId = "1371452320359744712";
  final String apiKey = "AIzaSyAiBqwqM8EwffLlkslJyLBjSkCWF8DpwDQ";
  
  final List<String> gendingLabels = ["Tayub", "Ladrang", "Slendro", "Pelog", "Ketawang", "Ayak"];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => isSplashing = false);
    
    _fetchInitialFeed();
    _loadOfflineData();
    _fetchSitemap();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'puska.db'),
      version: 3,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, labels TEXT)"
        );
      },
    );
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && nextPageToken != null && _searchController.text.isEmpty && _currentTab == 0 && selectedArticle == null) {
        _fetchMoreFeed();
      }
    }
  }

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
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=8"; 
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<Article> fetched = _parseArticles(data['items']);
        fetched.shuffle(); 
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

  Future<void> _handleSearch(String q) async {
    if (q.isEmpty) return;
    
    setState(() {
      isSearching = true; 
      filteredSuggestions = []; 
      selectedArticle = null;
      _searchController.text = q;
      _searchFocusNode.unfocus();
    });

    // Perbaikan: Selalu cek hasil offline dulu
    List<Article> localResults = offlineArticles.where((a) => 
      a.title.toLowerCase().contains(q.toLowerCase())
    ).toList();

    try {
      String url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts/search?q=${Uri.encodeComponent(q)}&key=$apiKey";
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<Article> apiResults = _parseArticles(data['items']);
        
        // Gabungkan hasil online dengan offline jika ada yang unik
        for (var local in localResults) {
          if (!apiResults.any((api) => api.id == local.id)) {
            apiResults.add(local);
          }
        }

        setState(() {
          searchResults = apiResults;
          _currentTab = 0; 
        });
      } else {
        setState(() => searchResults = localResults);
      }
    } catch (e) {
      // Jika error (offline), tampilkan hasil lokal saja
      setState(() {
        searchResults = localResults;
        _currentTab = 0;
      });
    }
    setState(() => isSearching = false);
  }

  Future<void> _openFromSitemap(String url) async {
    setState(() { isSearching = true; filteredSuggestions = []; });
    try {
      final res = await http.get(Uri.parse("https://www.googleapis.com/blogger/v3/blogs/$blogId/posts/bypath?path=${Uri.parse(url).path}&key=$apiKey"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          selectedArticle = _parseArticles([data]).first;
          _searchController.clear();
          _searchFocusNode.unfocus();
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
    final db = await _getDatabase();
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
    _searchFocusNode.unfocus();
    setState(() {
      searchResults = [];
      filteredSuggestions = [];
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isSplashing) {
      return Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF0F0F0F) : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
                  );
                },
                child: Image.asset('assets/logo.png', height: 100, 
                  errorBuilder: (c, e, s) => const Icon(Icons.play_circle_fill, color: Colors.red, size: 100)),
              ),
              const SizedBox(height: 20),
              const Text("SinsangNot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -1)),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (selectedArticle != null) { 
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
        appBar: AppBar(
          title: _buildYouTubeHeader(),
          elevation: 0,
        ),
        body: Stack(
          children: [
            RefreshIndicator(
              color: Colors.red,
              onRefresh: _fetchInitialFeed, 
              child: selectedArticle != null 
                ? ArticleReader(
                    id: selectedArticle!.id, title: selectedArticle!.title,
                    content: selectedArticle!.content, url: selectedArticle!.url,
                    labels: selectedArticle!.labels,
                    isDarkMode: widget.isDarkMode,
                    onClose: () {
                      setState(() => selectedArticle = null);
                    },
                    onLoadStart: () => {}, 
                    onLoadEnd: () => {},
                  )
                : _buildTabContent(),
            ),
            // PERBAIKAN: Saran pencarian melayang agar keyboard tidak tertutup
            if (filteredSuggestions.isNotEmpty) 
              _buildFloatingSuggestions(),
          ],
        ),
        bottomNavigationBar: _buildYouTubeFooter(),
      ),
    );
  }

  Widget _buildYouTubeHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () { 
            _resetSearch(); 
            setState(() { _currentTab = 0; selectedArticle = null; }); 
          },
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
              focusNode: _searchFocusNode,
              onChanged: (val) {
                if (val.isEmpty) {
                  setState(() => filteredSuggestions = []);
                } else {
                  final List<Map<String, String>> temp = sitemapSuggestions
                      .where((s) => s['title']!.toLowerCase().contains(val.toLowerCase()))
                      .toList();
                  
                  temp.sort((a, b) {
                    bool aStarts = a['title']!.toLowerCase().startsWith(val.toLowerCase());
                    bool bStarts = b['title']!.toLowerCase().startsWith(val.toLowerCase());
                    if (aStarts && !bStarts) return -1;
                    if (!aStarts && bStarts) return 1;
                    return a['title']!.length.compareTo(b['title']!.length);
                  });

                  setState(() => filteredSuggestions = temp.take(5).toList());
                }
              },
              onSubmitted: (val) => _handleSearch(val),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Cari...",
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: _resetSearch) 
                  : null,
                border: InputBorder.none, 
                contentPadding: const EdgeInsets.only(bottom: 12)),
            ),
          ),
        ),
      ],
    );
  }

  // PERBAIKAN: Widget saran pencarian melayang (floating)
  Widget _buildFloatingSuggestions() {
    return Positioned(
      top: 0,
      left: 60, 
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: (widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white).withOpacity(0.95),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: filteredSuggestions.length,
            separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
            itemBuilder: (c, i) => ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.history, size: 18, color: Colors.red),
              title: Text(
                filteredSuggestions[i]['title']!, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)
              ),
              onTap: () => _openFromSitemap(filteredSuggestions[i]['url']!),
            ),
          ),
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
        if (i == 0) {
          _resetSearch();
          setState(() { _currentTab = 0; selectedArticle = null; });
        } else if (_currentTab != i) {
          _resetSearch();
          setState(() { _currentTab = i; selectedArticle = null; });
          if (i == 2) _loadOfflineData();
        }
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
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    if (isOffline && _currentTab == 0 && feedArticles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Maaf anda sedang offline. Silakan buka KOLEKSI untuk melihat notasi download.",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
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
      case 0: return _buildArticleList(searchResults.isNotEmpty || _searchController.text.isNotEmpty ? searchResults : feedArticles);
      case 1: return _buildJelajah();
      case 2: return _buildArticleList(offlineArticles, isOfflineTab: true);
      case 3: return _buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
  }

  Widget _buildArticleList(List<Article> list, {bool isOfflineTab = false}) {
    if (list.isEmpty) {
      return Center(child: Text(isOfflineTab ? "Belum ada koleksi." : "Hasil tidak ditemukan."));
    }
    return ListView.builder(
      controller: _currentTab == 0 ? _scrollController : null,
      itemCount: list.length + (isLoadingMore && _currentTab == 0 ? 1 : 0),
      itemBuilder: (c, i) {
        if (i == list.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.red)));
        final a = list[i];
        return Column(
          children: [
            InkWell(onTap: () => setState(() => selectedArticle = a), child: _getThumbnail(a.content)),
            ListTile(
              onTap: () => setState(() => selectedArticle = a),
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.music_note, color: Colors.white, size: 20)),
              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(isOfflineTab ? "Tersedia Offline" : "Sinsangnot • ${a.labels.isNotEmpty ? a.labels.first : 'Gending'}"),
              trailing: isOfflineTab 
                ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(a))
                : const Icon(Icons.more_vert, size: 18),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  void _confirmDelete(Article a) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Hapus Koleksi?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal")),
        TextButton(onPressed: () async {
          final db = await _getDatabase();
          await db.delete('offline_posts', where: 'id = ?', whereArgs: [a.id]);
          Navigator.pop(c); _loadOfflineData();
        }, child: const Text("Hapus", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Widget _getThumbnail(String content) {
    RegExp exp = RegExp(r"<svg[\s\S]*?<\/svg>");
    Iterable<RegExpMatch> matches = exp.allMatches(content);
    return Container(
      width: double.infinity, height: 200, color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
      child: matches.isNotEmpty 
        ? ClipRect(child: OverflowBox(alignment: Alignment.topCenter, maxHeight: 600, child: SvgPicture.string(matches.first.group(0)!, colorFilter: widget.isDarkMode ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null)))
        : const Icon(Icons.music_video, size: 50, color: Colors.red),
    );
  }

  Widget _buildJelajah() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kategori Gending", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20, runSpacing: 25,
            children: gendingLabels.map((l) {
              return InkWell(
                onTap: () => _handleSearch(l),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30, backgroundColor: Colors.red,
                      child: Text(l[0], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSetelan() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        SwitchListTile(
          title: const Text("Tema Gelap"), secondary: const Icon(Icons.dark_mode),
          value: widget.isDarkMode, onChanged: (v) => widget.updateTheme(v),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline), title: const Text("Tentang Sinsangnot"), 
          onTap: () => _showInternalPage("Tentang", "Sinsangnot adalah perpustakaan digital notasi gending Jawa berkualitas tinggi."),
        ),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined), title: const Text("Privacy Policy"), 
          onTap: () => _showInternalPage("Privacy", "Kami menjamin data koleksi offline Anda tersimpan aman secara lokal."),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined), title: const Text("Disclaimer"), 
          onTap: () => _showInternalPage("Disclaimer", "Seluruh notasi adalah hasil digitalisasi kreatif untuk tujuan pelestarian budaya."),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.favorite, color: Colors.red), 
          title: const Text("Donasi Kreator"), subtitle: const Text("Dukung pelestarian notasi Jawa"),
          onTap: () => launchUrl(Uri.parse("https://link.dana.id/qr/MASUKKAN_ID_DANA_KAMU")), 
        ),
      ],
    );
  }

  void _showInternalPage(String title, String content) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24), height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 15),
            Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Tutup", style: TextStyle(color: Colors.white))))
          ],
        ),
      ),
    );
  }
}