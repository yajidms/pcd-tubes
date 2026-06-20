import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  print("Testing connection...");
  var uri = "mongodb+srv://yazidalrasyid145_db_user:BgrNiOVQiWs7vhVP@cluster0.jxilgkj.mongodb.net/pcd_tubes_db?retryWrites=true&w=majority&appName=Cluster0";
  try {
    final db = await Db.create(uri);
    await db.open();
    
    final col = db.collection('detection_logs');
    final docs = await col.find().toList();
    print("detection_logs count: ${docs.length}");
    for (var doc in docs) {
      print(doc);
    }
    
    await db.close();
  } catch (e) {
    print("Error: $e");
  }
  exit(0);
}
