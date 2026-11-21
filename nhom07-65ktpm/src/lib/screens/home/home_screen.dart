import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_utils.dart';
import '../../providers/sleep_provider.dart';
import '../sleep_management/sleep_goal_screen.dart';
import '../sleep_management/sleep_diary_screen.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final sleepProv = context.watch<SleepProvider>();
    final goal = sleepProv.goal;
    final latestRecord = sleepProv.latestRecord;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DCSleep Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined),
            tooltip: 'Chỉnh sửa mục tiêu ngủ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SleepGoalScreen()),
              );
            },
          ),
        ],
      ),
      body: sleepProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => sleepProv.loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Greeting & Sleep Goal Card
                    _buildGoalCard(context, goal),
                    const SizedBox(height: 16),

                    // 2. Discipline Progress Card
                    _buildDisciplineCard(
                      context,
                      sleepProv.complianceRate,
                      sleepProv.averageDurationHours,
                    ),
                    const SizedBox(height: 16),

                    // 3. Quick Action Shortcuts
                    _buildQuickActionButtons(context),
                    const SizedBox(height: 20),

                    // 4. Latest Sleep Record Summary
                    _buildLatestRecordCard(context, latestRecord),
                    const SizedBox(height: 20),

                    // 5. Daily Sleep Hygiene Tip
                    _buildDailyTipCard(context),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentIndigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Ghi nhật ký ngủ',
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SleepDiaryScreen()),
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, dynamic goal) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentIndigo.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bedtime_outlined,
                    color: AppTheme.accentCyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Kế Hoạch Giấc Ngủ Mục Tiêu',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeColumn(
                  label: 'Giờ đi ngủ',
                  timeStr: TimeUtils.formatTime(
                    goal.bedtimeHour,
                    goal.bedtimeMinute,
                  ),
                  icon: Icons.nightlight_round,
                  color: AppTheme.accentCyan,
                ),
                Container(width: 1, height: 40, color: AppTheme.cardNavy),
                _buildTimeColumn(
                  label: 'Giờ thức dậy',
                  timeStr: TimeUtils.formatTime(goal.wakeHour, goal.wakeMinute),
                  icon: Icons.wb_sunny_outlined,
                  color: AppTheme.softAmber,
                ),
                Container(width: 1, height: 40, color: AppTheme.cardNavy),
                _buildTimeColumn(
                  label: 'Mục tiêu',
                  timeStr: '${goal.targetDurationHours.toStringAsFixed(1)}h',
                  icon: Icons.timer_outlined,
                  color: AppTheme.softGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn({
    required String label,
    required String timeStr,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          timeStr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDisciplineCard(
    BuildContext context,
    double rate,
    double avgHours,
  ) {
    return Card(
      color: AppTheme.surfaceNavy,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: rate / 100.0,
                    strokeWidth: 6,
                    backgroundColor: AppTheme.cardNavy,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.softGreen,
                    ),
                  ),
                ),
                Text(
                  '${rate.round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chỉ số Kỷ luật Giấc ngủ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trung bình gần đây: ${TimeUtils.formatDuration(avgHours)}. Đạt mục tiêu ${rate.round()}% các ngày qua.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppTheme.accentCyan),
            ),
            icon: const Icon(Icons.flash_on, color: AppTheme.accentCyan),
            label: const Text(
              'Power Nap (15-20p)',
              style: TextStyle(color: AppTheme.textLight, fontSize: 13),
            ),
            onPressed: () => onNavigateTab(2), // Tab Power Nap
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppTheme.accentIndigo),
            ),
            icon: const Icon(
              Icons.smart_toy_outlined,
              color: AppTheme.accentIndigo,
            ),
            label: const Text(
              'Hỏi Trợ lý AI',
              style: TextStyle(color: AppTheme.textLight, fontSize: 13),
            ),
            onPressed: () => onNavigateTab(4), // Tab AI Assistant
          ),
        ),
      ],
    );
  }

  Widget _buildLatestRecordCard(BuildContext context, dynamic record) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nhật Ký Giấc Ngủ Gần Nhất',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (record != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: record.isGoalMet ? AppTheme.softGreen.withValues(alpha: 0.2) : AppTheme.softRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.isGoalMet ? 'Đạt mục tiêu' : 'Chưa đạt',
                      style: TextStyle(
                        fontSize: 11,
                        color: record.isGoalMet
                            ? AppTheme.softGreen
                            : AppTheme.softRed,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (record == null)
              const Text(
                'Chưa có dữ liệu nhật ký. Hãy ghi nhận giấc ngủ hôm nay nhé!',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thời lượng: ${TimeUtils.formatDuration(record.durationHours)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Từ: ${TimeUtils.formatDateTime(record.sleepTime)} đến ${TimeUtils.formatDateTime(record.wakeTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đánh giá cảm nhận: ${'⭐' * record.feelingRating}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardNavy),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lightbulb_outline, color: AppTheme.softAmber, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mẹo vệ sinh giấc ngủ: Ngừng sử dụng điện thoại ít nhất 30 phút trước khi ngủ giúp mắt thư giãn và kích thích sản sinh melatonin tự nhiên.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textLight,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
