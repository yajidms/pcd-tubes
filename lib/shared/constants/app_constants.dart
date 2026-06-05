import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// AppConstants — Konfigurasi & threshold untuk seluruh aplikasi
class AppConstants {
  AppConstants._();

  static const double faceConfidenceThreshold = 0.7;
  static const int maxFaces = 5;
  static const int frameSkip = 2;

  static const int memoryBufferMax = 3;

  static const double holdDurationChallenge = 3.0;

  static const double challengeConfidenceThreshold = 0.65;
  static const int challengeRounds = 5;

  static const int minSessionDurationSeconds = 3;
  static const int maxSessionDurationMinutes = 30;

  static const int mongoDbTimeoutSeconds = 10;
  static const int maxDetectionHistoryLimit = 50;
  static const int maxJournalEntriesLimit = 100;

  static const List<FaceExpression> allExpressions = FaceExpression.values;

  static const Map<FaceExpression, String> expressionLabels = {
    FaceExpression.happy: 'Senang',
    FaceExpression.sad: 'Sedih',
    FaceExpression.angry: 'Marah',
    FaceExpression.surprised: 'Terkejut',
    FaceExpression.fearful: 'Takut',
    FaceExpression.disgusted: 'Jijik',
    FaceExpression.neutral: 'Netral',
  };
}
