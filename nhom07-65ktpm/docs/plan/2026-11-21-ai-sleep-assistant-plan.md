# Kế Hoạch Triển Khai Phân Hệ AI Sleep Assistant (DCSleep)

> **Dành cho Agent/Kỹ sư triển khai:** BẮT BUỘC SỬ DỤNG SUB-SKILL: Sử dụng `superpowers:subagent-driven-development` (khuyên dùng) hoặc `superpowers:executing-plans` để thực thi kế hoạch này từng tác vụ một. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Xây dựng hoàn chỉnh phân hệ Trợ lý AI Tư vấn Giấc ngủ (AI Sleep Assistant) theo bản đặc tả v1.3, tích hợp Gemini 2.5 Flash, bộ lọc an toàn 2 lớp hỗ trợ tiếng Việt không dấu, cơ chế tự phục hồi ngoại tuyến và lưu trữ SQLite bền vững.

**Kiến trúc:** Áp dụng Strategy Pattern cho Service Layer (`AIService`), tách biệt logic gọi API khỏi quản trị trạng thái (`AIAssistantProvider`). Tầng trung gian tích hợp `SafetyGuardrails` chạy tiền kiểm tra trên máy trước khi chuyển qua `GeminiAIService` (trực tuyến) hoặc `OfflineSleepEngine` (ngoại tuyến). Dữ liệu lịch sử chat được lưu bền vững vào SQLite cục bộ (`database_helper.dart`).

**Công nghệ sử dụng:** Flutter 3.x, Dart 3.x, `provider`, `sqflite`, `http`, `flutter_secure_storage`.

