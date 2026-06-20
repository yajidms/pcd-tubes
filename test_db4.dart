import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pcd_tubes/core/services/mongodb_service.dart';
import 'package:pcd_tubes/core/models/detection_session.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  await MongoDbService.connect();
  
  if (!MongoDbService.isConnected) {
    print("Failed to connect!");
    exit(1);
  }
  
  final session = DetectionSession(
    startTime: DateTime.now().subtract(Duration(seconds: 5)),
    endTime: DateTime.now(),
    durationSeconds: 5,
    expressionDistribution: {'happy': 10, 'neutral': 2},
    averageAge: 25.5,
    totalFacesDetected: 12,
    dominantExpression: 'happy',
  );
  
  print("Logging session...");
  final success = await MongoDbService.logDetectionSession(session);
  print("Success? $success");
  
  final sessions = await MongoDbService.getDetectionHistory();
  print("Session count: ${sessions.length}");
  
  exit(0);
}
