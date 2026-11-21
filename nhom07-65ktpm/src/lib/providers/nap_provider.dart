import 'dart:async';
import 'package:flutter/material.dart';
import '../data/database/database_helper.dart';
import '../data/models/nap_record_model.dart';

class NapProvider extends ChangeNotifier {
  int _selectedPresetMinutes = 20;
  int _remainingSeconds = 20 * 60;
  bool _isRunning = false;
  Timer? _timer;
  List<NapRecordModel> _napHistory = [];

  int get selectedPresetMinutes => _selectedPresetMinutes;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  List<NapRecordModel> get napHistory => _napHistory;

  double get progress {
    final total = _selectedPresetMinutes * 60;
    if (total == 0) return 0;
    return 1.0 - (_remainingSeconds / total);
  }

  String get formattedRemainingTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void selectPreset(int minutes) {
    if (_isRunning) return;
    _selectedPresetMinutes = minutes;
    _remainingSeconds = minutes * 60;
    notifyListeners();
  }

  void startTimer() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        stopTimer(completed: true);
      }
    });
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _isRunning = false;
    _remainingSeconds = _selectedPresetMinutes * 60;
    notifyListeners();
  }

  Future<void> stopTimer({bool completed = false}) async {
    _timer?.cancel();
    _isRunning = false;

    if (completed) {
      final nap = NapRecordModel(
        startTime: DateTime.now().subtract(Duration(minutes: _selectedPresetMinutes)),
        durationMinutes: _selectedPresetMinutes,
        note: 'Hoàn thành giấc ngủ ngắn $_selectedPresetMinutes phút.',
      );
      await DatabaseHelper.instance.insertNapRecord(nap);
      await loadHistory();
    }
    _remainingSeconds = _selectedPresetMinutes * 60;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      _napHistory = await DatabaseHelper.instance.getNapRecords();
    } catch (e) {
      debugPrint('[NapProvider] SQLite loadHistory fallback: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
