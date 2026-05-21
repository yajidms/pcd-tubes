import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/features/detect/detect_screen.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("File .env tidak ditemukan, menggunakan environment default");
  }
  // Wrap dengan ProviderScope — wajib untuk flutter_riverpod
  runApp(const ProviderScope(child: PcdTubesApp()));
}

class PcdTubesApp extends StatelessWidget {
  const PcdTubesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tim CAP — Face Detect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DetectScreen(),
    );
  }
}
