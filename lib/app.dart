import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/catalog/presentation/catalog_screen.dart';
import 'features/progress/domain/progress_controller.dart';
import 'features/progress/presentation/progress_screen.dart';

class ChessPracticeApp extends StatelessWidget {
  const ChessPracticeApp({super.key, required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Practice',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _HomeShell(progress: progress),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.progress});

  final ProgressController progress;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CatalogScreen(progress: widget.progress),
      ProgressScreen(progress: widget.progress),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Courses'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Progress'),
        ],
      ),
    );
  }
}
