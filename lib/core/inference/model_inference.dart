import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Rect;

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

class FaceDetectorService {
  FaceDetector? _detector;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;


  Future<void> initialize() async {
    try {
      _detector = await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
        performanceConfig: PerformanceConfig.auto(),
      );
      _isInitialized = true;
      debugPrint('[FaceDetectorService] Initialized — BlazeFace frontCamera');
    } catch (e) {
      debugPrint('[FaceDetectorService] Init error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    _isInitialized = false;
    try {
      await _detector?.dispose();
    } catch (e) {
      debugPrint('[FaceDetectorService] Dispose error: $e');
    }
    _detector = null;
    debugPrint('[FaceDetectorService] Disposed');
  }


  Future<List<FaceDetectionResult>> detectFromCameraImage(
    CameraImage image, {
    CameraFrameRotation rotation = CameraFrameRotation.cw90,
  }) async {
    if (!_isInitialized || _detector == null) return [];

    try {
      final faces = await _detector!.detectFacesFromCameraImage(
        image,
        rotation: rotation,
        mode: FaceDetectionMode.standard,
        maxDim: 480,

      );

      return faces
          .map((face) => _convertFace(face))
          .whereType<FaceDetectionResult>()
          .toList();
    } catch (e) {
      debugPrint('[FaceDetectorService] Detection error: $e');
      return [];
    }
  }


  FaceDetectionResult? _convertFace(Face face) {
    try {
      final bb = face.boundingBox;
      final rect = Rect.fromLTRB(
        bb.topLeft.x.toDouble(),
        bb.topLeft.y.toDouble(),
        bb.bottomRight.x.toDouble(),
        bb.bottomRight.y.toDouble(),
      );

      final mesh = face.mesh;
      FaceExpression expression = FaceExpression.neutral;
      double confidence = 0.70;

      if (mesh != null && mesh.length >= 468) {
        final result = _classifyExpression(mesh);
        expression = result.expression;
        confidence = result.confidence;
      }

      final age = _estimateAge(face);

      return FaceDetectionResult(
        boundingBox: rect,
        expression: expression,
        estimatedAge: age,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('[FaceDetectorService] Face convert error: $e');
      return null;
    }
  }


  _Pt _safePoint(FaceMesh mesh, int index) {
    if (index < mesh.length) {
      final p = mesh[index];
      return _Pt(p.x.toDouble(), p.y.toDouble());
    }
    return const _Pt(0, 0);
  }


  ({FaceExpression expression, double confidence}) _classifyExpression(
    FaceMesh mesh,
  ) {
    try {
      final upperLip = _safePoint(mesh, 13);
      final lowerLip = _safePoint(mesh, 14);
      final leftCorner = _safePoint(mesh, 61);
      final rightCorner = _safePoint(mesh, 291);
      final leftEyeTop = _safePoint(mesh, 159);
      final leftEyeBot = _safePoint(mesh, 145);
      final rightEyeTop = _safePoint(mesh, 386);
      final rightEyeBot = _safePoint(mesh, 374);
      final leftBrowOuter = _safePoint(mesh, 105);
      final leftBrowInner = _safePoint(mesh, 70);
      final rightBrowInner = _safePoint(mesh, 336);
      final leftEyeInner = _safePoint(mesh, 33);
      final rightEyeInner = _safePoint(mesh, 263);
      final noseTip = _safePoint(mesh, 4);
      final lowerLipBottom = _safePoint(mesh, 17);

      final mouthW = (rightCorner.x - leftCorner.x).abs();
      if (mouthW < 1) {
        return (expression: FaceExpression.neutral, confidence: 0.65);
      }


      final mouthH = (lowerLip.y - upperLip.y).abs();
      final mar = mouthH / mouthW;

      final lipCenterY = (upperLip.y + lowerLip.y) / 2;
      final cornerAvgY = (leftCorner.y + rightCorner.y) / 2;
      final smileRatio = (lipCenterY - cornerAvgY) / mouthW;

      final leftEAR = (leftEyeBot.y - leftEyeTop.y).abs() / mouthW;
      final rightEAR = (rightEyeBot.y - rightEyeTop.y).abs() / mouthW;
      final avgEAR = (leftEAR + rightEAR) / 2;

      final browEyeGap = (leftEyeInner.y - leftBrowOuter.y).abs();
      final browRatio = browEyeGap / mouthW;

      final innerBrowAvgY = (leftBrowInner.y + rightBrowInner.y) / 2;
      final eyeInnerAvgY = (leftEyeInner.y + rightEyeInner.y) / 2;
      final innerBrowRaise = (eyeInnerAvgY - innerBrowAvgY).abs() / mouthW;

      final noseToLip = (lowerLipBottom.y - noseTip.y).abs() / mouthW;

      final leftCornerRelY = (leftCorner.y - lipCenterY).abs();
      final rightCornerRelY = (rightCorner.y - lipCenterY).abs();
      final mouthAsymmetry =
          (leftCornerRelY - rightCornerRelY).abs() / mouthW;

      final outerMouthH = (lowerLipBottom.y - upperLip.y).abs();
      final outerMAR = outerMouthH / mouthW;


      final scores = <FaceExpression, double>{};

      if (mar > 0.28 && avgEAR > 0.22) {
        scores[FaceExpression.surprised] =
            (mar / 0.4).clamp(0.0, 1.0) * 0.5 +
                (avgEAR / 0.3).clamp(0.0, 1.0) * 0.5;
      }

      if (smileRatio > 0.04) {
        scores[FaceExpression.happy] =
            (smileRatio / 0.12).clamp(0.0, 1.0);
      }

      if (browRatio < 0.24) {
        scores[FaceExpression.angry] =
            ((0.24 - browRatio) / 0.12).clamp(0.0, 1.0);
      }

      if (smileRatio < -0.02 && innerBrowRaise > 0.20) {
        scores[FaceExpression.sad] =
            ((-smileRatio) / 0.08).clamp(0.0, 1.0) * 0.6 +
                (innerBrowRaise / 0.30).clamp(0.0, 1.0) * 0.4;
      } else if (smileRatio < -0.03) {
        scores[FaceExpression.sad] =
            ((-smileRatio) / 0.10).clamp(0.0, 1.0) * 0.7;
      }

      if (avgEAR > 0.20 && mar > 0.12 && mar <= 0.28 && innerBrowRaise > 0.18) {
        scores[FaceExpression.fearful] =
            (avgEAR / 0.28).clamp(0.0, 1.0) * 0.4 +
                (mar / 0.25).clamp(0.0, 1.0) * 0.3 +
                (innerBrowRaise / 0.28).clamp(0.0, 1.0) * 0.3;
      }

      if (noseToLip < 0.55 && (mouthAsymmetry > 0.04 || outerMAR > 0.25)) {
        scores[FaceExpression.disgusted] =
            ((0.60 - noseToLip) / 0.20).clamp(0.0, 1.0) * 0.5 +
                (mouthAsymmetry / 0.08).clamp(0.0, 1.0) * 0.3 +
                (outerMAR > 0.25 ? 0.2 : 0.0);
      }


      if (scores.isEmpty) {
        return (expression: FaceExpression.neutral, confidence: 0.72);
      }

      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final winner = sorted.first;
      final runnerUpScore =
          sorted.length > 1 ? sorted[1].value : 0.0;

      final margin = winner.value - runnerUpScore;
      final rawConfidence = 0.60 + margin * 0.35;
      final normalizedConfidence = rawConfidence.clamp(0.55, 0.95);

      return (
        expression: winner.key,
        confidence: normalizedConfidence,
      );
    } catch (_) {
      return (expression: FaceExpression.neutral, confidence: 0.65);
    }
  }

  int _estimateAge(Face face) {
    final bb = face.boundingBox;
    final faceW = bb.width.toDouble();
    final faceH = bb.height.toDouble();

    if (faceW <= 0 || faceH <= 0) return 25;

    final mesh = face.mesh;
    if (mesh == null || mesh.length < 468) {
      final aspectRatio = faceW / faceH;
      return (aspectRatio * 25 + 12).clamp(15.0, 50.0).toInt();
    }

    try {
      final leftEye = _safePoint(mesh, 33);
      final rightEye = _safePoint(mesh, 263);
      final upperLip = _safePoint(mesh, 13);
      final chin = _safePoint(mesh, 152);
      final forehead = _safePoint(mesh, 10);
      final noseTip = _safePoint(mesh, 4);

      final eyeDistance = (rightEye.x - leftEye.x).abs();
      final eyeToFaceRatio = eyeDistance / faceW;

      final eyeCenterY = (leftEye.y + rightEye.y) / 2;
      final eyeToMouth = (upperLip.y - eyeCenterY).abs();
      final eyeToMouthRatio = eyeToMouth / faceH;

      final foreheadHeight = (eyeCenterY - forehead.y).abs();
      final foreheadRatio = foreheadHeight / faceH;

      final noseLength = (noseTip.y - eyeCenterY).abs();
      final noseRatio = noseLength / faceH;

      final chinLength = (chin.y - upperLip.y).abs();
      final chinRatio = chinLength / faceH;

      double ageScore = 0;
      ageScore += ((0.40 - eyeToFaceRatio) * 120).clamp(0.0, 30.0);
      ageScore += (eyeToMouthRatio * 50).clamp(5.0, 25.0);
      ageScore += ((0.40 - foreheadRatio) * 30).clamp(0.0, 15.0);
      ageScore += (noseRatio * 40).clamp(2.0, 12.0);
      ageScore += (chinRatio * 20).clamp(1.0, 8.0);

      final estimatedAge = (ageScore * 0.7 + 8).clamp(10.0, 65.0);
      final seed = (faceW * 0.1).toInt() % 5;
      return (estimatedAge + seed - 2).toInt().clamp(10, 65);
    } catch (_) {
      final aspectRatio = faceW / faceH;
      return (aspectRatio * 25 + 12).clamp(15.0, 50.0).toInt();
    }
  }
}

class _Pt {
  final double x;
  final double y;
  const _Pt(this.x, this.y);
}
