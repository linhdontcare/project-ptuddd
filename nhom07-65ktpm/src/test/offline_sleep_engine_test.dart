import 'package:flutter_test/flutter_test.dart';
import 'package:dcsleep/data/services/offline_sleep_engine.dart';

void main() {
  group('OfflineSleepEngine Tests', () {
    test('OfflineSleepEngine answers power nap questions (with and without diacritics)', () {
      final ans1 = OfflineSleepEngine.getAdvice('Ngủ trưa bao nhiêu phút?');
      expect(ans1.contains('Power Nap'), true);
      expect(ans1.contains('10 - 20 phút') || ans1.contains('15 - 20 phút') || ans1.contains('15-20'), true);
      expect(ans1.contains('Sleep Inertia') || ans1.contains('quán tính'), true);

      final ans2 = OfflineSleepEngine.getAdvice('ngu trua khoang bao lau thi tot');
      expect(ans2.contains('Power Nap'), true);
    });

    test('OfflineSleepEngine answers 4-7-8 breathing technique questions', () {
      final ans1 = OfflineSleepEngine.getAdvice('Kỹ thuật thở 4-7-8 làm thế nào?');
      expect(ans1.contains('4-7-8'), true);
      expect(ans1.contains('4 giây') || ans1.contains('4s'), true);
      expect(ans1.contains('7 giây') || ans1.contains('7s'), true);
      expect(ans1.contains('8 giây') || ans1.contains('8s'), true);

      final ans2 = OfflineSleepEngine.getAdvice('huong dan tho 4-7-8 de ngu');
      expect(ans2.contains('4-7-8'), true);
    });

    test('OfflineSleepEngine answers caffeine and drink hygiene questions', () {
      final ans1 = OfflineSleepEngine.getAdvice('Uống cà phê sau mấy giờ thì không mất ngủ?');
      expect(ans1.contains('Caffeine') || ans1.contains('cà phê'), true);
      expect(ans1.contains('14:00') || ans1.contains('14h'), true);
      expect(ans1.contains('bán hủy') || ans1.contains('5 - 7') || ans1.contains('5-7'), true);

      final ans2 = OfflineSleepEngine.getAdvice('uong ca phe toi co sao khong');
      expect(ans2.contains('Caffeine') || ans2.contains('cà phê'), true);
    });

    test('OfflineSleepEngine answers difficulty sleeping / 20-minute rule questions', () {
      final ans1 = OfflineSleepEngine.getAdvice('Tôi bị trằn trọc khó ngủ cả tiếng rồi');
      expect(ans1.contains('20 phút'), true);
      expect(ans1.contains('rời giường') || ans1.contains('ngồi dậy'), true);

      final ans2 = OfflineSleepEngine.getAdvice('kho ngu ban dem phai lam sao');
      expect(ans2.contains('20 phút') || ans2.contains('4-7-8'), true);
    });

    test('OfflineSleepEngine provides Default Fallback for unknown queries', () {
      final ans = OfflineSleepEngine.getAdvice('Hôm nay tôi stress quá công việc nhiều');
      expect(ans.contains('chế độ ngoại tuyến'), true);
      expect(ans.contains('kỹ thuật thở 4-7-8'), true);
      expect(ans.contains('Power nap') || ans.contains('ngủ trưa'), true);
    });
  });
}
