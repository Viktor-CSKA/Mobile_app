import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/clock.dart';
import 'core/theme/app_theme.dart';
import 'features/reminders/data/reminder_providers.dart';
import 'features/settings/data/theme_providers.dart';
import 'home_shell.dart';

class EzhemesyachnoApp extends ConsumerStatefulWidget {
  const EzhemesyachnoApp({super.key});

  @override
  ConsumerState<EzhemesyachnoApp> createState() => _EzhemesyachnoAppState();
}

class _EzhemesyachnoAppState extends ConsumerState<EzhemesyachnoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Вернулись в приложение (возможно, на следующий день): обновляем
  /// «сегодня» и «сейчас» и пересчитываем напоминания.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayProvider);
      ref.invalidate(nowProvider);
      ref.invalidate(reminderSyncProvider); // пересоздание = новый пересчёт
    }
  }

  @override
  Widget build(BuildContext context) {
    // Держим напоминания в соответствии с платежами и настройками.
    ref.watch(reminderSyncProvider);

    return MaterialApp(
      title: 'Ежемесячно',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
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
