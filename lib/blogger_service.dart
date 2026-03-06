import 'package:http/http.dart' as http;
import 'package:xml/xml.dart'; 

class BloggerService {
  final String blogUrl = "https://sinsangnot.blogspot.com";

  // 1. FUNGSI AMBIL FEED (Mendukung Infinite Scroll / Pagination)
  // Sekarang menerima startIndex untuk mengambil artikel urutan berikutnya
  Future<List<Map<String, dynamic>>> fetchFeed({int startIndex = 1, int maxResults = 8}) async {
    try {
      // Parameter start-index adalah kunci agar scroll tanpa batas bekerja
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

  // Alias untuk fetchInitialFeed agar tidak error di bagian kode lain jika dipanggil
  Future<List<Map<String, dynamic>>> fetchInitialFeed() async {
    return fetchFeed(startIndex: 1, maxResults: 8);
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

  // 3. FUNGSI PARSING DATA
  List<Map<String, dynamic>> _parseAtomFeed(String xmlBody) {
    final document = XmlDocument.parse(xmlBody);
    final List<Map<String, dynamic>> posts = [];

    for (var entry in document.findAllElements('entry')) {
      String title = entry.findElements('title').first.innerText;
      
      String label = "Gending"; 
      var categories = entry.findElements('category');
      if (categories.isNotEmpty) {
        label = categories.first.getAttribute('term') ?? "Gending";
      }

      String link = "";
      var links = entry.findElements('link');
      for (var l in links) {
        if (l.getAttribute('rel') == 'alternate') {
          link = l.getAttribute('href') ?? "";
        }
      }

      posts.add({
        'title': title,
        'label': label,
        'url': link,
        'content': "", 
      });
    }
    return posts;
  }

  // 4. FUNGSI AMBIL SITEMAP
  Future<http.Response> fetchSitemap() async {
    return await http.get(Uri.parse("$blogUrl/sitemap.xml"));
  }
}