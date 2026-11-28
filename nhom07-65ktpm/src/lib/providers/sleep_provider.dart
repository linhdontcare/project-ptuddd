import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database/database_helper.dart';
import '../data/models/sleep_goal_model.dart';
import '../data/models/sleep_record_model.dart';
import '../data/services/notification_service.dart';
import '../data/services/supabase_service.dart';

class SleepProvider extends ChangeNotifier {
  SleepGoalModel _goal = SleepGoalModel(
    bedtimeHour: 23,
    bedtimeMinute: 0,
    wakeHour: 7,
    wakeMinute: 0,
    targetDurationHours: 8.0,
  );
  List<SleepGoalModel> _goals = [];
  List<SleepRecordModel> _records = [];
  bool _isLoading = true;
  bool _hasSyncedInitialReminder = false;

  static const Map<int, String> _weekdayLabels = {
    DateTime.monday: 'T2',
    DateTime.tuesday: 'T3',
    DateTime.wednesday: 'T4',
    DateTime.thursday: 'T5',
    DateTime.friday: 'T6',
    DateTime.saturday: 'T7',
    DateTime.sunday: 'CN',
  };

  SleepGoalModel get goal {
    if (_goals.isEmpty) return _goal;
    final todayLabel = _weekdayLabels[DateTime.now().weekday];
    if (todayLabel != null) {
      for (final g in _goals) {
        final days = g.activeDays.split(',').map((d) => d.trim()).toSet();
        if (days.contains(todayLabel)) return g;
      }
    }
    return _goals.first;
  }

  List<SleepGoalModel> get goals =>
      _goals.isEmpty ? [_goal] : List.unmodifiable(_goals);
  List<SleepRecordModel> get records => _records;
  bool get isLoading => _isLoading;

  SleepRecordModel? get latestRecord =>
      _records.isNotEmpty ? _records.first : null;

  // Discipline & Compliance Rate (%)
  double get complianceRate {
    if (_records.isEmpty) return 100.0;
    final recent = _records.take(7).toList();
    final metCount = recent.where((r) => r.isGoalMet).length;
    return (metCount / recent.length) * 100.0;
  }

