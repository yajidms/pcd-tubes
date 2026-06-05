import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pcd_tubes/core/services/mongodb_service.dart';

/// Provider untuk memastikan koneksi ke MongoDB dilakukan secara asinkron 
/// dan tersedia bagi komponen lain yang membutuhkan koneksi DB.
final mongoDbInitProvider = FutureProvider<bool>((ref) async {
  await MongoDbService.connect();
  
  ref.onDispose(() {
    MongoDbService.disconnect();
  });
  
  return MongoDbService.isConnected;
});
