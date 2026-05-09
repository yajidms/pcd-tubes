import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class MongoDbService {
  static Db? _db;
  static Future<void> connect() async {
    final uri = dotenv.env['MONGODB_URI'];
    if (uri != null && uri.isNotEmpty) {
      _db = await Db.create(uri);
      await _db!.open();
    }
  }
}
