# Kế Hoạch Triển Khai Phân Hệ AI Sleep Assistant (DCSleep) - v1.4

> **Dành cho Agent/Kỹ sư triển khai:** BẮT BUỘC SỬ DỤNG SUB-SKILL: Sử dụng `superpowers:subagent-driven-development` (khuyên dùng) hoặc `superpowers:executing-plans` để thực thi kế hoạch này từng tác vụ một. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Xây dựng hoàn chỉnh phân hệ Trợ lý AI Tư vấn Giấc ngủ (AI Sleep Assistant) theo bản đặc tả v1.3, tích hợp Gemini 2.5 Flash, quản lý khóa an toàn qua `flutter_secure_storage`, bộ lọc an toàn 2 lớp hỗ trợ tiếng Việt không dấu, cơ chế tự phục hồi ngoại tuyến và lưu trữ SQLite bền vững.

**Phạm vi triển khai (Scope Clarification):** Đợt triển khai này tập trung 100% vào việc hoàn thiện và tối ưu `GeminiAIService` (Gemini 2.5 Flash) cùng bộ dự phòng `OfflineSleepEngine`. Phân hệ `OpenAIService` (Mục 2.3 của spec) nằm ngoài phạm vi thực thi đợt này, đã được mở sẵn cổng chờ kết nối thông qua interface `AIService`.

**Kiến trúc:** Áp dụng Strategy Pattern và Dependency Injection (DI) cho Service Layer (`AIService`), tách biệt hoàn toàn khỏi `AIAssistantProvider`. Dữ liệu được bảo vệ 2 tầng qua `SafetyGuardrails` (chạy trên máy) và `OfflineSleepEngine` (khi mạng lỗi). Khóa API được quản lý tập trung bởi `ApiKeyManager`. Toàn bộ lịch sử chat được lưu trữ bền vững trong SQLite cục bộ (`database_helper.dart`).

**Công nghệ sử dụng:** Flutter 3.x, Dart 3.x, `provider`, `sqflite`, `sqflite_common_ffi` (cho unit test trên máy tính), `http`, `flutter_secure_storage`.