**Tài liệu đặc tả (Spec):** [spec_ai_sleep_assistant.md](file:///d:/Nhom_mobile/project-ptuddd/nhom07-65ktpm/docs/plan/spec_ai_sleep_assistant.md)

---

## Ràng Buộc Toàn Cục (Global Constraints)

- **Mô hình AI:** Bắt buộc sử dụng `gemini-2.5-flash` (không dùng dòng 1.5 đã ngừng phục vụ).
- **Cấu hình Payload:** `thinkingBudget: 0`, `temperature: 0.7`, `maxOutputTokens: 1024`.
- **Bảo mật Header:** Truyền khóa API qua Header `x-goog-api-key`, không truyền qua URL query parameter `?key=...`.
- **Cửa sổ trượt (Sliding Window):** Tối đa 6 tin nhắn gần nhất; tin đầu tiên trong `contents` luôn là `user`; bắt buộc xen kẽ nghiêm ngặt `user` $\leftrightarrow$ `model`.
- **Ngữ cảnh giấc ngủ:** `[DỮ LIỆU THỰC TẾ TỪ DCSLEEP]` chỉ ghép động vào `system_instruction` của HTTP payload, tuyệt đối không lưu vào bảng `ai_chat_messages` trong SQLite.
- **Tiêu chuẩn mã nguồn:** Không có cảnh báo/lỗi trên `flutter analyze`, toàn bộ code nằm trọn vẹn trong `nhom07-65ktpm/src/`.

---

## Trọng Tâm Rà Soát (Review Focus)

1. **Chuỗi role không hợp lệ gửi tới Gemini REST API:** Khi danh sách tin nhắn bị cắt cụt bắt đầu bằng `model` hoặc có 2 tin `user` liên tiếp, API sẽ báo lỗi `400 Bad Request`.
2. **Bỏ dấu tiếng Việt trong câu hỏi nguy hiểm:** Người dùng gõ `thuoc ngu`, `ngung tho khi ngu` viết thường không dấu hoặc viết hoa phải được phát hiện 100% bởi `SafetyGuardrails`.
3. **Lỗi Migration SQLite khi cập nhật app cũ:** Thiết bị đã có database version 1 sẽ bị crash `no such column: is_offline` nếu thiếu lệnh `ALTER TABLE` trong `onUpgrade`.
4. **Treo dải banner ngoại tuyến khi mạng hồi phục:** Khi có kết nối trở lại và gọi API thành công, hệ thống phải tự động đặt lại `isOfflineMode = false` để ẩn banner.
5. **Độ trễ phản hồi quá ngưỡng:** Quá trình gọi mạng vượt quá 10 giây phải kích hoạt timeout và chuyển ngay sang `OfflineSleepEngine` với nhánh `Default Fallback`.

---

## Danh Sách Tác Vụ Triển Khai (Tasks)

### Tác Vụ 1: Nâng Cấp Model Tin Nhắn & Migration CSDL SQLite

**Tệp tin:**
- Sửa đổi: `nhom07-65ktpm/src/lib/data/models/ai_message_model.dart`
- Sửa đổi: `nhom07-65ktpm/src/lib/data/database/database_helper.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/ai_message_model_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Cơ sở dữ liệu SQLite cục bộ `dcsleep.db`.
- Cung cấp: `AIMessageModel` có thuộc tính `isOffline: bool`; `DatabaseHelper` hỗ trợ lưu và truy vấn cờ `is_offline`.

- [ ] **Bước 1: Viết bài test kiểm tra model serialization và cờ `isOffline`**
  ```dart
  // nhom07-65ktpm/src/test/ai_message_model_test.dart
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
  ```

- [ ] **Bước 2: Chạy test để xác nhận kiểm thử thất bại**
  - Chạy: `flutter test test/ai_message_model_test.dart`
  - Kết quả mong đợi: FAIL do `AIMessageModel` chưa có trường `isOffline`.

- [ ] **Bước 3: Cập nhật `AIMessageModel`**
  - Thêm thuộc tính `final bool isOffline;` với giá trị mặc định `false`.
  - Cập nhật hàm `toMap()` và `fromMap()` để đọc/ghi trường `is_offline` (1 / 0).

- [ ] **Bước 4: Cập nhật Migration trong `DatabaseHelper`**
  - Nâng `_databaseVersion` lên `2`.
  - Cập nhật câu lệnh `CREATE TABLE ai_chat_messages` bổ sung cột `is_offline INTEGER NOT NULL DEFAULT 0`.
  - Trong hàm `_onUpgrade(db, oldVersion, newVersion)`, thêm nhánh:
    ```dart
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE ai_chat_messages ADD COLUMN is_offline INTEGER NOT NULL DEFAULT 0;');
    }
    ```

- [ ] **Bước 5: Chạy lại test xác nhận vượt qua**
  - Chạy: `flutter test test/ai_message_model_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 6: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/models/ai_message_model.dart nhom07-65ktpm/src/lib/data/database/database_helper.dart nhom07-65ktpm/src/test/ai_message_model_test.dart
  git commit -m "feat(nhom07-65ktpm): bo sung cot is_offline vao ai_message_model va migration sqlite"
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
  test('SafetyGuardrails blocks medication keywords with and without accents', () {
    expect(SafetyGuardrails.evaluate('Tôi muốn mua thuốc ngủ').isBlocked, true);
    expect(SafetyGuardrails.evaluate('uong thuoc ngu lieu luong the nao').isBlocked, true);
    expect(SafetyGuardrails.evaluate('seduxen 5mg uong sao').isBlocked, true);
  });
  test('SafetyGuardrails detects red flags', () {
    expect(SafetyGuardrails.evaluate('ngung tho khi ngu co sao khong').isBlocked, true);
  });
  test('SafetyGuardrails allows normal sleep hygiene questions', () {
    expect(SafetyGuardrails.evaluate('Nên ngủ trưa bao nhiêu phút?').isBlocked, false);
  });
  ```

- [ ] **Bước 2: Chạy test để xác nhận kiểm thử thất bại**
  - Chạy: `flutter test test/safety_guardrails_test.dart`
  - Kết quả mong đợi: FAIL do chưa tạo lớp `SafetyGuardrails`.

- [ ] **Bước 3: Triển khai lớp `SafetyGuardrails`**
  - Tạo hàm tiện ích `removeDiacritics(String text)` chuyển ký tự tiếng Việt có dấu thành không dấu.
  - Định nghĩa danh sách từ khóa dược lý và dấu hiệu nguy hiểm (Red Flags).
  - So khớp song song chuỗi thường có dấu và không dấu. Trả về thông điệp từ chối chuẩn mực theo Mục 7.1 của bản đặc tả.

- [ ] **Bước 4: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/safety_guardrails_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 5: Commit**
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
  test('OfflineSleepEngine answers power nap questions', () {
    final ans = OfflineSleepEngine.getAdvice('Ngủ trưa bao nhiêu phút');
    expect(ans.contains('Power Nap'), true);
  });
  test('OfflineSleepEngine provides Default Fallback for unknown queries', () {
    final ans = OfflineSleepEngine.getAdvice('Hôm nay tôi stress quá');
    expect(ans.contains('chế độ ngoại tuyến'), true);
  });
  ```