  // Average sleep duration of recent 7 days
  double get averageDurationHours {
    if (_records.isEmpty) return _goal.targetDurationHours;
    final recent = _records.take(7).toList();
    final total = recent.fold<double>(0.0, (sum, r) => sum + r.durationHours);
    return total / recent.length;
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _goals = await DatabaseHelper.instance.getSleepGoals();
    _goal = _goals.first;
    _records = await DatabaseHelper.instance.getSleepRecords();

    if (!_hasSyncedInitialReminder) {
      _hasSyncedInitialReminder = true;
      if (_goals.any((g) => g.isReminderEnabled)) {
        try {
          await _syncBedtimeReminder();
        } catch (e) {
          debugPrint(
            '[SleepProvider] Lỗi lên lịch lại nhắc giờ đi ngủ khi mở app: $e',
          );
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateGoal({
    int? goalId,
    required int bedtimeHour,
    required int bedtimeMinute,
    required int wakeHour,
    required int wakeMinute,
    required double targetDurationHours,
    required String activeDays,
    bool? isReminderEnabled,
  }) async {
    final targetId = goalId ?? goal.id;
    final existing = _goals.firstWhere(
      (g) => g.id == targetId,
      orElse: () => goal,
    );
    final updated = SleepGoalModel(
      id: targetId,
      bedtimeHour: bedtimeHour,
      bedtimeMinute: bedtimeMinute,
      wakeHour: wakeHour,
      wakeMinute: wakeMinute,
      targetDurationHours: targetDurationHours,
      activeDays: activeDays,
      isReminderEnabled: isReminderEnabled ?? existing.isReminderEnabled,
    );
    await _deduplicateDaysAcrossOtherGoals(
      selectedDaysStr: activeDays,
      excludeGoalId: targetId,
    );
    await DatabaseHelper.instance.updateSleepGoal(updated);
    _goals = await DatabaseHelper.instance.getSleepGoals();
    _goal = _goals.first;
    unawaited(SupabaseService.instance.syncSleepGoal(updated));
    await _syncBedtimeReminder();
    notifyListeners();
  }

  Future<void> addGoal({
    required int bedtimeHour,
    required int bedtimeMinute,
    required int wakeHour,
    required int wakeMinute,
    required double targetDurationHours,
    required String activeDays,
    bool isReminderEnabled = true,
  }) async {
    await _deduplicateDaysAcrossOtherGoals(selectedDaysStr: activeDays);
    final newGoal = SleepGoalModel(
      bedtimeHour: bedtimeHour,
      bedtimeMinute: bedtimeMinute,
      wakeHour: wakeHour,
      wakeMinute: wakeMinute,
      targetDurationHours: targetDurationHours,
      activeDays: activeDays,
      isReminderEnabled: isReminderEnabled,
    );
    await DatabaseHelper.instance.insertSleepGoal(newGoal);
    _goals = await DatabaseHelper.instance.getSleepGoals();
    _goal = _goals.first;
    unawaited(SupabaseService.instance.syncSleepGoal(newGoal));
    await _syncBedtimeReminder();
    notifyListeners();
  }

  Future<void> _deduplicateDaysAcrossOtherGoals({
    required String selectedDaysStr,
    int? excludeGoalId,
  }) async {
    final selectedDays = selectedDaysStr
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toSet();
    if (selectedDays.isEmpty) return;

    for (final existing in _goals) {
      if (excludeGoalId != null && existing.id == excludeGoalId) continue;
      if (existing.id == null) continue;

      final existingDays = existing.activeDays
          .split(',')
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();
      final remaining =
          existingDays.where((d) => !selectedDays.contains(d)).toList();

      if (remaining.length == existingDays.length) continue;

      if (remaining.isEmpty) {
        await DatabaseHelper.instance.deleteSleepGoal(existing.id!);
      } else {
        final updatedOther = SleepGoalModel(
          id: existing.id,
          bedtimeHour: existing.bedtimeHour,
          bedtimeMinute: existing.bedtimeMinute,
          wakeHour: existing.wakeHour,
          wakeMinute: existing.wakeMinute,
          targetDurationHours: existing.targetDurationHours,
          activeDays: remaining.join(','),
          isReminderEnabled: existing.isReminderEnabled,
        );
        await DatabaseHelper.instance.updateSleepGoal(updatedOther);
      }
    }
  }

  Future<void> deleteGoal(int id) async {
    if (_goals.length <= 1) return;
    await DatabaseHelper.instance.deleteSleepGoal(id);
    _goals = await DatabaseHelper.instance.getSleepGoals();
    _goal = _goals.first;
    await _syncBedtimeReminder();
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool value, {int? goalId}) async {
    final targetId = goalId ?? goal.id;
    final existing = _goals.firstWhere(
      (g) => g.id == targetId,
      orElse: () => goal,
    );
    final updated = SleepGoalModel(
      id: existing.id,
      bedtimeHour: existing.bedtimeHour,
      bedtimeMinute: existing.bedtimeMinute,
      wakeHour: existing.wakeHour,
      wakeMinute: existing.wakeMinute,
      targetDurationHours: existing.targetDurationHours,
      activeDays: existing.activeDays,
      isReminderEnabled: value,
    );
    await DatabaseHelper.instance.updateSleepGoal(updated);
    _goals = await DatabaseHelper.instance.getSleepGoals();
    _goal = _goals.first;
    unawaited(SupabaseService.instance.syncSleepGoal(updated));
    await _syncBedtimeReminder();
    notifyListeners();
  }

  Future<void> _syncBedtimeReminder() async {
    await NotificationService.instance.cancelBedtimeReminders();
    await NotificationService.instance.cancelWakeupReminders();

    final listToSchedule = _goals.isNotEmpty ? _goals : [_goal];
    for (int i = 0; i < listToSchedule.length && i < 10; i++) {
      final g = listToSchedule[i];
      if (!g.isReminderEnabled) continue;
      await NotificationService.instance.scheduleBedtimeReminder(
        hour: g.bedtimeHour,
        minute: g.bedtimeMinute,
        title: 'Đến giờ đi ngủ rồi',
        body: 'Đã đến giờ đi ngủ theo lịch bạn đặt. Chuẩn bị nghỉ thôi!',
        activeDays: g.activeDays,
        slotIndex: i,
      );
      await NotificationService.instance.scheduleWakeupReminder(
        hour: g.wakeHour,
        minute: g.wakeMinute,
        title: 'Đã đến giờ thức dậy!',
        body: 'Chào buổi sáng! Đã đến giờ thức dậy đón ngày mới rồi!',
        activeDays: g.activeDays,
        slotIndex: i,
      );
    }
  }

  Future<void> addSleepRecord({
    required DateTime sleepTime,
    required DateTime wakeTime,
    required int feelingRating,
    required int wakeUpCount,
    required String note,
  }) async {
    final duration = wakeTime.difference(sleepTime).inMinutes / 60.0;
    final isGoalMet = duration >= (_goal.targetDurationHours - 0.5);

    final record = SleepRecordModel(
      sleepTime: sleepTime,
      wakeTime: wakeTime,
      durationHours: duration,
      wakeUpCount: wakeUpCount,
      feelingRating: feelingRating,
      note: note,
      isGoalMet: isGoalMet,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.insertSleepRecord(record);
    unawaited(SupabaseService.instance.syncSleepRecord(record));
    await loadData();
  }

  // Cập nhật nhật ký giấc ngủ
  Future<void> updateSleepRecord(SleepRecordModel record) async {
    if (record.id == null) return;

    await DatabaseHelper.instance.updateSleepRecord(record);
    await loadData();
  }

  // Xóa nhật ký giấc ngủ
  Future<void> deleteSleepRecord(int id) async {
    await DatabaseHelper.instance.deleteSleepRecord(id);
    await loadData();
  }
}
