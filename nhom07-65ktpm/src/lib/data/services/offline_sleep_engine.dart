import 'package:dcsleep/data/services/safety_guardrails.dart';

/// Bộ tri thức chuyên gia ngoại tuyến (OfflineSleepEngine)
/// Cung cấp câu trả lời khoa học tức thì khi thiết bị mất mạng, timeout hoặc API bị lỗi.
class OfflineSleepEngine {
  /// Phân tích prompt của người dùng và trả về hướng dẫn chuyên gia tương ứng.
  /// Hỗ trợ 4 chủ đề cốt lõi và nhánh Default Fallback.
  static String getAdvice(String prompt) {
    final rawLower = prompt.toLowerCase();
    final noDiacritics = SafetyGuardrails.removeDiacritics(rawLower);

    // 1. Giấc ngủ trưa (Power Nap)
    if (_hasAnyMatch(rawLower, noDiacritics, [
      'ngủ trưa', 'ngu trua', 'power nap', 'giấc ngủ ngắn', 'giac ngu ngan', 'nap',
    ])) {
      return '🌙 Về giấc ngủ trưa (Power Nap):\n\n'
          '1. Thời lượng lý tưởng: 10 - 20 phút (khuyến nghị 15 - 20 phút). Tránh ngủ quá 30 phút vì dễ rơi vào giấc ngủ sâu (Slow-wave sleep), khi thức dậy sẽ bị mệt mỏi, choáng váng do quán tính giấc ngủ (Sleep Inertia).\n'
          '2. Thời điểm tốt nhất: Trong khoảng 12:30 - 13:30, cách giờ ngủ ban đêm ít nhất 6 tiếng.\n'
          '3. Bạn có thể sử dụng tab "Giấc ngủ ngắn" trong DCSleep để bấm đếm ngược 15-20 phút nhé!';
    }

    // 2. Kỹ thuật thở 4-7-8 & Giãn cơ
    if (_hasAnyMatch(rawLower, noDiacritics, [
      '4-7-8', '4 7 8', 'hít thở', 'hit tho', 'tập thở', 'tap tho',
      'giãn cơ', 'gian co', 'thư giãn', 'thu gian', 'hơi thở', 'hoi tho',
      'thở', 'tho',
    ])) {
      return '🌬️ Kỹ thuật thở 4-7-8 giúp thư giãn hệ thần kinh:\n\n'
          '1. Hít vào: Bằng mũi nhẹ nhàng trong 4 giây.\n'
          '2. Nín thở: Giữ hơi thở ổn định trong 7 giây.\n'
          '3. Thở ra: Từ từ bằng miệng tạo âm thanh nhẹ trong 8 giây.\n'
          '4. Lặp lại: Thực hiện liên tục 4 chu kỳ để kích hoạt hệ thần kinh phó giao cảm (Parasympathetic), giúp nhịp tim chậm lại và dễ dàng đi vào giấc ngủ.';
    }

    // 3. Vệ sinh Caffeine & Ăn uống
    if (_hasAnyMatch(rawLower, noDiacritics, [
      'cà phê', 'ca phe', 'caffeine', 'nước tăng lực', 'nuoc tang luc',
      'đồ uống', 'do uong', 'ăn uống', 'an uong', 'bữa tối', 'bua toi',
      'ăn đêm', 'an dem', 'trà', 'tra',
    ])) {
      return '☕ Vệ sinh giấc ngủ về đồ ăn & thức uống:\n\n'
          '1. Caffeine: Tránh uống cà phê, trà đậm, nước tăng lực sau 14:00 (Caffeine có thời gian bán hủy từ 5 - 7 tiếng trong cơ thể).\n'
          '2. Bữa tối: Không ăn quá no hoặc đồ cay nóng nhiều dầu mỡ trong vòng 2 tiếng trước khi đi ngủ để tránh áp lực tiêu hóa và trào ngược dạ dày.\n'
          '3. Đồ uống bổ trợ: Bạn có thể dùng một ly nước ấm hoặc trà hoa cúc nhẹ để hỗ trợ làm dịu thần kinh trước giờ ngủ.';
    }

    // 4. Xử lý khó ngủ / trằn trọc ban đêm (Quy tắc 20 phút)
    if (_hasAnyMatch(rawLower, noDiacritics, [
      'khó ngủ', 'kho ngu', 'mất ngủ', 'mat ngu', 'trằn trọc', 'tran troc',
      'thức khuya', 'thuc khuya', 'rời giường', 'roi giuong',
      'không ngủ được', 'khong ngu duoc',
    ])) {
      return '💡 Gợi ý khắc phục khi khó ngủ hoặc trằn trọc ban đêm:\n\n'
          '1. Quy tắc 20 phút: Nếu nằm trên giường quá 20 phút mà chưa thể ngủ được, hãy rời giường (ngồi dậy), di chuyển sang không gian khác hoặc bàn đọc sách.\n'
          '2. Thư giãn thụ động: Đọc sách giấy dưới ánh đèn vàng mờ hoặc nghe nhạc nhẹ cho đến khi cảm thấy buồn ngủ thực sự rồi mới trở lại giường nằm.\n'
          '3. Kỹ thuật thở 4-7-8: Khi lên giường lại, thực hiện 4 chu kỳ thở 4-7-8 để đưa cơ thể về trạng thái thả lỏng sâu.\n'
          '4. Hạn chế thiết bị: Tuyệt đối tránh lướt điện thoại hay xem màn hình máy tính vì ánh sáng xanh sẽ làm ức chế hormone Melatonin.';
    }

    // 5. Nhánh dự phòng mặc định (Default Fallback)
    return 'DCSleep hiện đang hoạt động ở chế độ ngoại tuyến. Trong chế độ này, tôi hỗ trợ tốt nhất các chủ đề: kỹ thuật thở 4-7-8, thời lượng ngủ trưa (Power nap), kiểm soát caffeine và mẹo khi khó ngủ. Bạn có thể chọn nhanh các câu hỏi gợi ý ở phía trên hoặc kết nối mạng để trò chuyện chi tiết hơn nhé!';
  }

  static bool _hasAnyMatch(String raw, String noDiacritics, List<String> keywords) {
    for (final kw in keywords) {
      // 1. Kiểm tra khớp chuỗi chính xác trên chuỗi gốc
      final rawPattern = RegExp('(?<=^|[^a-zA-Z0-9àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ])${RegExp.escape(kw)}(?=[^a-zA-Z0-9àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]|\$)', caseSensitive: false);
      if (rawPattern.hasMatch(raw)) {
        return true;
      }

      // 2. Kiểm tra khớp từ biên (word boundary) trên chuỗi không dấu thuần ASCII
      final kwNoDiacritics = SafetyGuardrails.removeDiacritics(kw);
      final asciiPattern = RegExp('(?<=^|[^a-zA-Z0-9])${RegExp.escape(kwNoDiacritics)}(?=[^a-zA-Z0-9]|\$)', caseSensitive: false);
      if (asciiPattern.hasMatch(noDiacritics)) {
        return true;
      }
    }
    return false;
  }
}
