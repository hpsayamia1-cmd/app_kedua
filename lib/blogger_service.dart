import 'package:http/http.dart' as http;
import 'package:xml/xml.dart'; 

class BloggerService {
  // Saya sesuaikan ke URL blog baru Mas agar langsung sinkron
  final String blogUrl = "https://playertayub.blogspot.com";

  // 1. FUNGSI AMBIL FEED (Mendukung Infinite Scroll & Full Content)
  Future<List<Map<String, dynamic>>> fetchFeed({int startIndex = 1, int maxResults = 8}) async {
    try {
      // Menambahkan alt=json atau menggunakan atom feed default 
      // Kita tetap gunakan default tapi pastikan konten ditarik
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

  // 3. FUNGSI PARSING DATA (PENTING: Sekarang mengambil konten artikel)
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

      // KUNCI UTAMA: Mengambil konten HTML penuh untuk diekstrak gambarnya
      String content = "";
      var contentElements = entry.findElements('content');
      if (contentElements.isNotEmpty) {
        content = contentElements.first.innerText;
      }

      posts.add({
        'title': title,
        'label': label,
        'url': link,
        'content': content, // Sekarang konten berisi HTML (WebP + Lirik)
      });
    }
    return posts;
  }

  // 4. FUNGSI AMBIL SITEMAP
  Future<http.Response> fetchSitemap() async {
    return await http.get(Uri.parse("$blogUrl/sitemap.xml"));
  }
}