**Tài liệu đặc tả (Spec):** [spec_ai_sleep_assistant.md](file:///d:/Nhom_mobile/project-ptuddd/nhom07-65ktpm/docs/spec/spec_ai_sleep_assistant.md)

---

## Ràng Buộc Toàn Cục (Global Constraints)

- **Mô hình AI:** Bắt buộc sử dụng `gemini-2.5-flash` (không dùng dòng 1.5 đã ngừng phục vụ).
- **Cấu hình Payload:** `thinkingBudget: 0`, `temperature: 0.7`, `maxOutputTokens: 1024`.
- **Thời gian chờ (Timeout):** Gắn cứng `.timeout(const Duration(seconds: 10))` cho mọi request HTTP gọi API trực tuyến.
- **Bảo mật Header:** Truyền khóa API qua Header `x-goog-api-key`, tuyệt đối không truyền qua URL query parameter `?key=...`.
- **Cửa sổ trượt (Sliding Window):** Tối đa 6 tin nhắn gần nhất; tin đầu tiên trong `contents` luôn là `user`; bắt buộc xen kẽ nghiêm ngặt `user` $\leftrightarrow$ `model`.
- **Ngữ cảnh giấc ngủ:** `[DỮ LIỆU THỰC TẾ TỪ DCSLEEP]` chỉ ghép động vào `system_instruction` của HTTP payload, tuyệt đối không lưu vào bảng `ai_chat_messages` trong SQLite.
- **Dependency Injection:** `AIAssistantProvider` không gọi cứng `DatabaseHelper.instance` hay `GeminiAIService.instance` mà nhận qua constructor (có default value) để đảm bảo unit test mock 100%.
- **Tiêu chuẩn mã nguồn:** Không có cảnh báo/lỗi trên `flutter analyze`, toàn bộ code nằm trọn vẹn trong `nhom07-65ktpm/src/`.

---

## Trọng Tâm Rà Soát (Review Focus)

1. **Chuỗi role không hợp lệ & Trùng lặp tin nhắn cuối:** Nếu snapshot lịch sử chat sau khi thêm tin nhắn mới của user, mảng `contents` sẽ chứa 2 tin `user` liên tiếp ở cuối $\rightarrow$ API bắn lỗi `400 Bad Request`. Khắc phục: Snapshot `previousHistory` trước khi add tin nhắn mới, kèm bước sanitize role trong `buildContentsPayload`.
2. **Crash `MissingPluginException` khi chạy test SQLite trên máy tính:** Khi chạy `flutter test`, `sqflite` thiếu platform channel của Android/iOS. Khắc phục: Sử dụng `sqflite_common_ffi` (`sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`) trong `setUpAll`.
3. **Gắn nhầm nhãn `[Ngoại tuyến]` cho cảnh báo y tế:** Phản hồi từ `SafetyGuardrails` là cơ chế an toàn chủ động, điện thoại vẫn có mạng bình thường. Khắc phục: Chỉ gán `isOffline: true` khi câu trả lời thực sự do `OfflineSleepEngine` sinh ra.
4. **Bỏ dấu tiếng Việt trong từ khóa cấm:** Người dùng gõ `thuoc ngu`, `ngung tho khi ngu` viết thường không dấu hoặc viết hoa phải được phát hiện 100% bởi `SafetyGuardrails`.
5. **Độ trễ và Banner treo khi mạng phục hồi:** Mạng chập chờn $\rightarrow$ hiển thị banner kèm đúng nguyên nhân (`_offlineReason`); khi mạng có lại và gửi thành công $\rightarrow$ tự động ẩn banner (`_isOfflineMode = false`).

---

## Danh Sách Tác Vụ Triển Khai (Tasks)

### Tác Vụ 1: Bổ Sung Dependencies, Nâng Cấp Model & Migration SQLite FFI

**Tệp tin:**
- Sửa đổi: `nhom07-65ktpm/src/pubspec.yaml`
- Sửa đổi: `nhom07-65ktpm/src/lib/data/models/ai_message_model.dart`
- Sửa đổi: `nhom07-65ktpm/src/lib/data/database/database_helper.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/ai_message_model_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: `sqflite`, `sqflite_common_ffi`, `flutter_secure_storage`.
- Cung cấp: `AIMessageModel` có thuộc tính `isOffline: bool`; `DatabaseHelper` hỗ trợ lưu và truy vấn cờ `is_offline`, cho phép tiêm database/factory phục vụ unit test.

- [ ] **Bước 1: Bổ sung dependencies vào `pubspec.yaml`**
  - Thêm `flutter_secure_storage: ^9.2.2` vào mục `dependencies:`.
  - Thêm `sqflite_common_ffi: ^2.3.4+4` vào mục `dev_dependencies:`.
  - Chạy: `flutter pub get`.

- [ ] **Bước 2: Viết test kiểm tra serialization của `AIMessageModel`**
  ```dart
  // nhom07-65ktpm/src/test/ai_message_model_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:dcsleep/data/models/ai_message_model.dart';

  void main() {
    test('AIMessageModel serialization includes isOffline flag', () {
      final msg = AIMessageModel(
        id: 1,
        text: 'Thở 4-7-8',
        isUser: false,
        isOffline: true,
        timestamp: DateTime.parse('2026-11-21T08:00:00'),
      );
      final map = msg.toMap();
      expect(map['is_offline'], 1);
      final fromMap = AIMessageModel.fromMap(map);
      expect(fromMap.isOffline, true);
    });
  }
  ```

- [ ] **Bước 3: Cập nhật `AIMessageModel`**
  - Thêm thuộc tính `final bool isOffline;` với giá trị mặc định `false`.
  - Cập nhật hàm `toMap()` ghi `is_offline: isOffline ? 1 : 0`.
  - Cập nhật hàm `fromMap()` đọc `isOffline: (map['is_offline'] as int?) == 1`.

- [ ] **Bước 4: Cập nhật `DatabaseHelper` với Migration an toàn và hỗ trợ FFI**
  - Nâng `_databaseVersion` lên `2`.
  - Bổ sung `is_offline INTEGER NOT NULL DEFAULT 0` vào câu lệnh `CREATE TABLE ai_chat_messages`.
  - Trong `_onUpgrade(db, oldVersion, newVersion)`, thêm:
    ```dart
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE ai_chat_messages ADD COLUMN is_offline INTEGER NOT NULL DEFAULT 0;');
    }
    ```
  - Cập nhật hàm `insertAIMessage`, `getAllAIMessages` để lưu/đọc chính xác trường `is_offline`.

- [ ] **Bước 5: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/ai_message_model_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 6: Commit**
  ```bash
  git add nhom07-65ktpm/src/pubspec.yaml nhom07-65ktpm/src/pubspec.lock nhom07-65ktpm/src/lib/data/models/ai_message_model.dart nhom07-65ktpm/src/lib/data/database/database_helper.dart nhom07-65ktpm/src/test/ai_message_model_test.dart
  git commit -m "feat(nhom07-65ktpm): bo sung dependencies, cot is_offline model va migration sqlite"
  ```

---

### Tác Vụ 2: Xây Dựng Bộ Lọc An Toàn Tiền Xử Lý (Safety Guardrails)

**Tệp tin:**
- Tạo mới: `nhom07-65ktpm/src/lib/data/services/safety_guardrails.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/safety_guardrails_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Chuỗi văn bản prompt của người dùng.
- Cung cấp: Hàm `SafetyGuardrails.evaluate(String prompt) -> SafetyCheckResult` trả về cảnh báo nếu phát hiện dược lý / red flags.

