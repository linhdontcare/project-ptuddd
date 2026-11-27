import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dcsleep/data/models/ai_message_model.dart';
import 'package:dcsleep/data/services/ai_service.dart';

/// Dịch vụ gọi Gemini 2.5 Flash REST API (tách biệt hoàn toàn khỏi OfflineSleepEngine).
/// Sử dụng header `x-goog-api-key`, hỗ trợ inject `http.Client` để kiểm thử bằng `MockClient`,
/// timeout 10 giây và chuẩn hóa lịch sử hội thoại `contents` tránh lỗi 400 Bad Request.
class GeminiAIService implements AIService {
  static final GeminiAIService instance = GeminiAIService();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const String _baseSystemInstruction = '''
[VAI TRÒ VÀ TÍNH CÁCH]:
Bạn là Chuyên gia Tư vấn Giấc ngủ Khoa học của ứng dụng DCSleep. Hãy trả lời ấm áp, thấu cảm, khoa học, súc tích bằng tiếng Việt. Độ dài câu trả lời lý tưởng dưới 200 từ.

[PHẠM VI TRI THỨC ĐƯỢC PHÉP TƯ VẤN]:
1. Nguyên tắc Vệ sinh Giấc ngủ (Sleep Hygiene): Ánh sáng, nhiệt độ phòng ngủ (20-24°C), kiểm soát caffeine (tránh sau 14h), hạn chế ánh sáng xanh từ thiết bị số.
2. Nhịp sinh học (Circadian Rhythm): Quy tắc thức ngủ đều đặn, chu kỳ giấc ngủ 90 phút (REM & NREM).
3. Kỹ thuật thư giãn hỗ trợ vào giấc: Kỹ thuật thở 4-7-8, giãn cơ lũy tiến (PMR), quy tắc 20 phút rời giường khi mất ngủ.
4. Quản lý giấc ngủ ngắn (Power Nap): 10 - 20 phút buổi trưa (12:30 - 13:30), tránh ngủ quá 30 phút gây quán tính giấc ngủ (Sleep Inertia).

[RANH GIỚI VÀ QUY TẮC BẮT BUỘC]:
- KHÔNG BAO GIỜ đưa ra chẩn đoán y khoa hoặc kê đơn, hướng dẫn liều lượng bất kỳ loại thuốc ngủ/thuốc an thần nào.
- Luôn kết thúc bằng lưu ý ngắn: Lời khuyên mang tính chất hỗ trợ xây dựng lối sống khoa học, không thay thế chỉ định y tế.''';

  final http.Client _client;
  final Duration _timeout;
  String _apiKey = '';

  GeminiAIService({
    http.Client? client,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 10);

  @override
  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  @override
  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  @override
  Future<String> askAssistant({
    required String prompt,
    String? sleepContext,
    List<AIMessageModel> history = const [],
  }) async {
    if (!hasApiKey) {
      throw AIServiceException('Chưa cấu hình API Key');
    }

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': _buildSystemInstruction(sleepContext)},
        ],
      },
      'contents': buildContentsPayload(
        history: history,
        currentPrompt: prompt,
      ),
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'maxOutputTokens': 1024,
        'thinkingConfig': {
          'thinkingBudget': 0,
        },
      },
    };

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      final responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode != 200) {
        throw AIServiceException(
          responseBody,
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw AIServiceException(
          'Phản hồi từ Gemini API không có kết quả',
          statusCode: response.statusCode,
        );
      }

      final firstCandidate = candidates.first as Map<String, dynamic>?;
      final content = firstCandidate?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final firstPart = parts != null && parts.isNotEmpty ? parts.first : null;
      final text = firstPart is Map<String, dynamic>
          ? firstPart['text']?.toString().trim()
          : null;

      if (text == null || text.isEmpty) {
        throw AIServiceException(
          'Nội dung phản hồi từ Gemini API rỗng',
          statusCode: response.statusCode,
        );
      }

      return text;
    } on AIServiceException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AIServiceException(
        'Quá thời gian chờ phản hồi từ máy chủ AI',
        cause: e,
      );
    } on SocketException catch (e) {
      throw AIServiceException(
        'Mất kết nối Internet: $e',
        cause: e,
      );
    } catch (e) {
      throw AIServiceException('Lỗi kết nối dịch vụ AI: $e', cause: e);
    }
  }

  String _buildSystemInstruction(String? sleepContext) {
    if (sleepContext == null || sleepContext.trim().isEmpty) {
      return _baseSystemInstruction;
    }
    return '$_baseSystemInstruction\n\n[DỮ LIỆU THỰC TẾ TỪ DCSLEEP HIỆN TẠI]:\n${sleepContext.trim()}';
  }

  /// Chuẩn hóa mảng `contents` cho Gemini REST API:
  /// 1. Nạp lịch sử từ `history`.
  /// 2. Nối `currentPrompt` (`role: user`) vào cuối TRƯỚC khi khử trùng lặp.
  /// 3. Cắt cửa sổ trượt tối đa 7 tin nhắn gần nhất.
  /// 4. Bỏ qua các tin nhắn `role: model` ở đầu mảng.
  /// 5. Khử trùng lặp các role đứng liền nhau (giữ phần tử mới hơn).
  List<Map<String, dynamic>> buildContentsPayload({
    List<AIMessageModel> history = const [],
    required String currentPrompt,
  }) {
    final rawContents = <Map<String, dynamic>>[];

    for (final msg in history) {
      if (msg.text.trim().isEmpty) continue;
      rawContents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text},
        ],
      });
    }

    rawContents.add({
      'role': 'user',
      'parts': [
        {'text': currentPrompt},
      ],
    });

    final windowed = rawContents.length > 7
        ? rawContents.sublist(rawContents.length - 7)
        : List<Map<String, dynamic>>.from(rawContents);

    while (windowed.isNotEmpty && windowed.first['role'] == 'model') {
      windowed.removeAt(0);
    }

    final deduped = <Map<String, dynamic>>[];
    for (final item in windowed) {
      if (deduped.isNotEmpty && deduped.last['role'] == item['role']) {
        deduped.removeLast();
      }
      deduped.add(item);
    }

    return deduped;
  }
}
