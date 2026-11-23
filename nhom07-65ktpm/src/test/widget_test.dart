import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dcsleep/main.dart';
import 'package:dcsleep/providers/settings_provider.dart';
import 'package:dcsleep/providers/sleep_provider.dart';
import 'package:dcsleep/providers/nap_provider.dart';
import 'package:dcsleep/providers/ai_assistant_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('DCSleep app builds and displays dashboard smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SleepProvider()),
          ChangeNotifierProvider(create: (_) => NapProvider()),
          ChangeNotifierProvider(create: (_) => AIAssistantProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const DCSleepApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('DCSleep Dashboard'), findsOneWidget);
    expect(find.text('Trang chủ'), findsWidgets);
  });
}
