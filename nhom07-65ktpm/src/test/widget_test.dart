import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dcsleep/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('DCSleep app builds and displays dashboard smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DCSleepApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('DCSleep Dashboard'), findsOneWidget);
    expect(find.text('Trang chủ'), findsWidgets);
  });
}