- [ ] **Bước 1: Viết test cho bộ lọc an toàn với cả tiếng Việt có dấu và không dấu**
  ```dart
  // nhom07-65ktpm/src/test/safety_guardrails_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:dcsleep/data/services/safety_guardrails.dart';

  void main() {
    test('SafetyGuardrails blocks medication keywords with and without accents', () {
      expect(SafetyGuardrails.evaluate('Tôi muốn mua thuốc ngủ').isBlocked, true);
      expect(SafetyGuardrails.evaluate('uong thuoc ngu lieu luong the nao').isBlocked, true);
      expect(SafetyGuardrails.evaluate('seduxen 5mg uong sao').isBlocked, true);
      expect(SafetyGuardrails.evaluate('uong stilnox hay diazepam').isBlocked, true);
    });
    test('SafetyGuardrails detects red flags', () {
      expect(SafetyGuardrails.evaluate('ngung tho khi ngu co sao khong').isBlocked, true);
      expect(SafetyGuardrails.evaluate('Ngưng thở khi ngủ có nguy hiểm không').isBlocked, true);
    });
    test('SafetyGuardrails allows normal sleep hygiene questions', () {
      expect(SafetyGuardrails.evaluate('Nên ngủ trưa bao nhiêu phút?').isBlocked, false);
      expect(SafetyGuardrails.evaluate('uong ca phe sau may gio').isBlocked, false);
    });
  }
  ```

- [ ] **Bước 2: Triển khai lớp `SafetyGuardrails`**
  - Tạo hàm tiện ích `removeDiacritics(String text)` loại bỏ toàn bộ dấu tiếng Việt.
  - Danh sách từ khóa cấm: `thuốc ngủ`, `thuoc ngu`, `thuốc an thần`, `thuoc an than`, `seduxen`, `stilnox`, `zolpidem`, `diazepam`, `rotunda`, `uống thuốc gì`, `uong thuoc gi`, `liều lượng thuốc`, `lieu luong thuoc`.
  - Danh sách Red Flags: `ngưng thở khi ngủ`, `ngung tho khi ngu`, `co giật`, `co giat`, `ảo giác`, `ao giac`, `suy nhược cấp`, `suy nhuoc cap`, `mất ngủ kinh niên`, `mat ngu kinh nien`.
  - Trả về `SafetyCheckResult(isBlocked: true, warningMessage: '...')` khi vi phạm.

- [ ] **Bước 3: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/safety_guardrails_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 4: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/services/safety_guardrails.dart nhom07-65ktpm/src/test/safety_guardrails_test.dart
  git commit -m "feat(nhom07-65ktpm): trien khai bo loc an toan 2 lop safety guardrails ho tro tieng viet khong dau"
  ```

---

### Tác Vụ 3: Hoàn Thiện Bộ Tri Thức Chuyên Gia Ngoại Tuyến (OfflineSleepEngine)

**Tệp tin:**
- Tạo mới: `nhom07-65ktpm/src/lib/data/services/offline_sleep_engine.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/offline_sleep_engine_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Chuỗi prompt của người dùng.
- Cung cấp: Hàm `OfflineSleepEngine.getAdvice(String prompt) -> String` cung cấp câu trả lời ngoại tuyến tức thì cho 4 chủ đề và nhánh Default Fallback.

