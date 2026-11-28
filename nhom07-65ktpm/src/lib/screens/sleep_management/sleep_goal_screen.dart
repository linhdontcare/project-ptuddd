import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/sleep_goal_model.dart';
import '../../providers/sleep_provider.dart';

class SleepGoalScreen extends StatefulWidget {
  const SleepGoalScreen({super.key});

  @override
  State<SleepGoalScreen> createState() => _SleepGoalScreenState();
}

class _SleepGoalScreenState extends State<SleepGoalScreen> {
  static const List<String> _weekdays = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  late TimeOfDay _bedtime;
  late TimeOfDay _wakeTime;
  late double _targetDuration;
  late Set<String> _activeDays;
  late bool _isReminderEnabled;
  int? _editingGoalId;
  bool _isCreatingNew = false;
  SleepGoalModel? _observedGoal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isCreatingNew) return;
    final sleepProv = context.watch<SleepProvider>();
    final goals = sleepProv.goals;
    final targetGoal = _editingGoalId != null
        ? goals.firstWhere(
            (g) => g.id == _editingGoalId,
            orElse: () => sleepProv.goal,
          )
        : sleepProv.goal;
    if (identical(targetGoal, _observedGoal)) return;

    final previousGoal = _observedGoal;
    _observedGoal = targetGoal;
    if (previousGoal != null &&
        previousGoal.id == targetGoal.id &&
        previousGoal.bedtimeHour == targetGoal.bedtimeHour &&
        previousGoal.bedtimeMinute == targetGoal.bedtimeMinute &&
        previousGoal.wakeHour == targetGoal.wakeHour &&
        previousGoal.wakeMinute == targetGoal.wakeMinute &&
        previousGoal.targetDurationHours == targetGoal.targetDurationHours &&
        previousGoal.activeDays == targetGoal.activeDays &&
        previousGoal.isReminderEnabled == targetGoal.isReminderEnabled) {
      return;
    }

    _loadGoalIntoForm(targetGoal);
  }

  void _loadGoalIntoForm(SleepGoalModel goal) {
    _editingGoalId = goal.id;
    _isCreatingNew = false;
    _bedtime = TimeOfDay(hour: goal.bedtimeHour, minute: goal.bedtimeMinute);
    _wakeTime = TimeOfDay(hour: goal.wakeHour, minute: goal.wakeMinute);
    _targetDuration = goal.targetDurationHours;
    _isReminderEnabled = goal.isReminderEnabled;
    _activeDays = goal.activeDays
        .split(',')
        .map((day) => day.trim())
        .where(_weekdays.contains)
        .toSet();
    if (_activeDays.isEmpty) {
      _activeDays.addAll(_weekdays);
    }
  }

  void _startNewGoal() {
    final goals = context.read<SleepProvider>().goals;
    final usedDays = goals
        .expand((g) => g.activeDays.split(',').map((d) => d.trim()))
        .toSet();
    final remainingDays = _weekdays.where((d) => !usedDays.contains(d)).toSet();

    setState(() {
      _isCreatingNew = true;
      _editingGoalId = null;
      _bedtime = const TimeOfDay(hour: 23, minute: 30);
      _wakeTime = const TimeOfDay(hour: 7, minute: 30);
      _recalculateDuration();
      _isReminderEnabled = true;
      _activeDays = remainingDays.isNotEmpty
          ? remainingDays
          : {'T7', 'CN'};
    });
  }

  Future<void> _selectBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bedtime,
      helpText: 'CHỌN GIỜ ĐI NGỦ MỤC TIÊU',
    );
    if (picked != null) {
      setState(() {
        _bedtime = picked;
        _recalculateDuration();
      });
    }
  }

  Future<void> _selectWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime,
      helpText: 'CHỌN GIỜ THỨC DẬY MỤC TIÊU',
    );
    if (picked != null) {
      setState(() {
        _wakeTime = picked;
        _recalculateDuration();
      });
    }
  }

  void _recalculateDuration() {
    int startMinutes = _bedtime.hour * 60 + _bedtime.minute;
    int endMinutes = _wakeTime.hour * 60 + _wakeTime.minute;

    if (endMinutes <= startMinutes) {
      endMinutes += 24 * 60; // Qua đêm
    }

    _targetDuration = (endMinutes - startMinutes) / 60.0;
  }

  void _toggleActiveDay(String day, bool selected) {
    if (selected) {
      setState(() => _activeDays.add(day));
      return;
    }

    if (_activeDays.length == 1 && _activeDays.contains(day)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chọn ít nhất 1 ngày')));
      return;
    }

    setState(() => _activeDays.remove(day));
  }

  Future<void> _saveGoal() async {
    final sleepProv = context.read<SleepProvider>();
    final daysStr = _weekdays.where(_activeDays.contains).join(',');

    if (_isCreatingNew) {
      await sleepProv.addGoal(
        bedtimeHour: _bedtime.hour,
        bedtimeMinute: _bedtime.minute,
        wakeHour: _wakeTime.hour,
        wakeMinute: _wakeTime.minute,
        targetDurationHours: _targetDuration,
        activeDays: daysStr,
        isReminderEnabled: _isReminderEnabled,
      );
      if (mounted) {
        setState(() {
          _isCreatingNew = false;
          _observedGoal = null;
          if (sleepProv.goals.isNotEmpty) {
            _loadGoalIntoForm(sleepProv.goals.last);
          }
        });
      }
    } else {
      await sleepProv.updateGoal(
        goalId: _editingGoalId,
        bedtimeHour: _bedtime.hour,
        bedtimeMinute: _bedtime.minute,
        wakeHour: _wakeTime.hour,
        wakeMinute: _wakeTime.minute,
        targetDurationHours: _targetDuration,
        activeDays: daysStr,
        isReminderEnabled: _isReminderEnabled,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCreatingNew
                ? 'Đã thêm lịch mục tiêu giấc ngủ mới!'
                : 'Đã cập nhật mục tiêu giấc ngủ thành công!',
          ),
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _setReminderEnabled(bool value) async {
    setState(() => _isReminderEnabled = value);
    if (_isCreatingNew) return;
    await context.read<SleepProvider>().setReminderEnabled(
      value,
      goalId: _editingGoalId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Đã bật nhắc giờ đi ngủ' : 'Đã tắt nhắc giờ đi ngủ',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết Lập Mục Tiêu Ngủ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xây dựng lịch ngủ cố định giúp đồng hồ sinh học cơ thể ổn định và thức dậy tràn đầy năng lượng.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildGoalsSelectorSection(context),
            const SizedBox(height: 16),
            // Select Bedtime
            _buildTimePickerCard(
              title: 'Giờ đi ngủ mục tiêu',
              subtitle: 'Thời điểm bắt đầu lên giường ngủ',
              timeStr: TimeUtils.formatTime(_bedtime.hour, _bedtime.minute),
              icon: Icons.nightlight_round,
              color: AppTheme.accentCyan,
              onTap: _selectBedtime,
            ),
            const SizedBox(height: 16),
            // Select Wake Time
            _buildTimePickerCard(
              title: 'Giờ thức dậy mục tiêu',
              subtitle: 'Thời điểm thức dậy đón ngày mới',
              timeStr: TimeUtils.formatTime(_wakeTime.hour, _wakeTime.minute),
              icon: Icons.wb_sunny_outlined,
              color: AppTheme.softAmber,
              onTap: _selectWakeTime,
            ),
            const SizedBox(height: 20),
            // Target Duration Preview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Thời lượng ngủ mục tiêu:',
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          TimeUtils.formatDuration(_targetDuration),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (_targetDuration < 6.0 || _targetDuration > 10.0)
                                ? AppTheme.softAmber
                                : AppTheme.softGreen,
                          ),
                        ),
                      ],
                    ),
                    if (_targetDuration < 6.0 || _targetDuration > 10.0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppTheme.softAmber,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Khuyến nghị người trưởng thành nên ngủ từ 7–9 giờ mỗi đêm.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.softAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ngày áp dụng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  _activeDays
                                    ..clear()
                                    ..addAll(['T2', 'T3', 'T4', 'T5', 'T6']);
                                }),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'T2–T6',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () => setState(() {
                                  _activeDays
                                    ..clear()
                                    ..addAll(_weekdays);
                                }),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Cả tuần',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekdays.map((day) {
                          return FilterChip(
                            label: Text(day),
                            selected: _activeDays.contains(day),
                            onSelected: (selected) =>
                                _toggleActiveDay(day, selected),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Nhắc giờ ngủ & thức dậy'),
              value: _isReminderEnabled,
              onChanged: _setReminderEnabled,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  _isCreatingNew
                      ? Icons.add_circle_outline
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  _isCreatingNew
                      ? 'Thêm Lịch Ngủ Mới'
                      : 'Lưu Mục Tiêu Giấc Ngủ',
                ),
                onPressed: _saveGoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsSelectorSection(BuildContext context) {
    final sleepProv = context.watch<SleepProvider>();
    final goals = sleepProv.goals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch ngủ đã đặt (${goals.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: _startNewGoal,
              icon: const Icon(Icons.add, size: 18, color: AppTheme.accentCyan),
              label: const Text(
                'Thêm lịch mới',
                style: TextStyle(color: AppTheme.accentCyan, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...goals.map((g) {
          final isSelected = !_isCreatingNew && g.id == _editingGoalId;
          final bedStr = TimeUtils.formatTime(g.bedtimeHour, g.bedtimeMinute);
          final wakeStr = TimeUtils.formatTime(g.wakeHour, g.wakeMinute);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accentCyan
                    : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.schedule_rounded,
                color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
              ),
              title: Text(
                '$bedStr → $wakeStr (${TimeUtils.formatDuration(g.targetDurationHours)})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                g.activeDays.split(',').join(' • '),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              trailing: goals.length > 1 && g.id != null
                  ? IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.softRed,
                        size: 20,
                      ),
                      tooltip: 'Xóa lịch này',
                      onPressed: () async {
                        await sleepProv.deleteGoal(g.id!);
                        if (mounted) {
                          setState(() {
                            _isCreatingNew = false;
                            _observedGoal = null;
                            _loadGoalIntoForm(sleepProv.goal);
                          });
                        }
                      },
                    )
                  : null,
              onTap: () => setState(() => _loadGoalIntoForm(g)),
            ),
          );
        }),
        if (_isCreatingNew)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentIndigo.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.accentCyan.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Đang tạo lịch ngủ mới',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _loadGoalIntoForm(sleepProv.goal)),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimePickerCard({
    required String title,
    required String subtitle,
    required String timeStr,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            timeStr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
