import 'dart:io';
import 'package:pcd_tubes/core/models/detection_session.dart';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  var uri = "mongodb+srv://yazidalrasyid145_db_user:BgrNiOVQiWs7vhVP@cluster0.jxilgkj.mongodb.net/pcd_tubes_db?retryWrites=true&w=majority&appName=Cluster0";
  try {
    final db = await Db.create(uri);
    await db.open();
    print("Connected!");
    
    final col = db.collection('detection_logs');
    
    final session = DetectionSession(
      startTime: DateTime.now().subtract(Duration(seconds: 5)),
      endTime: DateTime.now(),
      durationSeconds: 5,
      expressionDistribution: {'happy': 10, 'neutral': 2},
      averageAge: 25.5,
      totalFacesDetected: 12,
      dominantExpression: 'happy',
    );
    
    await col.insertOne(session.toMap());
    print("Inserted successfully!");
    
    final count = await col.count();
    print("Total logs: $count");
    
    await db.close();
  } catch (e) {
    print("Error: $e");
  }
  exit(0);
}
