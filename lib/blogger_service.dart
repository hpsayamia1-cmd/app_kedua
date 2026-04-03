import 'package:http/http.dart' as http;
import 'package:xml/xml.dart'; 
import 'dart:io'; // Penting: Untuk mengecek koneksi internet asli

class BloggerService {
  // URL blog Mas agar langsung sinkron
  final String blogUrl = "https://playertayub.blogspot.com";

  // --- FUNGSI BARU: CEK KONEKSI OTOMATIS ---
  // Fungsi ini yang tadi menyebabkan error saat build karena belum ada
  Future<bool> checkConnection() async {
    try {
      // Mencoba memanggil google untuk cek jalur data internet yang aktif
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false; // Jika error atau timeout, dianggap offline
    }
  }

  // 1. FUNGSI AMBIL FEED (Mendukung Infinite Scroll & Full Content)
  Future<List<Map<String, dynamic>>> fetchFeed({int startIndex = 1, int maxResults = 8}) async {
    try {
      final url = "$blogUrl/feeds/posts/default?start-index=$startIndex&max-results=$maxResults";
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _parseAtomFeed(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 2. FUNGSI PENCARIAN ONLINE
  Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    try {
      final url = "$blogUrl/feeds/posts/default?q=${Uri.encodeComponent(query)}";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return _parseAtomFeed(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 3. FUNGSI PARSING DATA (Mengambil konten artikel lengkap)
  List<Map<String, dynamic>> _parseAtomFeed(String xmlBody) {
    final document = XmlDocument.parse(xmlBody);
    final List<Map<String, dynamic>> posts = [];

    for (var entry in document.findAllElements('entry')) {
      String title = entry.findElements('title').first.innerText;
      
      // Mengambil Label
      String label = "Gending"; 
      var categories = entry.findElements('category');
      if (categories.isNotEmpty) {
        label = categories.first.getAttribute('term') ?? "Gending";
      }

      // Mengambil URL Artikel
      String link = "";
      var links = entry.findElements('link');
      for (var l in links) {
        if (l.getAttribute('rel') == 'alternate') {
          link = l.getAttribute('href') ?? "";
        }
      }

      // Mengambil konten HTML penuh (untuk gambar & lirik)
      String content = "";
      var contentElements = entry.findElements('content');
      if (contentElements.isNotEmpty) {
        content = contentElements.first.innerText;
      }

      posts.add({
        'title': title,
        'label': label,
        'url': link,
        'content': content, 
      });
    }
    return posts;
  }

  // 4. FUNGSI AMBIL SITEMAP
  Future<http.Response> fetchSitemap() async {
    return await http.get(Uri.parse("$blogUrl/sitemap.xml"));
  }
}