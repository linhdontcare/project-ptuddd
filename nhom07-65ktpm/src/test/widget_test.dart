import 'package:flutter_test/flutter_test.dart';
import 'package:dcsleep/main.dart';

void main() {
  testWidgets('DCSleep app builds and displays dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DCSleepApp());
    await tester.pumpAndSettle();

    // Verify that the dashboard title and bottom navigation appear.
    expect(find.text('DCSleep Dashboard'), findsOneWidget);
    expect(find.text('Trang chủ'), findsWidgets);
  });
}
