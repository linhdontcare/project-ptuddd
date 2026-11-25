import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dcsleep/data/models/ai_message_model.dart';
import 'package:dcsleep/data/services/ai_service.dart';
import 'package:dcsleep/data/services/gemini_ai_service.dart';

void main() {
  group('GeminiAIService Tests', () {
    test('throws AIServiceException when API key is empty without calling HTTP', () async {
      bool httpCalled = false;
      final mockClient = MockClient((_) async {
        httpCalled = true;
        return http.Response('{}', 200);
      });

      final service = GeminiAIService(client: mockClient);
      expect(service.hasApiKey, false);

      await expectLater(
        service.askAssistant(prompt: 'Tôi khó ngủ'),
        throwsA(isA<AIServiceException>()),
      );
      expect(httpCalled, false);
    });

    test('transmits API key in x-goog-api-key header, not URL query, using gemini-2.5-flash', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '  Hãy thử kỹ thuật thở 4-7-8.  '}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiAIService(client: mockClient);
      service.setApiKey('test_secret_key');
      expect(service.hasApiKey, true);

      final res = await service.askAssistant(prompt: 'Hello');

      expect(res, 'Hãy thử kỹ thuật thở 4-7-8.');
      expect(capturedUri.toString(), contains('gemini-2.5-flash:generateContent'));
      expect(capturedUri.queryParameters.containsKey('key'), false);
      expect(capturedHeaders['x-goog-api-key'], 'test_secret_key');
      expect(capturedHeaders['Content-Type'], 'application/json');
    });

    test('includes sleepContext in system_instruction and sets thinkingBudget: 0', () async {
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Phản hồi mẫu'}
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = GeminiAIService(client: mockClient);
      service.setApiKey('test_secret_key');

      await service.askAssistant(
        prompt: 'Đánh giá giấc ngủ giúp tôi',
        sleepContext: 'Mục tiêu: 8.0 giờ. Tỷ lệ tuân thủ: 85%.',
      );

      final sysText = capturedBody['system_instruction']['parts'][0]['text'] as String;
      expect(sysText, contains('DCSleep'));
      expect(sysText, contains('Mục tiêu: 8.0 giờ. Tỷ lệ tuân thủ: 85%.'));

      final genConfig = capturedBody['generationConfig'] as Map<String, dynamic>;
      expect(genConfig['temperature'], 0.7);
      expect(genConfig['maxOutputTokens'], 1024);
      expect(genConfig['thinkingConfig']['thinkingBudget'], 0);
    });

    test('throws AIServiceException with statusCode on HTTP 429 and 401 errors', () async {
      final rateLimitClient = MockClient(
        (_) async => http.Response('{"error": "quota exceeded"}', 429),
      );
      final rateLimitService = GeminiAIService(client: rateLimitClient)
        ..setApiKey('k');

      await expectLater(
        rateLimitService.askAssistant(prompt: 'Hi'),
        throwsA(
          isA<AIServiceException>().having((e) => e.statusCode, 'statusCode', 429),
        ),
      );

      final authClient = MockClient(
        (_) async => http.Response('{"error": "invalid api key"}', 401),
      );
      final authService = GeminiAIService(client: authClient)..setApiKey('k');

      await expectLater(
        authService.askAssistant(prompt: 'Hi'),
        throwsA(
          isA<AIServiceException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('throws AIServiceException when response candidates are missing or empty', () async {
      final emptyClient = MockClient(
        (_) async => http.Response(jsonEncode({'candidates': []}), 200),
      );
      final service = GeminiAIService(client: emptyClient)..setApiKey('k');

      await expectLater(
        service.askAssistant(prompt: 'Hi'),
        throwsA(isA<AIServiceException>()),
      );
    });

    test('throws AIServiceException on request timeout', () async {
      final slowClient = MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return http.Response('{}', 200);
      });
      final service = GeminiAIService(
        client: slowClient,
        timeout: const Duration(milliseconds: 30),
      )..setApiKey('k');

      await expectLater(
        service.askAssistant(prompt: 'Hi'),
        throwsA(isA<AIServiceException>()),
      );
    });
  });

  group('GeminiAIService.buildContentsPayload Tests', () {
    test('strips leading model greeting and deduplicates trailing user messages keeping currentPrompt', () {
      final service = GeminiAIService();
      final history = [
        AIMessageModel(id: 1, text: 'Xin chào!', isUser: false),
        AIMessageModel(id: 2, text: 'Tôi mệt', isUser: true),
        AIMessageModel(id: 3, text: 'Tin user bị kẹt từ phiên trước', isUser: true),
      ];

      final contents = service.buildContentsPayload(
        history: history,
        currentPrompt: 'Câu hỏi mới của tôi',
      );

      expect(contents.length, 1);
      expect(contents.first['role'], 'user');
      expect(contents.first['parts'][0]['text'], 'Câu hỏi mới của tôi');
    });

    test('maintains strict user-model-user alternation across multi-turn history', () {
      final service = GeminiAIService();
      final history = [
        AIMessageModel(id: 1, text: 'Chào mừng', isUser: false),
        AIMessageModel(id: 2, text: 'Câu hỏi 1', isUser: true),
        AIMessageModel(id: 3, text: 'Trả lời 1', isUser: false),
        AIMessageModel(id: 4, text: 'Cảnh báo phụ', isUser: false),
        AIMessageModel(id: 5, text: 'Câu hỏi 2', isUser: true),
        AIMessageModel(id: 6, text: 'Trả lời 2', isUser: false),
      ];

      final contents = service.buildContentsPayload(
        history: history,
        currentPrompt: 'Câu hỏi 3',
      );

      expect(contents.first['role'], 'user');
      expect(contents.last['role'], 'user');
      expect(contents.last['parts'][0]['text'], 'Câu hỏi 3');

      for (int i = 0; i < contents.length - 1; i++) {
        expect(contents[i]['role'], isNot(equals(contents[i + 1]['role'])));
      }
      // Giữ phần tử mới hơn khi trùng role model (Trả lời 1 bị loại, giữ Cảnh báo phụ)
      expect(contents[1]['parts'][0]['text'], 'Cảnh báo phụ');
    });

    test('caps sliding window to at most 7 messages including currentPrompt', () {
      final service = GeminiAIService();
      final history = <AIMessageModel>[
        for (int i = 0; i < 10; i++)
          AIMessageModel(
            id: i + 1,
            text: i.isEven ? 'User $i' : 'Model $i',
            isUser: i.isEven,
          ),
      ];

      final contents = service.buildContentsPayload(
        history: history,
        currentPrompt: 'Current prompt',
      );

      expect(contents.length, lessThanOrEqualTo(7));
      expect(contents.first['role'], 'user');
      expect(contents.last['role'], 'user');
      expect(contents.last['parts'][0]['text'], 'Current prompt');
      for (int i = 0; i < contents.length - 1; i++) {
        expect(contents[i]['role'], isNot(equals(contents[i + 1]['role'])));
      }
    });
  });
}
