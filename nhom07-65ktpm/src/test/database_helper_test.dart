import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dcsleep/data/database/database_helper.dart';
import 'package:dcsleep/data/models/ai_message_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.instance.closeDatabase();
  });

  test('DatabaseHelper saves and retrieves is_offline flag using in-memory db', () async {
    await DatabaseHelper.instance.initCustomDatabase(path: inMemoryDatabasePath);
    final msg = AIMessageModel(
      text: 'Offline test',
      isUser: false,
      isOffline: true,
      timestamp: DateTime.now(),
    );
    final id = await DatabaseHelper.instance.insertAIMessage(msg);
    final messages = await DatabaseHelper.instance.getAllAIMessages();
    expect(messages.any((m) => m.id == id && m.isOffline == true), true);
  });
}
