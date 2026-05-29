import 'package:mongo_dart/mongo_dart.dart';

// JournalEntry — data class untuk entri mood journal
//
// User bisa menambah catatan mood secara manual atau auto-suggest dari
// ekspresi terakhir yang terdeteksi. Disimpan ke MongoDB collection
// `mood_journal`.
class JournalEntry {
  JournalEntry({
    this.id,
    required this.mood,
    required this.moodLabel,
    required this.note,
    required this.createdAt,
    this.suggestedFromDetection = false,
  });

  final ObjectId? id;

  /// Emoji mood: '😊', '😢', '😠', dll
  final String mood;

  /// Label mood dalam Bahasa Indonesia: 'Senang', 'Sedih', dll
  final String moodLabel;

  /// Catatan teks dari user
  final String note;

  final DateTime createdAt;

  /// Apakah mood ini di-suggest dari hasil deteksi terakhir
  final bool suggestedFromDetection;

  /// Serialisasi ke Map untuk MongoDB insert
  Map<String, dynamic> toMap() {
    return {
      'mood': mood,
      'moodLabel': moodLabel,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'suggestedFromDetection': suggestedFromDetection,
    };
  }

  /// Deserialisasi dari Map MongoDB document
  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['_id'] as ObjectId?,
      mood: map['mood'] as String,
      moodLabel: map['moodLabel'] as String,
      note: map['note'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      suggestedFromDetection: map['suggestedFromDetection'] as bool? ?? false,
    );
  }

  /// Copy-with untuk update
  JournalEntry copyWith({
    ObjectId? id,
    String? mood,
    String? moodLabel,
    String? note,
    DateTime? createdAt,
    bool? suggestedFromDetection,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      mood: mood ?? this.mood,
      moodLabel: moodLabel ?? this.moodLabel,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      suggestedFromDetection:
          suggestedFromDetection ?? this.suggestedFromDetection,
    );
  }

  @override
  String toString() =>
      'JournalEntry(mood: $mood, label: $moodLabel, date: $createdAt)';
}
