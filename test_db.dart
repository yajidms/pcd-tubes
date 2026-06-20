import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  try {
    await dotenv.load(fileName: ".env");
    print("Env loaded: ${dotenv.env['MONGODB_URI']}");
    final db = await Db.create(dotenv.env['MONGODB_URI']!);
    await db.open();
    print("Connected successfully!");
    await db.close();
  } catch (e) {
    print("Error connecting: $e");
  }
  exit(0);
}
