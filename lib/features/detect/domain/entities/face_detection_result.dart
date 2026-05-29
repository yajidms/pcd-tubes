import 'package:flutter/material.dart';

// ENUM: FaceExpression
// 7 kelas ekspresi sesuai FER-2013 standard.
// Deteksi via heuristics mesh 468-titik MediaPipe.
// NOTE: Untuk akurasi produksi, ganti dengan model TFLite klasifikasi custom.
enum FaceExpression {
  happy,
  sad,
  angry,
  surprised,
  fearful,
  disgusted,
  neutral,
}

extension FaceExpressionExtension on FaceExpression {
  /// Nama tampilan dalam Bahasa Indonesia
  String get displayName {
    switch (this) {
      case FaceExpression.happy:
        return 'Senang';
      case FaceExpression.sad:
        return 'Sedih';
      case FaceExpression.angry:
        return 'Marah';
      case FaceExpression.neutral:
        return 'Netral';
      case FaceExpression.surprised:
        return 'Terkejut';
      case FaceExpression.fearful:
        return 'Takut';
      case FaceExpression.disgusted:
        return 'Jijik';
    }
  }

  /// Emoji representasi ekspresi untuk Challenge Mode & Journal
  String get emoji {
    switch (this) {
      case FaceExpression.happy:
        return '😊';
      case FaceExpression.sad:
        return '😢';
      case FaceExpression.angry:
        return '😠';
      case FaceExpression.neutral:
        return '😐';
      case FaceExpression.surprised:
        return '😲';
      case FaceExpression.fearful:
        return '😨';
      case FaceExpression.disgusted:
        return '🤮';
    }
  }

  /// Warna bounding box overlay — sesuai spec Tim CAP:
  /// Hijau=Happy, Ungu=Sad, Merah=Angry, Biru=Neutral,
  /// Oranye=Surprised, Deep Purple=Fearful, Teal=Disgusted
  Color get boxColor {
    switch (this) {
      case FaceExpression.happy:
        return const Color(0xFF00E676);

      case FaceExpression.sad:
        return const Color(0xFFE040FB);

      case FaceExpression.angry:
        return const Color(0xFFFF1744);

      case FaceExpression.neutral:
        return const Color(0xFF2979FF);

      case FaceExpression.surprised:
        return const Color(0xFFFF9100);

      case FaceExpression.fearful:
        return const Color(0xFFB388FF);

      case FaceExpression.disgusted:
        return const Color(0xFF1DE9B6);

    }
  }
}

// ENTITY: FaceDetectionResult
// Immutable data class. Koordinat boundingBox dalam camera-image pixel space.
// Scaling ke screen space dilakukan oleh FaceOverlayPainter.
class FaceDetectionResult {
  const FaceDetectionResult({
    required this.boundingBox,
    required this.expression,
    required this.estimatedAge,
    required this.confidence,
  });

  /// Bounding box dalam koordinat pixel kamera (post-rotation)
  final Rect boundingBox;

  /// Ekspresi terdeteksi (landmark heuristics)
  final FaceExpression expression;

  /// Estimasi usia — heuristics berbasis rasio fitur wajah
  final int estimatedAge;

  /// Confidence score [0.0 – 1.0]
  final double confidence;

  /// Label teks untuk chip overlay: "23th Senang 87%"
  String get chipLabel {
    final pct = (confidence * 100).toStringAsFixed(0);
    return '${estimatedAge}th ${expression.displayName} $pct%';
  }

  @override
  String toString() =>
      'FaceDetectionResult(expr: ${expression.name}, age: $estimatedAge, conf: $confidence)';
}