- [ ] **Bước 1: Viết test cho 4 chủ đề giấc ngủ và nhánh Default Fallback**
  ```dart
  // nhom07-65ktpm/src/test/offline_sleep_engine_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:dcsleep/data/services/offline_sleep_engine.dart';

  void main() {
    test('OfflineSleepEngine answers power nap questions', () {
      final ans = OfflineSleepEngine.getAdvice('Ngủ trưa bao nhiêu phút');
      expect(ans.contains('Power Nap'), true);
    });
    test('OfflineSleepEngine provides Default Fallback for unknown queries', () {
      final ans = OfflineSleepEngine.getAdvice('Hôm nay tôi stress quá');
      expect(ans.contains('chế độ ngoại tuyến'), true);
      expect(ans.contains('kỹ thuật thở 4-7-8'), true);
    });
  }
  ```

- [ ] **Bước 2: Triển khai lớp `OfflineSleepEngine`**
  - Đóng gói 4 nhánh tri thức y khoa chuẩn (Thở 4-7-8, Ngủ trưa Power Nap 15-20p, Vệ sinh Caffeine sau 14h, Trằn trọc 20 phút).
  - Bổ sung nhánh `Default Fallback` hướng dẫn người dùng sử dụng Quick Chips khi câu hỏi không thuộc 4 chủ đề trên.

- [ ] **Bước 3: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/offline_sleep_engine_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 4: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/services/offline_sleep_engine.dart nhom07-65ktpm/src/test/offline_sleep_engine_test.dart
  git commit -m "feat(nhom07-65ktpm): xay dung offline sleep engine kem default fallback"
  ```

---

### Tác Vụ 4: Quản Lý Khóa API An Toàn (ApiKeyManager)

**Tệp tin:**
- Tạo mới: `nhom07-65ktpm/src/lib/data/services/api_key_manager.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/api_key_manager_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: `flutter_secure_storage`.
- Cung cấp: Lớp `ApiKeyManager` với các hàm `getApiKey()`, `saveCustomApiKey()`, `clearCustomApiKey()`.

- [ ] **Bước 1: Viết test cho luồng ưu tiên đọc API Key**
  ```dart
  // nhom07-65ktpm/src/test/api_key_manager_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:dcsleep/data/services/api_key_manager.dart';

  void main() {
    test('ApiKeyManager fallback to environment key when storage is empty', () async {
      final manager = ApiKeyManager(mockStorage: mockEmptyStorage);
      final key = await manager.getApiKey();
      expect(key, isNotNull); // đọc từ const String.fromEnvironment
    });
  }
  ```

- [ ] **Bước 2: Triển khai `ApiKeyManager`**
  - Sử dụng `FlutterSecureStorage` để lưu trữ key của người dùng với khóa `'user_gemini_api_key'`.
  - Luồng `getApiKey()`:
    1. Kiểm tra key trong `FlutterSecureStorage`.
    2. Nếu có và không rỗng $\rightarrow$ trả về key này.
    3. Nếu không có $\rightarrow$ fallback về `const String.fromEnvironment('GEMINI_API_KEY')`.
  - Cung cấp `saveCustomApiKey(String key)` và `clearCustomApiKey()`.

- [ ] **Bước 3: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/api_key_manager_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 4: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/services/api_key_manager.dart nhom07-65ktpm/src/test/api_key_manager_test.dart
  git commit -m "feat(nhom07-65ktpm): trien khai api key manager voi flutter_secure_storage va environment fallback"
  ```

---

### Tác Vụ 5: Tầng Dịch Vụ AI Trực Tuyến & Chuẩn Hóa Role Gemini API

**Tệp tin:**
- Tạo mới: `nhom07-65ktpm/src/lib/data/services/ai_service.dart`
- Sửa đổi: `nhom07-65ktpm/src/lib/data/services/gemini_ai_service.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/gemini_ai_service_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Model Gemini 2.5 Flash, API Key, lịch sử tin nhắn gần nhất (`history`).
- Cung cấp: Interface `AIService`, ngoại lệ `AIServiceException`, và lớp `GeminiAIService`.

