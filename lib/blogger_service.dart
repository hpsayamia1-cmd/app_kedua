import 'package:http/http.dart' as http;
import 'package:xml/xml.dart'; // Pastikan tambahkan 'xml' di pubspec.yaml

class BloggerService {
  // Kita tidak lagi butuh API Key di sini untuk keamanan GitHub
  final String blogUrl = "https://sinsangnot.blogspot.com";

  // 1. FUNGSI FEED BERANDA (TANPA API KEY)
  // Mengambil 8 postingan terbaru (Hanya Judul & Label agar enteng)
  Future<List<Map<String, dynamic>>> fetchInitialFeed() async {
    try {
      final response = await http
          .get(Uri.parse("$blogUrl/feeds/posts/default?max-results=8"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _parseAtomFeed(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 2. FUNGSI PENCARIAN ONLINE (RINGAN & AMAN)
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

  // 3. FUNGSI PARSING DATA (JUDUL & LABEL SAJA)
  // Ini yang membuat aplikasi Anda kembali 'enteng' seperti dulu
  List<Map<String, dynamic>> _parseAtomFeed(String xmlBody) {
    final document = XmlDocument.parse(xmlBody);
    final List<Map<String, dynamic>> posts = [];

    for (var entry in document.findAllElements('entry')) {
      // Ambil Judul Asli (Bukan Link)
      String title = entry.findElements('title').first.innerText;
      
      // Ambil Label Tunggal (Gong-1, Ladrang, dll)
      String label = "Gending"; // Default
      var categories = entry.findElements('category');
      if (categories.isNotEmpty) {
        label = categories.first.getAttribute('term') ?? "Gending";
      }

      // Ambil Link untuk keperluan download isi nantinya
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
        'content': "", // Kosongkan dulu agar Beranda tidak berat
      });
    }
    return posts;
  }

  // 4. FUNGSI AMBIL SITEMAP
  Future<http.Response> fetchSitemap() async {
    return await http.get(Uri.parse("$blogUrl/sitemap.xml"));
  }
}