import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/nap_provider.dart';

class PowerNapScreen extends StatelessWidget {
  const PowerNapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final napProv = context.watch<NapProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giấc Ngủ Ngắn (Power Nap)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. Informational Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceNavy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardNavy),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: AppTheme.accentCyan),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Khuyến nghị khoa học: Giấc ngủ ngắn 10–20 phút giúp não bộ phục hồi sự tỉnh táo mà không gây cảm giác mệt mỏi sau khi thức dậy.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 2. Preset Selection Chips
            const Text('Chọn thời lượng giấc ngủ ngắn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: AppConstants.napPresetsMinutes.map((minutes) {
                final isSelected = napProv.selectedPresetMinutes == minutes;
                return ChoiceChip(
                  label: Text('$minutes phút'),
                  selected: isSelected,
                  selectedColor: AppTheme.accentIndigo,
                  onSelected: (selected) {
                    if (selected) napProv.selectPreset(minutes);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 36),

            // 3. Circular Countdown Progress Widget
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: napProv.progress,
                    strokeWidth: 10,
                    backgroundColor: AppTheme.cardNavy,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      napProv.formattedRemainingTime,
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      napProv.isRunning ? 'Đang trong giấc ngủ ngắn...' : 'Sẵn sàng bắt đầu',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),

            // 4. Control Buttons (Start / Pause / Reset)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!napProv.isRunning)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.softGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('Bắt đầu', style: TextStyle(color: Colors.white, fontSize: 16)),
                    onPressed: () => napProv.startTimer(),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.softAmber,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    icon: const Icon(Icons.pause, color: Colors.black87),
                    label: const Text('Tạm dừng', style: TextStyle(color: Colors.black87, fontSize: 16)),
                    onPressed: () => napProv.pauseTimer(),
                  ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Đặt lại'),
                  onPressed: () => napProv.resetTimer(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