- [ ] **Bước 1: Viết test cho thuật toán chuẩn hóa Sliding Window & Timeout 10s**
  ```dart
  // nhom07-65ktpm/src/test/gemini_ai_service_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:dcsleep/data/services/gemini_ai_service.dart';
  import 'package:dcsleep/data/models/ai_message_model.dart';

  void main() {
    test('GeminiAIService cleans history: starts with user and alternates strictly', () {
      final history = [
        AIMessageModel(id: 1, text: 'Hi', isUser: false, timestamp: DateTime.now()), // bot chào
        AIMessageModel(id: 2, text: 'Kho khó ngủ', isUser: true, timestamp: DateTime.now()),
        AIMessageModel(id: 3, text: 'Bạn thử thở 478', isUser: false, timestamp: DateTime.now()),
      ];
      final contents = GeminiAIService.instance.buildContentsPayload(
        history: history,
        currentPrompt: 'Thở thế nào?',
      );
      expect(contents.first['role'], 'user');
      expect(contents.last['role'], 'user');
      for (int i = 0; i < contents.length - 1; i++) {
        expect(contents[i]['role'], isNot(equals(contents[i + 1]['role'])));
      }
    });
    test('GeminiAIService throws AIServiceException when apiKey is empty', () async {
      GeminiAIService.instance.setApiKey('');
      expect(
        () => GeminiAIService.instance.askAssistant(prompt: 'Test'),
        throwsA(isA<AIServiceException>()),
      );
    });
  }
  ```

- [ ] **Bước 2: Định nghĩa `ai_service.dart`**
  - Khai báo class `AIServiceException` (message, statusCode).
  - Khai báo abstract class `AIService` với hàm `askAssistant({prompt, sleepContext, history}) -> Future<String>`.

- [ ] **Bước 3: Cập nhật `GeminiAIService`**
  - Triển khai `implements AIService`.
  - Sử dụng endpoint `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`.
  - Kiểm tra sớm: `if (!hasApiKey) throw AIServiceException('Chưa cấu hình API Key');`.
  - Gắn Header `x-goog-api-key: _apiKey` (tuyệt đối không truyền `?key=` trên URL).
  - Cấu hình `"generationConfig": {"temperature": 0.7, "maxOutputTokens": 1024, "thinkingConfig": {"thinkingBudget": 0}}`.
  - Cấu hình trường `"system_instruction"` tách biệt (ghép kèm ngữ cảnh `sleepContext` nếu có).
  - Cài đặt `buildContentsPayload`:
    1. Cắt tối đa 6 tin từ `history`.
    2. Bỏ tin nhắn chào mở đầu (nếu là `model`).
    3. Khử trùng lặp: nếu 2 tin cùng role liên tiếp, chỉ giữ tin mới nhất.
    4. Thêm tin nhắn hiện tại `{"role": "user", "parts": [{"text": currentPrompt}]}` vào cuối.
  - Gọi HTTP với `.timeout(const Duration(seconds: 10))`.
  - Xử lý mã phản hồi: nếu $\neq 200$, ném `AIServiceException` với mã lỗi tương ứng.

- [ ] **Bước 4: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/gemini_ai_service_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 5: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/services/ai_service.dart nhom07-65ktpm/src/lib/data/services/gemini_ai_service.dart nhom07-65ktpm/src/test/gemini_ai_service_test.dart
  git commit -m "feat(nhom07-65ktpm): cap nhat gemini 2.5 flash payload, header auth, timeout va role sanitizer"
  ```

---

### Tác Vụ 6: Nâng Cấp State Provider & Cơ Chế Tự Phục Hồi Online

**Tệp tin:**
- Sửa đổi: `nhom07-65ktpm/src/lib/providers/ai_assistant_provider.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/ai_assistant_provider_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: `SafetyGuardrails`, `GeminiAIService`, `OfflineSleepEngine`, `DatabaseHelper` (nhận qua constructor).
- Cung cấp: State `messages`, `isThinking`, `isOfflineMode`, `offlineReason`, hàm `sendMessage()`, hàm `clearHistory()`.

- [ ] **Bước 1: Viết test cho Provider với Constructor Injection và Auto-recovery**
  ```dart
  // nhom07-65ktpm/src/test/ai_assistant_provider_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:dcsleep/providers/ai_assistant_provider.dart';

  void main() {
    test('AIAssistantProvider sets isOffline = false for SafetyGuardrails warning', () async {
      final provider = AIAssistantProvider(databaseHelper: mockDb, aiService: mockService);
      await provider.sendMessage('Uong thuoc ngu');
      expect(provider.messages.last.isOffline, false); // Không phải lỗi mạng, không gắn tag ngoại tuyến
    });
    test('AIAssistantProvider resets isOfflineMode and offlineReason on successful response', () async {
      final provider = AIAssistantProvider(databaseHelper: mockDb, aiService: mockService);
      provider.setOfflineModeForTest(true, reason: 'Mất mạng');
      await provider.sendMessage('Nên ngủ mấy giờ');
      expect(provider.isOfflineMode, false);
      expect(provider.offlineReason, isNull);
    });
  }
  ```

