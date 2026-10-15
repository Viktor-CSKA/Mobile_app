import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/reminders/data/reminder_providers.dart';
import 'home_shell.dart';

class EzhemesyachnoApp extends ConsumerWidget {
  const EzhemesyachnoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Держим напоминания в соответствии с платежами и настройками.
    ref.watch(reminderSyncProvider);

    return MaterialApp(
      title: 'Ежемесячно',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
