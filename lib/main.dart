import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  
  bool isLoadingMore = false;
  bool isInitialLoading = true;
  bool isSearching = false; 
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
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500) {
      if (!isLoadingMore && nextPageToken != null && _searchController.text.isEmpty && _currentTab == 0 && selectedArticle == null) {
        _fetchMoreFeed();
      }
    }
  }

  // --- LOGIKA DATA ---

  Future<void> _fetchInitialFeed() async {
    setState(() => isInitialLoading = true);
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=15"; // Ambil lebih banyak untuk shuffle
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<Article> fetched = _parseArticles(data['items']);
        fetched.shuffle(); // Acak Konten
        setState(() {
          feedArticles = fetched;
          nextPageToken = data['nextPageToken'];
        });
      }
    } catch (e) { debugPrint("Error: $e"); }
    setState(() => isInitialLoading = false);
  }

  Future<void> _fetchMoreFeed() async {
    setState(() => isLoadingMore = true);
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=10&pageToken=$nextPageToken";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List<Article> fetched = _parseArticles(data['items']);
        fetched.shuffle(); // Acak data baru yang masuk
        setState(() {
          feedArticles.addAll(fetched);
          nextPageToken = data['nextPageToken'];
        });
      }
    } catch (e) { nextPageToken = null; }
    setState(() => isLoadingMore = false);
  }

  Future<void> _handleSearch(String q, {String? label}) async {
    setState(() {
      isSearching = true; 
      _currentTab = 0;
      selectedArticle = null;
    });

    try {
      String url = label != null 
          ? "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?labels=${Uri.encodeComponent(label)}&key=$apiKey"
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

  List<Article> _parseArticles(dynamic items) {
    if (items == null) return [];
    return List<Article>.from(items.map((i) => Article(
      id: i['id'], title: i['title'], content: i['content'], url: i['url'],
      labels: List<String>.from(i['labels'] ?? [])
    )));
  }

  Future<void> _loadOfflineData() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dbPath, 'puska.db'), 
      version: 3,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 3) await db.execute("ALTER TABLE offline_posts ADD COLUMN labels TEXT");
      }
    );
    final List<Map<String, dynamic>> maps = await db.query('offline_posts');
    setState(() {
      offlineArticles = maps.map((e) => Article(
        id: e['id'].toString(), title: e['title'].toString(),
        content: e['content'].toString(), url: e['url'].toString(),
        labels: List<String>.from(json.decode(e['labels']?.toString() ?? "[]"))
      )).toList();
    });
  }

  void _showInternalPage(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 15),
            Expanded(child: SingleChildScrollView(child: Text(content, style: const TextStyle(fontSize: 16, height: 1.5)))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context),
                child: const Text("Tutup", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _getThumbnail(String content) {
    RegExp exp = RegExp(r"<svg[\s\S]*?<\/svg>");
    Iterable<RegExpMatch> matches = exp.allMatches(content);
    
    return Container(
      width: double.infinity,
      height: 200,
      color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
      child: matches.isNotEmpty 
        ? ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: 600,
              child: SvgPicture.string(
                matches.first.group(0)!, 
                width: MediaQuery.of(context).size.width,
                colorFilter: widget.isDarkMode ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null,
              ),
            ),
          )
        : const Icon(Icons.music_video, size: 50, color: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (selectedArticle != null) { 
          setState(() => selectedArticle = null); 
          return false; 
        }
        if (_searchController.text.isNotEmpty) {
          _searchController.clear();
          _fetchInitialFeed();
          return false;
        }
        if (_currentTab != 0) {
          setState(() => _currentTab = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (c, inner) => [
              SliverAppBar(
                floating: true, 
                snap: true, 
                pinned: false,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: _buildYouTubeHeader(),
                elevation: 0,
              )
            ],
            body: RefreshIndicator(
              color: Colors.red,
              onRefresh: _fetchInitialFeed, // Tarik ke atas untuk acak & refresh
              child: selectedArticle != null 
                ? ArticleReader(
                    id: selectedArticle!.id, title: selectedArticle!.title,
                    content: selectedArticle!.content, url: selectedArticle!.url,
                    labels: selectedArticle!.labels,
                    onClose: () => setState(() => selectedArticle = null),
                    onLoadStart: () => {}, 
                    onLoadEnd: () => {},
                  )
                : _buildTabContent(),
            ),
          ),
        ),
        bottomNavigationBar: _buildYouTubeFooter(),
      ),
    );
  }

  Widget _buildYouTubeHeader() {
    return Row(
      children: [
        Image.asset('assets/logo.png', height: 28, 
          errorBuilder: (c, e, s) => const Icon(Icons.play_circle_fill, color: Colors.red)),
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
              onSubmitted: (val) => _handleSearch(val),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Cari...",
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear, size: 16), 
                      onPressed: () { _searchController.clear(); _fetchInitialFeed(); }) 
                  : null,
                border: InputBorder.none, 
                contentPadding: const EdgeInsets.only(bottom: 12)),
            ),
          ),
        ),
      ],
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
          // Jika sudah di tab beranda, scroll ke atas & acak ulang
          if (_currentTab == 0) {
             _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
             _fetchInitialFeed(); 
          }
          _searchController.clear(); 
          selectedArticle = null; 
        }
        setState(() => _currentTab = i);
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
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    
    switch (_currentTab) {
      case 0: 
        final list = _searchController.text.isNotEmpty ? searchResults : feedArticles;
        return _buildArticleList(list);
      case 1: return _buildJelajah();
      case 2: return _buildArticleList(offlineArticles, isOffline: true);
      case 3: return _buildSetelan();
      default: return _buildArticleList(feedArticles);
    }
  }

  Widget _buildArticleList(List<Article> list, {bool isOffline = false}) {
    if (list.isEmpty) {
      return ListView( // Gunakan ListView agar Pull-to-refresh tetap jalan saat kosong
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              children: [
                Icon(isOffline ? Icons.cloud_off : Icons.search_off, size: 60, color: Colors.grey),
                const SizedBox(height: 10),
                Text(
                  isOffline 
                    ? "Kosong (Belum terdownload)\nKlik ikon download di artikel untuk menyimpan." 
                    : "Tidak ditemukan hasil.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(), // Wajib ada agar Pull to Refresh aktif
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
              subtitle: Text(isOffline ? "Tersedia Offline" : "Sinsangnot • ${a.labels.isNotEmpty ? a.labels.first : 'Gending'}"),
              trailing: const Icon(Icons.more_vert, size: 18),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

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
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text("Pengaturan & Informasi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        SwitchListTile(
          title: const Text("Tema Gelap"),
          subtitle: const Text("Sesuaikan kenyamanan mata"),
          secondary: const Icon(Icons.dark_mode),
          value: widget.isDarkMode,
          onChanged: (v) => widget.updateTheme(v),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline), 
          title: const Text("Tentang Sinsangnot"), 
          onTap: () => _showInternalPage("Tentang Sinsangnot", 
            "Sinsangnot adalah perpustakaan digital notasi gending Jawa. Aplikasi ini dikembangkan untuk memudahkan pengrawit dan pecinta budaya mengakses notasi berkualitas tinggi (SVG) secara instan dan offline."),
        ),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined), 
          title: const Text("Privacy Policy"), 
          onTap: () => _showInternalPage("Privacy Policy", 
            "Kami menghargai privasi Anda. Aplikasi Sinsangnot tidak mengambil data pribadi pengguna. Data koleksi offline disimpan secara lokal di perangkat Anda."),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined), 
          title: const Text("Disclaimer"), 
          onTap: () => _showInternalPage("Disclaimer", 
            "Seluruh isi notasi dalam aplikasi ini adalah hasil digitalisasi kreatif. Penggunaan untuk tujuan komersial harus seizin pemilik konten."),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.favorite_border, color: Colors.red), 
          title: const Text("Donasi Kreator"), 
          subtitle: const Text("Dukung pelestarian notasi digital"),
          onTap: () => launchUrl(Uri.parse("https://link.dana.id/qr/MASUKKAN_ID_DANA")), 
        ),
      ],
    );
  }
}