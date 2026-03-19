import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static Future<Database> getDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'puska.db'),
      version: 7, // Naikkan ke versi 7 untuk mendukung tabel Catatan
      onCreate: (db, version) async {
        // Buat tabel Koleksi Offline
        await db.execute(
          "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT, imageUrl TEXT, localImagePath TEXT)"
        );
        // Buat tabel Catatan (Notes)
        await db.execute(
          "CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, date TEXT)"
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 6) {
          await db.execute("DROP TABLE IF EXISTS offline_posts");
          await db.execute(
            "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT, imageUrl TEXT, localImagePath TEXT)"
          );
        }
        
        // JIKA VERSI NAIK KE 7: Tambahkan tabel notes tanpa menghapus data yang lama
        if (oldVersion < 7) {
          await db.execute(
            "CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, date TEXT)"
          );
        }
      },
    );
  }
}