import 'package:mongo_dart/mongo_dart.dart';

// DetectionSession — data class untuk menyimpan ringkasan sesi deteksi
//
// Satu sesi = dari kamera mulai stream hingga berhenti/app background.
// Disimpan ke MongoDB collection `detection_logs`.
class DetectionSession {
  DetectionSession({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.expressionDistribution,
    required this.averageAge,
    required this.totalFacesDetected,
    required this.dominantExpression,
  });

  final ObjectId? id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  /// Hitungan per ekspresi: {'happy': 42, 'sad': 12, ...}
  final Map<String, int> expressionDistribution;

  final double averageAge;
  final int totalFacesDetected;
  final String dominantExpression;

  /// Serialisasi ke Map untuk MongoDB insert
  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'expressionDistribution': expressionDistribution,
      'averageAge': averageAge,
      'totalFacesDetected': totalFacesDetected,
      'dominantExpression': dominantExpression,
    };
  }

  /// Deserialisasi dari Map MongoDB document
  factory DetectionSession.fromMap(Map<String, dynamic> map) {
    return DetectionSession(
      id: map['_id'] as ObjectId?,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      durationSeconds: (map['durationSeconds'] as num).toInt(),
      expressionDistribution:
          Map<String, int>.from(map['expressionDistribution'] as Map),
      averageAge: (map['averageAge'] as num).toDouble(),
      totalFacesDetected: (map['totalFacesDetected'] as num).toInt(),
      dominantExpression: map['dominantExpression'] as String,
    );
  }

  @override
  String toString() =>
      'DetectionSession(duration: ${durationSeconds}s, faces: $totalFacesDetected, dominant: $dominantExpression)';
}
