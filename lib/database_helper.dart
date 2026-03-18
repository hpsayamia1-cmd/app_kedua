import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static Future<Database> getDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'puska.db'),
      version: 6, 
      onCreate: (db, version) {
        // DI SINI: Harus sama lengkapnya dengan yang di onUpgrade
        return db.execute(
          "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT, imageUrl TEXT, localImagePath TEXT)"
        );
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 6) {
          // Reset tabel agar kolom localImagePath tersedia bagi user lama
          db.execute("DROP TABLE IF EXISTS offline_posts");
          db.execute(
            "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT, imageUrl TEXT, localImagePath TEXT)"
          );
        }
      },
    );
  }
}