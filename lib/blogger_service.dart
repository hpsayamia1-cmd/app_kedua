import 'package:http/http.dart' as http;
import 'dart:convert';

class BloggerService {
  final String blogId = "1371452320359744712";
  final String apiKey = "AIzaSyAiBqwqM8EwffLlkslJyLBjSkCWF8DpwDQ";

  // Fungsi untuk mengambil feed beranda
  Future<http.Response> fetchInitialFeed() async {
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts?key=$apiKey&maxResults=8";
    return await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
  }

  // Fungsi untuk pencarian online
  Future<http.Response> searchPosts(String query) async {
    final url = "https://www.googleapis.com/blogger/v3/blogs/$blogId/posts/search?q=${Uri.encodeComponent(query)}&key=$apiKey";
    return await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
  }
  
  // Fungsi untuk ambil sitemap
  Future<http.Response> fetchSitemap() async {
    return await http.get(Uri.parse("https://sinsangnot.blogspot.com/sitemap.xml"));
  }
}