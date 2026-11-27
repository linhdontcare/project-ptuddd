import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/database/database_helper.dart';
import '../data/models/ai_message_model.dart';
import '../data/services/ai_service.dart';
import '../data/services/api_key_manager.dart';
import '../data/services/gemini_ai_service.dart';
import '../data/services/offline_sleep_engine.dart';
import '../data/services/safety_guardrails.dart';

/// Quản lý trạng thái hội thoại Trợ lý AI Giấc ngủ (AIAssistantProvider).
/// Hỗ trợ Dependency Injection đầy đủ, chống race condition khi spam gửi,
/// rào cản an toàn SafetyGuardrails, fallback ngoại tuyến kèm ngữ cảnh và tự phục hồi Online.
class AIAssistantProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  final AIService _aiService;
  final ApiKeyManager _apiKeyManager;

  List<AIMessageModel> _messages = [];
  bool _isThinking = false;
  bool _isOfflineMode = false;
  String? _offlineReason;

  AIAssistantProvider({
    DatabaseHelper? databaseHelper,
    AIService? aiService,
    ApiKeyManager? apiKeyManager,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
        _aiService = aiService ?? GeminiAIService.instance,
        _apiKeyManager = apiKeyManager ?? ApiKeyManager();

  List<AIMessageModel> get messages => List.unmodifiable(_messages);
  bool get isThinking => _isThinking;
  bool get isLoading => _isThinking; // Alias tạm giữ tương thích tới Tác vụ 7
  bool get isOfflineMode => _isOfflineMode;
  String? get offlineReason => _offlineReason;

  @visibleForTesting
  void setThinkingForTest(bool value) {
    _isThinking = value;
  }

  @visibleForTesting
  void setOfflineModeForTest(bool value, {String? reason}) {
    _isOfflineMode = value;
    _offlineReason = reason;
  }

  Future<void> loadMessages() async {
    final loaded = await _databaseHelper.getAllAIMessages();
    _messages = List<AIMessageModel>.from(loaded);
    notifyListeners();
  }

  Future<void> sendMessage(String prompt, {String? sleepSummary}) async {
    final cleanPrompt = prompt.trim();
    if (_isThinking || cleanPrompt.isEmpty) return;

    // Khóa ngay trước mọi lệnh await để chặn triệt để double-tap race condition
    _isThinking = true;
    notifyListeners();

    try {
      // 1. Chụp snapshot lịch sử TRƯỚC khi thêm tin nhắn mới của user
      final previousHistory = List<AIMessageModel>.from(_messages);

      // 2. Lưu và hiển thị tin nhắn người dùng (is_offline = 0)
      final userMsg = AIMessageModel(
        text: cleanPrompt,
        isUser: true,
        isOffline: false,
      );
      await _databaseHelper.insertAIMessage(userMsg);
      _messages.add(userMsg);
      notifyListeners();

      // 3. Tầng 1: Kiểm tra SafetyGuardrails cục bộ
      final safetyResult = SafetyGuardrails.evaluate(cleanPrompt);
      if (safetyResult.isBlocked && safetyResult.warningMessage != null) {
        final warningMsg = AIMessageModel(
          text: safetyResult.warningMessage!,
          isUser: false,
          isOffline: false, // Rào cản an toàn chủ động, không phải lỗi mạng
        );
        await _databaseHelper.insertAIMessage(warningMsg);
        _messages.add(warningMsg);
        return;
      }

      // 4. Tầng 2: Nạp API Key và gọi dịch vụ AI trực tuyến (bên trong try/catch)
      try {
        final apiKey = await _apiKeyManager.getApiKey();
        _aiService.setApiKey(apiKey);

        final responseText = await _aiService.askAssistant(
          prompt: cleanPrompt,
          sleepContext: sleepSummary,
          history: previousHistory,
        );

        // Thành công -> Tự phục hồi trạng thái Online
        _isOfflineMode = false;
        _offlineReason = null;

        final aiMsg = AIMessageModel(
          text: responseText,
          isUser: false,
          isOffline: false,
        );
        await _databaseHelper.insertAIMessage(aiMsg);
        _messages.add(aiMsg);
      } catch (e) {
        // Fallback sang bộ tri thức ngoại tuyến
        _isOfflineMode = true;
        _offlineReason = _resolveOfflineReason(e);

        final offlineReply = OfflineSleepEngine.getAdvice(
          cleanPrompt,
          sleepContext: sleepSummary,
        );
        final offlineMsg = AIMessageModel(
          text: offlineReply,
          isUser: false,
          isOffline: true,
        );
        await _databaseHelper.insertAIMessage(offlineMsg);
        _messages.add(offlineMsg);
      }
    } finally {
      _isThinking = false;
      notifyListeners();
    }
  }

  String _resolveOfflineReason(Object error) {
    if (error is TimeoutException) {
      return 'Quá thời gian phản hồi (> 10s)';
    }
    if (error is SocketException) {
      return 'Mất kết nối Internet';
    }
    if (error is AIServiceException) {
      if (error.cause is TimeoutException) {
        return 'Quá thời gian phản hồi (> 10s)';
      }
      if (error.cause is SocketException) {
        return 'Mất kết nối Internet';
      }
      if (error.statusCode == 429) {
        return 'Dịch vụ AI trực tuyến quá tải (HTTP 429)';
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Khóa API không hợp lệ hoặc hết hạn';
      }
      if (error.statusCode == null) {
        if (error.message.contains('Chưa cấu hình API Key')) {
          return 'Chưa cấu hình API Key';
        }
        return 'Không thể kết nối dịch vụ AI trực tuyến';
      }
      return 'Dịch vụ AI trực tuyến tạm gián đoạn (HTTP ${error.statusCode})';
    }
    return 'Không thể kết nối dịch vụ AI trực tuyến';
  }

  Future<void> clearHistory() async {
    if (_isThinking) return;
    await _databaseHelper.clearAllAIMessages();
    _messages.clear();
    notifyListeners();
  }
}
