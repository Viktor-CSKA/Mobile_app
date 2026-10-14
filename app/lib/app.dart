import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'home_shell.dart';

class EzhemesyachnoApp extends StatelessWidget {
  const EzhemesyachnoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ежемесячно',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