- [ ] **Bước 2: Chạy test xác nhận kiểm thử thất bại**
  - Chạy: `flutter test test/offline_sleep_engine_test.dart`
  - Kết quả mong đợi: FAIL.

- [ ] **Bước 3: Triển khai lớp `OfflineSleepEngine`**
  - Đóng gói 4 nhánh tri thức y khoa chuẩn (Thở 4-7-8, Ngủ trưa Power Nap 15-20p, Vệ sinh Caffeine sau 14h, Trằn trọc 20 phút).
  - Bổ sung nhánh `Default Fallback` hướng dẫn người dùng sử dụng Quick Chips khi câu hỏi không thuộc 4 chủ đề trên.

- [ ] **Bước 4: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/offline_sleep_engine_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 5: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/services/offline_sleep_engine.dart nhom07-65ktpm/src/test/offline_sleep_engine_test.dart
  git commit -m "feat(nhom07-65ktpm): xay dung offline sleep engine kem default fallback"
  ```

---

### Tác Vụ 4: Tầng Dịch Vụ AI Trực Tuyến & Chuẩn Hóa Role Gemini API

**Tệp tin:**
- Tạo mới: `nhom07-65ktpm/src/lib/data/services/ai_service.dart`
- Sửa đổi: `nhom07-65ktpm/src/lib/data/services/gemini_ai_service.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/gemini_ai_service_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Model Gemini 2.5 Flash, API Key, lịch sử tin nhắn gần nhất (`history`).
- Cung cấp: Interface `AIService`, ngoại lệ `AIServiceException`, và lớp `GeminiAIService` với logic chuẩn hóa role luân phiên.

- [ ] **Bước 1: Viết test cho thuật toán chuẩn hóa Sliding Window (Tránh lỗi 400 Bad Request)**
  ```dart
  // nhom07-65ktpm/src/test/gemini_ai_service_test.dart
  test('GeminiAIService cleans history to alternate user and model, starting with user', () {
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
  });
  ```

- [ ] **Bước 2: Chạy test xác nhận kiểm thử thất bại**
  - Chạy: `flutter test test/gemini_ai_service_test.dart`
  - Kết quả mong đợi: FAIL.

- [ ] **Bước 3: Định nghĩa `ai_service.dart`**
  - Khai báo class `AIServiceException` (message, statusCode).
  - Khai báo abstract class `AIService` với hàm `askAssistant({prompt, sleepContext, history}) -> Future<String>`.

- [ ] **Bước 4: Cập nhật `GeminiAIService`**
  - Triển khai `implements AIService`.
  - Sử dụng endpoint `models/gemini-2.5-flash:generateContent`.
  - Cấu hình header `x-goog-api-key: _apiKey`.
  - Cấu hình `"generationConfig": {"temperature": 0.7, "maxOutputTokens": 1024, "thinkingConfig": {"thinkingBudget": 0}}`.
  - Cấu hình trường `"system_instruction"` tách biệt (ghép kèm ngữ cảnh `sleepContext` nếu có).
  - Cài đặt hàm `buildContentsPayload` cắt tối đa 6 tin, bỏ tin `model` ở đầu mảng, đảm bảo xen kẽ nghiêm ngặt `user` $\leftrightarrow$ `model`.
  - Khi lỗi mạng/mã HTTP $\neq$ 200, ném `AIServiceException`.

- [ ] **Bước 5: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/gemini_ai_service_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 6: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/data/services/ai_service.dart nhom07-65ktpm/src/lib/data/services/gemini_ai_service.dart nhom07-65ktpm/src/test/gemini_ai_service_test.dart
  git commit -m "feat(nhom07-65ktpm): cap nhat gemini 2.5 flash payload va chuan hoa role alternation"
  ```

---

### Tác Vụ 5: Nâng Cấp State Provider & Cơ Chế Tự Phục Hồi Online

**Tệp tin:**
- Sửa đổi: `nhom07-65ktpm/src/lib/providers/ai_assistant_provider.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/ai_assistant_provider_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: `SafetyGuardrails`, `GeminiAIService`, `OfflineSleepEngine`, `DatabaseHelper`.
- Cung cấp: State `messages`, `isThinking`, `isOfflineMode`, hàm `sendMessage()`, hàm `clearHistory()`.