- [ ] **Bước 2: Cập nhật `AIAssistantProvider`**
  - Chuyển sang sử dụng Constructor Injection:
    ```dart
    AIAssistantProvider({
      DatabaseHelper? databaseHelper,
      AIService? aiService,
      ApiKeyManager? apiKeyManager,
    }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
         _aiService = aiService ?? GeminiAIService.instance,
         _apiKeyManager = apiKeyManager ?? ApiKeyManager();
    ```
  - Khai báo state:
    - `bool _isOfflineMode = false; bool get isOfflineMode => _isOfflineMode;`
    - `String? _offlineReason; String? get offlineReason => _offlineReason;`
  - Luồng trong `sendMessage(prompt, {sleepSummary})`:
    1. Chụp snapshot lịch sử trước khi thêm tin mới:
       `final previousHistory = List<AIMessageModel>.from(_messages);`
    2. Thêm tin nhắn người dùng vào danh sách và lưu vào SQLite (`is_offline = 0`).
    3. Kiểm tra `SafetyGuardrails.evaluate(prompt)`:
       - Nếu vi phạm: Thêm tin nhắn cảnh báo bot vào danh sách, lưu SQLite với **`is_offline = 0`** (vì không phải lỗi mạng), notifyListeners và return.
    4. Cập nhật `_isThinking = true; notifyListeners();`.
    5. Nạp API Key qua `_apiKeyManager.getApiKey()` và set vào `_aiService`.
    6. Khối `try / catch`:
       - **Thử gọi Online:**
         ```dart
         final response = await _aiService.askAssistant(
           prompt: prompt,
           sleepContext: sleepSummary,
           history: previousHistory,
         );
         _isOfflineMode = false;
         _offlineReason = null;
         // Lưu tin nhắn bot với is_offline = 0
         ```
       - **Bắt ngoại lệ (`AIServiceException` / Exception):**
         ```dart
         _isOfflineMode = true;
         if (e is AIServiceException && e.statusCode == 429) {
           _offlineReason = 'Dịch vụ AI trực tuyến quá tải (HTTP 429)';
         } else if (e is AIServiceException && (e.statusCode == 401 || e.statusCode == 403)) {
           _offlineReason = 'Khóa API không hợp lệ hoặc hết hạn';
         } else if (e.toString().contains('TimeoutException')) {
           _offlineReason = 'Quá thời gian phản hồi (> 10s)';
         } else {
           _offlineReason = 'Mất kết nối Internet hoặc chưa có API Key';
         }
         final offlineReply = OfflineSleepEngine.getAdvice(prompt);
         // Lưu tin nhắn bot với is_offline = 1
         ```
    7. `_isThinking = false; notifyListeners();`.
  - Triển khai `clearHistory()`: gọi `_databaseHelper.clearAllAIMessages()` (không gọi static singleton) và làm mới danh sách `_messages`.

- [ ] **Bước 3: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/ai_assistant_provider_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 4: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/providers/ai_assistant_provider.dart nhom07-65ktpm/src/test/ai_assistant_provider_test.dart
  git commit -m "feat(nhom07-65ktpm): nang cap ai_assistant_provider voi di, history snapshot va offline reason"
  ```

---

### Tác Vụ 7: Hoàn Thiện Giao Diện Chat UI (AIAssistantScreen) & Tích Hợp SleepContext

**Tệp tin:**
- Sửa đổi: `nhom07-65ktpm/src/lib/screens/ai_assistant/ai_assistant_screen.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/ai_assistant_screen_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Trạng thái từ `AIAssistantProvider` và `SleepProvider`.
- Cung cấp: Màn hình Chat UI hoàn chỉnh với AppBar có nút Xóa lịch sử (kèm Confirm Dialog), Banner ngoại tuyến hiển thị đúng nguyên nhân `_offlineReason`, Tag `[Ngoại tuyến]` trên tin nhắn, Medical Disclaimer cố định ở chân màn hình, và kích hoạt gửi câu hỏi khi bấm Quick Chips.

