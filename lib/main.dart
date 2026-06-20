import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/core/services/mongodb_service.dart';
import 'package:pcd_tubes/features/challenge/challenge_screen.dart';
import 'package:pcd_tubes/features/dashboard/dashboard_screen.dart';
import 'package:pcd_tubes/features/detect/detect_screen.dart';
import 'package:pcd_tubes/features/journal/journal_screen.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("File .env tidak ditemukan, menggunakan environment default");
  }

  // Await MongoDB connection agar siap sebelum widget query data
  await MongoDbService.connect();

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
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _current = 0;

  final _screens = const [
    DetectScreen(),
    DashboardScreen(),
    JournalScreen(),
    ChallengeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _current, children: _screens),
      bottomNavigationBar: _ElegantNavBar(
        current: _current,
        onTap: (i) {
          setState(() => _current = i);
        },
      ),
    );
  }
}

class _ElegantNavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const _ElegantNavBar({required this.current, required this.onTap});

  static const _items = [
    (Icons.camera_alt_outlined, 'Detect'),
    (Icons.bar_chart_outlined, 'Dashboard'),
    (Icons.book_outlined, 'Journal'),
    (Icons.emoji_events_outlined, 'Challenge'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 72 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E), width: 1)),
      ),
      child: Row(
        children: _items.asMap().entries.map((e) {
          final active = e.key == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(e.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        e.value.$1,
                        size: 22,
                        color: active ? AppTheme.primary : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? AppTheme.primary : Colors.grey.shade600,
                      ),
                      child: Text(e.value.$2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}