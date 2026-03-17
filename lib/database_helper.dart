import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static Future<Database> getDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'puska.db'),
      version: 5, // Naikkan ke 5 untuk mendukung kolom imageUrl
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT, imageUrl TEXT)"
        );
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 5) {
          // Kita bersihkan tabel lama agar strukturnya fresh dengan kolom imageUrl
          db.execute("DROP TABLE IF EXISTS offline_posts");
          db.execute(
            "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT, imageUrl TEXT)"
          );
        }
      },
    );
  }
}