- [ ] **Bước 1: Viết widget test kiểm tra hiển thị Banner Ngoại tuyến, Reason và Disclaimer**
  ```dart
  // nhom07-65ktpm/src/test/ai_assistant_screen_test.dart
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    testWidgets('AIAssistantScreen displays offline banner with specific reason', (tester) async {
      // Bơm widget với mock provider isOfflineMode = true, offlineReason = 'Mất kết nối Internet'
      // Kiểm tra tìm thấy text banner
    });
    testWidgets('AIAssistantScreen displays fixed Medical Disclaimer', (tester) async {
      // Kiểm tra tìm thấy dòng khuyến cáo y tế ở chân màn hình
    });
  }
  ```

- [ ] **Bước 2: Cập nhật `ai_assistant_screen.dart`**
  - Nút Action "Xóa lịch sử" trên AppBar: hiển thị `AlertDialog` xác nhận trước khi gọi `provider.clearHistory()`.
  - Dải Banner Ngoại tuyến dưới AppBar:
    ```dart
    if (aiProv.isOfflineMode)
      Container(
        color: Colors.amber.shade900.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠️ Chế độ ngoại tuyến: ${aiProv.offlineReason ?? "Tri thức cục bộ"}',
                style: const TextStyle(fontSize: 12, color: Colors.amber),
              ),
            ),
          ],
        ),
      ),
    ```
  - Xử lý Quick Chips: Khi bấm vào chip, tự động gọi `_handleSend(chipText)`.
  - Hàm `_handleSend([String? presetText])`:
    - Trích xuất dữ liệu từ `SleepProvider`:
      `final summary = 'Mục tiêu: ${sleepProv.goal.targetDurationHours}h. Tỷ lệ tuân thủ: ${sleepProv.complianceRate.round()}%.';`
    - Gọi `aiProv.sendMessage(text, sleepSummary: summary)`.
  - Bong bóng tin nhắn:
    - Nếu `message.isOffline == true`: hiển thị nhãn chip nhỏ `[Ngoại tuyến]` màu xám trên đầu bong bóng bot.
  - Chân trang màn hình (dưới ô nhập chat): Thêm dòng Medical Disclaimer cố định:  
    *“DCSleep AI cung cấp kiến thức vệ sinh giấc ngủ nhằm xây dựng thói quen khoa học, không thay thế chẩn đoán y tế.”*

- [ ] **Bước 3: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/ai_assistant_screen_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 4: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/screens/ai_assistant/ai_assistant_screen.dart nhom07-65ktpm/src/test/ai_assistant_screen_test.dart
  git commit -m "feat(nhom07-65ktpm): hoan thien ai_assistant_screen voi banner ly do offline va disclaimer co dinh"
  ```

---

### Tác Vụ 8: Tích Hợp Kiểm Thử Toàn Diện & Nghiệm Thu Tiêu Chí

**Tệp tin:**
- Kiểm thử tích hợp: `nhom07-65ktpm/src/test/ai_assistant_integration_test.dart`

**Giao diện kết nối:**
- Kiểm thử toàn diện 8 tiêu chí nghiệm thu từ Mục 8 của bản đặc tả kỹ thuật với `sqflite_common_ffi`.

- [ ] **Bước 1: Viết test tích hợp end-to-end với SQLite FFI**
  ```dart
  // nhom07-65ktpm/src/test/ai_assistant_integration_test.dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:sqflite_common_ffi/sqflite_ffi.dart';

  void main() {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('End-to-end flow: safe prompt, medication block, and offline fallback', () async {
      // Kiểm thử toàn bộ 8 tiêu chí nghiệm thu
    });
  }
  ```

- [ ] **Bước 2: Chạy toàn bộ test suite của dự án**
  - Chạy: `cd nhom07-65ktpm/src && flutter test`
  - Kết quả mong đợi: 100% tests PASS.

- [ ] **Bước 3: Chạy phân tích tĩnh mã nguồn**
  - Chạy: `cd nhom07-65ktpm/src && flutter analyze`
  - Kết quả mong đợi: No issues found (0 errors, 0 warnings).

- [ ] **Bước 4: Commit hoàn tất toàn bộ phân hệ**
  ```bash
  git add nhom07-65ktpm/src/
  git commit -m "test(nhom07-65ktpm): hoan tat kiem thu toan dien phan he ai sleep assistant dat chuan nghiem thu"
  ```