- [ ] **Bước 1: Viết test cho luồng tự phục hồi Online và chặn an toàn Local Pre-filter**
  ```dart
  // nhom07-65ktpm/src/test/ai_assistant_provider_test.dart
  test('AIAssistantProvider intercepts medication query with local pre-filter without calling API', () async {
    final provider = AIAssistantProvider(databaseHelper: mockDb, aiService: mockService);
    await provider.sendMessage('Uong thuoc ngu');
    expect(provider.messages.last.isOffline, true);
    expect(provider.messages.last.text.contains('không đưa ra hướng dẫn sử dụng hoặc liều lượng các loại thuốc ngủ'), true);
  });
  test('AIAssistantProvider resets isOfflineMode to false on successful online response', () async {
    final provider = AIAssistantProvider(databaseHelper: mockDb, aiService: mockService);
    provider.setOfflineModeForTest(true);
    await provider.sendMessage('Nên ngủ mấy giờ');
    expect(provider.isOfflineMode, false);
  });
  ```

- [ ] **Bước 2: Chạy test xác nhận kiểm thử thất bại**
  - Chạy: `flutter test test/ai_assistant_provider_test.dart`
  - Kết quả mong đợi: FAIL.

- [ ] **Bước 3: Cập nhật `AIAssistantProvider`**
  - Thêm biến trạng thái `bool _isOfflineMode = false; bool get isOfflineMode => _isOfflineMode;`.
  - Luồng trong `sendMessage(prompt, {sleepSummary})`:
    1. Tạo tin nhắn người dùng, lưu vào SQLite (`is_offline = 0`).
    2. Kiểm tra `SafetyGuardrails.evaluate(prompt)`: nếu bị chặn, lấy thông điệp từ chối, lưu tin nhắn bot (`is_offline = 1`), `notifyListeners()` và kết thúc sớm.
    3. Thử gọi `_aiService.askAssistant(...)`:
       - **Thành công:** Lưu tin nhắn bot (`is_offline = 0`), đặt `_isOfflineMode = false`.
       - **Lỗi (`AIServiceException` / Exception):** Đặt `_isOfflineMode = true`, gọi `OfflineSleepEngine.getAdvice(prompt)`, lưu tin nhắn bot (`is_offline = 1`).
    4. Cập nhật `_isThinking = false` và `notifyListeners()`.
  - Triển khai `clearHistory()`: gọi `DatabaseHelper.instance.clearAllMessages()` và xóa danh sách trong bộ nhớ.

