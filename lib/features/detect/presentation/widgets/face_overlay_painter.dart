import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// FaceOverlayPainter — CustomPainter untuk overlay bounding box real-time
//
// Menerima koordinat dalam camera-image space, melakukan scaling ke canvas.
// Mendukung:
//   • Bounding box berwarna sesuai ekspresi (Happy=hijau, Angry=merah, dll)
//   • Chip label: "[Usia]th [Ekspresi] [Confidence]%"
//   • Opacity untuk animasi fade-in/out (dikelola parent via AnimationController)
//   • Mirroring horizontal untuk front camera
class FaceOverlayPainter extends CustomPainter {
  const FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
    required this.opacity,
  });

  final List<FaceDetectionResult> faces;
  final Size imageSize;

  final bool isFrontCamera;
  final double opacity;



  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty || opacity <= 0 || imageSize == Size.zero) return;

    for (final face in faces) {
      final scaledRect = _scaleRect(face.boundingBox, size);
      _drawBoundingBox(canvas, scaledRect, face.expression.boxColor);
      _drawChipLabel(canvas, scaledRect, face.chipLabel, face.expression.boxColor);
    }
  }



  /// Mencocokkan koordinat bounding box dari kamera ke layar.
  Rect _scaleRect(Rect bbox, Size canvasSize) {
    // Karena CustomPaint sekarang seukuran dengan CameraPreview (SizedBox),
    // kita hanya perlu melakukan mapping rasio secara langsung.
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;

    double left = bbox.left * scaleX;
    double top = bbox.top * scaleY;
    double right = bbox.right * scaleX;
    double bottom = bbox.bottom * scaleY;

    // Front camera: mirror horizontal agar sesuai cermin.
    if (isFrontCamera) {
      final mirroredLeft = canvasSize.width - right;
      final mirroredRight = canvasSize.width - left;
      left = mirroredLeft;
      right = mirroredRight;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }


  void _drawBoundingBox(Canvas canvas, Rect rect, Color color) {
    final borderPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    _drawCornerAccents(canvas, rect, color);
  }

  /// Gambar aksen sudut berbentuk "L" — efek HUD scanner
  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const len = 18.0;


    canvas.drawLine(rect.topLeft, rect.topLeft.translate(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, len), paint);
    canvas.drawLine(rect.topRight, rect.topRight.translate(-len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight.translate(0, len), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(len, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -len), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(-len, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(0, -len), paint);
  }


  void _drawChipLabel(Canvas canvas, Rect faceRect, String label, Color color) {
    const fontSize = 11.0;
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.black.withOpacity(opacity),
        letterSpacing: 0.3,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final chipWidth = tp.width + padding.horizontal;
    final chipHeight = tp.height + padding.vertical;

    double chipTop = faceRect.top - chipHeight - 6;
    if (chipTop < 4) chipTop = faceRect.top + 6;


    final chipLeft = faceRect.left.clamp(4.0, double.infinity);

    final chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight);

    final chipPaint = Paint()
      ..color = color.withOpacity(opacity * 0.92)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
      chipPaint,
    );

    tp.paint(
      canvas,
      Offset(chipLeft + padding.left, chipTop + padding.top),
    );
  }


  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.opacity != opacity ||
        oldDelegate.imageSize != imageSize;
  }
}
