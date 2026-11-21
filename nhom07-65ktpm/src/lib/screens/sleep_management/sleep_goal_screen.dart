import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../providers/sleep_provider.dart';

class SleepGoalScreen extends StatefulWidget {
  const SleepGoalScreen({super.key});

  @override
  State<SleepGoalScreen> createState() => _SleepGoalScreenState();
}

class _SleepGoalScreenState extends State<SleepGoalScreen> {
  late TimeOfDay _bedtime;
  late TimeOfDay _wakeTime;
  late double _targetDuration;

  @override
  void initState() {
    super.initState();
    final goal = context.read<SleepProvider>().goal;
    _bedtime = TimeOfDay(hour: goal.bedtimeHour, minute: goal.bedtimeMinute);
    _wakeTime = TimeOfDay(hour: goal.wakeHour, minute: goal.wakeMinute);
    _targetDuration = goal.targetDurationHours;
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

  Future<void> _saveGoal() async {
    await context.read<SleepProvider>().updateGoal(
          bedtimeHour: _bedtime.hour,
          bedtimeMinute: _bedtime.minute,
          wakeHour: _wakeTime.hour,
          wakeMinute: _wakeTime.minute,
          targetDurationHours: _targetDuration,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật mục tiêu giấc ngủ thành công!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết Lập Mục Tiêu Ngủ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xây dựng lịch ngủ cố định giúp đồng hồ sinh học cơ thể ổn định và thức dậy tràn đầy năng lượng.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Thời lượng ngủ mục tiêu:', style: TextStyle(fontSize: 15)),
                    Text(
                      TimeUtils.formatDuration(_targetDuration),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.softGreen),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Lưu Mục Tiêu Giấc Ngủ'),
                onPressed: _saveGoal,
              ),
            ),
          ],
        ),
      ),
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
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            timeStr,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