- [ ] **Bước 4: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/ai_assistant_provider_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 5: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/providers/ai_assistant_provider.dart nhom07-65ktpm/src/test/ai_assistant_provider_test.dart
  git commit -m "feat(nhom07-65ktpm): tich hop safety guardrails, offline fallback va co che auto-recovery vao provider"
  ```

---

### Tác Vụ 6: Hoàn Thiện Giao Diện Chat UI, Banner Ngoại Tuyến & Tag Phản Hồi

**Tệp tin:**
- Sửa đổi: `nhom07-65ktpm/src/lib/screens/ai_assistant/ai_assistant_screen.dart`
- Kiểm thử: `nhom07-65ktpm/src/test/ai_assistant_screen_test.dart`

**Giao diện kết nối:**
- Tiêu thụ: Trạng thái từ `AIAssistantProvider` và `SleepProvider`.
- Cung cấp: Màn hình Chat UI hoàn chỉnh với AppBar có nút Xóa lịch sử, Banner ngoại tuyến màu vàng mờ tự ẩn, Tag `[Ngoại tuyến]` trên bong bóng chat, hiệu ứng typing indicator.

- [ ] **Bước 1: Viết widget test kiểm tra hiển thị Banner Ngoại tuyến và Tag `[Ngoại tuyến]`**
  ```dart
  // nhom07-65ktpm/src/test/ai_assistant_screen_test.dart
  testWidgets('AIAssistantScreen shows yellow offline banner when isOfflineMode is true', (tester) async {
    // bơm widget với mock provider isOfflineMode = true
    await tester.pumpWidget(createTestWidget(isOfflineMode: true));
    expect(find.textContaining('Đang hoạt động ở chế độ ngoại tuyến'), findsOneWidget);
  });
  testWidgets('AIAssistantScreen shows [Ngoại tuyến] tag for offline messages', (tester) async {
    // bơm widget với 1 tin nhắn có isOffline = true
    await tester.pumpWidget(createTestWidget(hasOfflineMessage: true));
    expect(find.textContaining('[Ngoại tuyến]'), findsOneWidget);
  });
  ```

- [ ] **Bước 2: Chạy test xác nhận kiểm thử thất bại**
  - Chạy: `flutter test test/ai_assistant_screen_test.dart`
  - Kết quả mong đợi: FAIL do chưa thêm Banner và Tag.

- [ ] **Bước 3: Cập nhật `ai_assistant_screen.dart`**
  - Thêm nút Action "Xóa lịch sử" trên AppBar kèm `showDialog` xác nhận trước khi gọi `provider.clearHistory()`.
  - Hiển thị dải `Container` banner màu vàng mờ dưới AppBar khi `aiProv.isOfflineMode == true`:  
    `"⚠️ Đang hoạt động ở chế độ ngoại tuyến (Tri thức cục bộ)"`.
  - Trong bong bóng chat của AI, nếu `message.isOffline == true`, hiển thị nhãn chip nhỏ `[Ngoại tuyến]` phía trên nội dung tin nhắn.
  - Tinh chỉnh hiệu ứng hiển thị trạng thái `isThinking` (3 chấm nhảy động) và tự động cuộn xuống cuối màn hình (`_scrollToBottom`).

- [ ] **Bước 4: Chạy test xác nhận vượt qua**
  - Chạy: `flutter test test/ai_assistant_screen_test.dart`
  - Kết quả mong đợi: PASS.

- [ ] **Bước 5: Commit**
  ```bash
  git add nhom07-65ktpm/src/lib/screens/ai_assistant/ai_assistant_screen.dart nhom07-65ktpm/src/test/ai_assistant_screen_test.dart
  git commit -m "feat(nhom07-65ktpm): hoan thien giao dien chat ai kem banner ngoai tuyen va tag tin nhan"
  ```

---

### Tác Vụ 7: Tích Hợp Kiểm Thử Toàn Diện & Đánh Giá Tiêu Chí Nghiệm Thu (Acceptance Test)

**Tệp tin:**
- Kiểm thử tích hợp: `nhom07-65ktpm/src/test/ai_assistant_integration_test.dart`

**Giao diện kết nối:**
- Kiểm thử toàn diện 8 tiêu chí nghiệm thu từ Mục 8 của bản đặc tả kỹ thuật.

- [ ] **Bước 1: Viết test tích hợp end-to-end kiểm tra toàn bộ luồng hoạt động**
  - Kiểm tra gửi nhận tin nhắn bình thường.
  - Kiểm tra câu hỏi chứa từ khóa `thuoc ngu` bị chặn ngay bởi Pre-filter.
  - Kiểm tra ngắt mạng kích hoạt `OfflineSleepEngine` và hiển thị banner ngoại tuyến.
  - Kiểm tra khôi phục lịch sử từ SQLite sau khi khởi động lại app.

- [ ] **Bước 2: Chạy toàn bộ test suite của dự án**
  - Chạy: `cd nhom07-65ktpm/src && flutter test`
  - Kết quả mong đợi: Toàn bộ tests PASS.

- [ ] **Bước 3: Chạy phân tích tĩnh mã nguồn**
  - Chạy: `cd nhom07-65ktpm/src && flutter analyze`
  - Kết quả mong đợi: No issues found (hoặc 0 errors, 0 warnings nghiêm trọng).

- [ ] **Bước 4: Commit tài liệu và hoàn tất nhánh tính năng**
  ```bash
  git add nhom07-65ktpm/src/
  git commit -m "test(nhom07-65ktpm): hoan tat kiem thu toan dien phan he ai sleep assistant dat chuan nghiem thu"
  ```
