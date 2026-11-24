import 'package:flutter/material.dart';

import '../data/database/database_helper.dart';
import '../data/models/reminder_model.dart';
import '../data/models/user_model.dart';

class SettingsProvider extends ChangeNotifier {
  final UserModel _user = UserModel(
    name: 'Mã Khánh Linh',
    email: 'mkl.deeptry@gmail.com',
    studentId: '2351170602',
    className: '65KTPM',
  );
  List<ReminderModel> _reminders = [];
  bool _isDarkMode = true;

  UserModel get user => _user;
  List<ReminderModel> get reminders => _reminders;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadSettings() async {
    _reminders = await DatabaseHelper.instance.getReminders();
    notifyListeners();
  }

  Future<void> toggleReminder(ReminderModel reminder, bool val) async {
    final updated = ReminderModel(
      id: reminder.id,
      title: reminder.title,
      hour: reminder.hour,
      minute: reminder.minute,
      type: reminder.type,
      isEnabled: val,
    );
    await DatabaseHelper.instance.updateReminder(updated);
    await loadSettings();
  }

  void toggleTheme(bool dark) {
    _isDarkMode = dark;
    notifyListeners();
  }
}
