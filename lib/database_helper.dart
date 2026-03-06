import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static Future<Database> getDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'puska.db'),
      version: 4, // Naikkan versi ke 4 agar tabel diperbarui
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT)"
        );
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 4) {
          // Jika user update dari versi lama, kita sesuaikan kolomnya
          db.execute("DROP TABLE IF EXISTS offline_posts");
          db.execute(
            "CREATE TABLE offline_posts(id TEXT PRIMARY KEY, title TEXT, content TEXT, url TEXT, label TEXT)"
          );
        }
      },
    );
  }
}