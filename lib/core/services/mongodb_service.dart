import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'package:pcd_tubes/core/models/detection_session.dart';
import 'package:pcd_tubes/core/models/journal_entry.dart';

// MongoDbService — CRUD operations untuk MongoDB Atlas
//
// Collections:
//   • detection_logs  — ringkasan sesi deteksi wajah
//   • mood_journal    — entri mood journal user
//
// Semua method memiliki graceful fallback: return empty/null jika DB tidak
// terkoneksi. App tetap bisa berjalan tanpa database (mode offline).
//
// Konfigurasi:
//   Organisasi: oguri-cap → Project: pcd
//   Connection string via .env file
class MongoDbService {
  static Db? _db;

  /// Apakah sudah terhubung ke MongoDB
  static bool get isConnected => _db != null && _db!.isConnected;


  static Future<void>? _connectionFuture;

  /// Koneksi ke MongoDB Atlas. Graceful fallback jika gagal.
  static Future<void> connect() async {
    if (isConnected) return;
    if (_connectionFuture != null) {
      await _connectionFuture;
      return;
    }

    _connectionFuture = _connectInternal();
    await _connectionFuture;
    _connectionFuture = null;
  }

  static Future<void> _connectInternal() async {
    try {
      final uri = dotenv.env['MONGODB_URI'];
      if (uri == null || uri.isEmpty) {
        debugPrint('[MongoDbService] MONGODB_URI tidak ditemukan di .env');
        return;
      }

      _db = await Db.create(uri);
      await _db!.open();
      debugPrint('[MongoDbService] Connected to MongoDB Atlas');
    } catch (e) {
      debugPrint('[MongoDbService] Connection error: $e');
      _db = null;
    }
  }

  /// Tutup koneksi MongoDB
  static Future<void> disconnect() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      _db = null;
      debugPrint('[MongoDbService] Disconnected');
    }
  }


  static Future<DbCollection?> _collection(String name) async {
    if (!isConnected) {
      await connect();
    }
    if (!isConnected) return null;
    return _db!.collection(name);
  }

  static String get _logsCollection =>
      dotenv.env['MONGODB_COLLECTION_LOGS'] ?? 'detection_logs';

  static String get _journalCollection =>
      dotenv.env['MONGODB_COLLECTION_JOURNAL'] ?? 'mood_journal';


  /// Simpan ringkasan sesi deteksi ke collection detection_logs
  static Future<bool> logDetectionSession(DetectionSession session) async {
    try {
      final col = await _collection(_logsCollection);
      if (col == null) {
        debugPrint('[MongoDbService] DB not connected — skip log session');
        return false;
      }

      await col.insertOne(session.toMap());
      debugPrint('[MongoDbService] Session logged: ${session.durationSeconds}s');
      return true;
    } catch (e) {
      debugPrint('[MongoDbService] logDetectionSession error: $e');
      return false;
    }
  }

  /// Ambil histori sesi deteksi, sorted by date desc
  static Future<List<DetectionSession>> getDetectionHistory({
    int limit = 50,
  }) async {
    try {
      final col = await _collection(_logsCollection);
      if (col == null) return [];

      final docs = await col
          .find(where.sortBy('startTime', descending: true).limit(limit))
          .toList();

      return docs.map((doc) => DetectionSession.fromMap(doc)).toList();
    } catch (e) {
      debugPrint('[MongoDbService] getDetectionHistory error: $e');
      return [];
    }
  }

  /// Ambil statistik distribusi ekspresi aggregated dari semua sesi
  static Future<Map<String, int>> getExpressionStats() async {
    try {
      final col = await _collection(_logsCollection);
      if (col == null) return {};

      final docs = await col.find().toList();
      final stats = <String, int>{};

      for (final doc in docs) {
        final dist = doc['expressionDistribution'];
        if (dist is Map) {
          for (final entry in dist.entries) {
            final key = entry.key.toString();
            final value = (entry.value as num).toInt();
            stats[key] = (stats[key] ?? 0) + value;
          }
        }
      }

      return stats;
    } catch (e) {
      debugPrint('[MongoDbService] getExpressionStats error: $e');
      return {};
    }
  }


  /// Simpan entri mood journal baru
  static Future<bool> saveJournalEntry(JournalEntry entry) async {
    try {
      final col = await _collection(_journalCollection);
      if (col == null) {
        debugPrint('[MongoDbService] DB not connected — skip save journal');
        return false;
      }

      await col.insertOne(entry.toMap());
      debugPrint('[MongoDbService] Journal entry saved: ${entry.moodLabel}');
      return true;
    } catch (e) {
      debugPrint('[MongoDbService] saveJournalEntry error: $e');
      return false;
    }
  }

  /// Ambil semua entri journal, sorted by date desc
  static Future<List<JournalEntry>> getJournalEntries({
    int limit = 100,
  }) async {
    try {
      final col = await _collection(_journalCollection);
      if (col == null) return [];

      final docs = await col
          .find(where.sortBy('createdAt', descending: true).limit(limit))
          .toList();

      return docs.map((doc) => JournalEntry.fromMap(doc)).toList();
    } catch (e) {
      debugPrint('[MongoDbService] getJournalEntries error: $e');
      return [];
    }
  }

  /// Hapus entri journal berdasarkan ObjectId
  static Future<bool> deleteJournalEntry(String id) async {
    try {
      final col = await _collection(_journalCollection);
      if (col == null) return false;

      final objectId = ObjectId.fromHexString(id);
      await col.deleteOne(where.id(objectId));
      debugPrint('[MongoDbService] Journal entry deleted: $id');
      return true;
    } catch (e) {
      debugPrint('[MongoDbService] deleteJournalEntry error: $e');
      return false;
    }
  }
}
