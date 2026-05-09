import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pcd_tubes/features/detect/detect_screen.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("File .env tidak ditemukan, menggunakan environment default");
  }
  runApp(const PcdTubesApp());
}
class PcdTubesApp extends StatelessWidget {
  const PcdTubesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCD Tubes',
      theme: AppTheme.lightTheme,
      home: const DetectScreen(),
    );
  }
}
