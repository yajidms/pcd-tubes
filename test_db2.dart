import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  print("Testing connection...");
  var uri = "mongodb+srv://yazidalrasyid145_db_user:BgrNiOVQiWs7vhVP@cluster0.jxilgkj.mongodb.net/pcd_tubes_db?retryWrites=true&w=majority&appName=Cluster0";
  try {
    final db = await Db.create(uri);
    print("Created db instance, opening...");
    await db.open().timeout(Duration(seconds: 10));
    print("Connected successfully!");
    
    final col = db.collection('detection_logs');
    final count = await col.count();
    print("detection_logs count: $count");
    
    await db.close();
  } catch (e) {
    print("Error connecting to MongoDB: $e");
  }
  exit(0);
}
