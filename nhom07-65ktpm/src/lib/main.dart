import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/sleep_provider.dart';
import 'providers/nap_provider.dart';
import 'providers/ai_assistant_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DCSleepApp());
}

class DCSleepApp extends StatelessWidget {
  const DCSleepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SleepProvider()..loadData()),
        ChangeNotifierProvider(create: (_) => NapProvider()..loadHistory()),
        ChangeNotifierProvider(
          create: (_) => AIAssistantProvider()..loadMessages(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSettings(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'DCSleep',
            debugShowCheckedModeBanner: false,
            theme: settings.isDarkMode ? AppTheme.darkTheme : ThemeData.light(useMaterial3: true),
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}
