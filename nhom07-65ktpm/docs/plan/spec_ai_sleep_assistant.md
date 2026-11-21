# ĐẶC TẢ KỸ THUẬT PHÂN HỆ: TRỢ LÝ AI TƯ VẤN GIẤC NGỦ (AI SLEEP ASSISTANT)

> **Dự án:** DCSleep – Ứng dụng Hỗ trợ Xây dựng Kỷ luật và Cải thiện Thói quen Ngủ bằng Trí tuệ Nhân tạo  
> **Học phần:** Phát triển ứng dụng cho các thiết bị di động (PTUDDD)  
> **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường  
> **Lớp sinh hoạt:** 65KTPM – Nhóm 07  
> **Sinh viên phụ trách:** **Dương Quốc Vượng** (Mã sinh viên: **2351170634** – Thành viên)  
> **Phiên bản tài liệu:** 1.0  
> **Ngày phê duyệt:** 21/11/2026  

---

## 1. TỔNG QUAN VÀ MỤC TIÊU PHÂN HỆ

### 1.1. Bối cảnh
Trong hệ thống DCSleep, người dùng (đặc biệt là sinh viên và người đi làm) thường gặp các vấn đề đa dạng về giấc ngủ như: khó vào giấc, thức khuya do áp lực học tập, sử dụng thiết bị điện tử ban đêm, hoặc ngủ trưa sai cách dẫn đến mệt mỏi. Phân hệ **AI Sleep Assistant** đóng vai trò là một người bạn đồng hành 24/7, cung cấp giải pháp tư vấn khoa học dựa trên phương pháp Vệ sinh giấc ngủ (Sleep Hygiene) và nhịp sinh học (Circadian Rhythm).

### 1.2. Mục tiêu chức năng
1. Cung cấp giao diện trò chuyện dạng hội thoại trực quan (Chat UI) thân thiện, dễ sử dụng.
2. Tích hợp mô hình ngôn ngữ lớn (LLM) thông qua lớp dịch vụ (Service Layer) hỗ trợ Google Gemini API (ưu tiên mặc định) và có kiến trúc mở rộng cho OpenAI API.
3. Kỹ thuật Prompt cá nhân hóa: Tự động trích xuất dữ liệu nhật ký giấc ngủ (thời lượng ngủ, tỷ lệ tuân thủ) của người dùng để làm ngữ cảnh trả lời (Context-aware responses).
4. Khả năng chịu lỗi và chạy ngoại tuyến 100%: Tích hợp hệ tri thức chuyên gia dự phòng (Offline Expert Knowledge Base) giúp ứng dụng không bao giờ bị gián đoạn ngay cả khi không có kết nối Internet hoặc lỗi API.
5. Thiết lập rào cản y đức và an toàn (Safety Guardrails): Bắt buộc đính kèm tuyên bố miễn trừ y tế, từ chối kê đơn thuốc ngủ và cảnh báo người dùng đến cơ sở y tế khi có dấu hiệu bệnh lý nghiêm trọng.
6. Lưu trữ dữ liệu lịch sử hội thoại vào cơ sở dữ liệu SQLite cục bộ.

---

## 2. KIẾN TRÚC TẦNG DỊCH VỤ (SERVICE LAYER ARCHITECTURE)

Áp dụng mẫu thiết kế **Strategy Pattern** và **Service Abstraction** nhằm cô lập hoàn toàn logic gọi API với tầng giao diện (UI) và quản lý trạng thái (`Provider`).

```
┌────────────────────────────────────────────────────────┐
│                   AIAssistantScreen                    │
└───────────────────────────┬────────────────────────────┘
                            │ (Lắng nghe State)
┌───────────────────────────▼────────────────────────────┘
│                  AIAssistantProvider                   │
└───────────────────────────┬────────────────────────────┘
                            │ (Gọi hàm trừu tượng)
┌───────────────────────────▼────────────────────────────┘
│                     «interface»                        │
│                      AIService                         │
│  + askAssistant(prompt, context): Future<String>       │
└───────────────▲────────────────────────▲───────────────┘
                │                        │
┌───────────────┴──────────────┐ ┌───────┴───────────────┐
│       GeminiAIService        │ │        OpenAIService  │
│  - Model: gemini-1.5-flash   │ │  - Model: gpt-4o-mini │
│  - REST Endpoint / SDK       │ │  - REST Endpoint      │
└──────────────────────────────┘ └───────────────────────┘
```

### 2.1. Định nghĩa Interface chung (`ai_service.dart`)
```dart
abstract class AIService {
  Future<String> askAssistant({
    required String prompt,
    String? sleepContext,
  });

  void setApiKey(String key);
  bool get hasApiKey;
}
```

### 2.2. Triển khai Gemini Service (`gemini_ai_service.dart` - Mặc định)
- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={API_KEY}`
- **Phương thức:** `POST`
- **Headers:** `Content-Type: application/json`
- **Cấu hình tham số (Generation Config):**
  - `temperature`: 0.7 (đảm bảo câu trả lời vừa sinh động, tự nhiên vừa bám sát thực tế khoa học).
  - `topP`: 0.95.
  - `maxOutputTokens`: 800 (tối ưu hóa thời gian phản hồi và dung lượng gói tin).

### 2.3. Triển khai OpenAI Service (`openai_ai_service.dart` - Module mở rộng)
- **Endpoint:** `https://api.openai.com/v1/chat/completions`
- **Model:** `gpt-4o-mini`
- **Payload:** Chuyển đổi định dạng message sang `{"role": "system" | "user", "content": "..."}` tương thích chuẩn OpenAI.

---

## 3. THIẾT KẾ KỸ THUẬT PROMPT & TIÊM NGỮ CẢNH (PROMPT ENGINEERING)

### 3.1. Chỉ thị hệ thống cốt lõi (System Instruction)
Chỉ thị hệ thống được đính kèm vào mọi yêu cầu gửi đến mô hình LLM nhằm định hình phong cách, phạm vi kiến thức và ranh giới chuyên môn:

```text
[VAI TRÒ VÀ TÍNH CÁCH]:
Bạn là Chuyên gia Tư vấn Giấc ngủ Khoa học của ứng dụng DCSleep. Bạn có phong cách trò chuyện ấm áp, lắng nghe, thấu cảm, khoa học và súc tích bằng tiếng Việt.

[PHẠM VI TRI THỨC ĐƯỢC PHÉP TƯ VẤN]:
1. Nguyên tắc Vệ sinh Giấc ngủ (Sleep Hygiene): Ánh sáng, nhiệt độ phòng ngủ (20-24°C), kiểm soát caffeine (tránh sau 14h), hạn chế ánh sáng xanh.
2. Nhịp sinh học (Circadian Rhythm): Quy tắc thức ngủ đều đặn, chu kỳ giấc ngủ 90 phút (REM & NREM).
3. Kỹ thuật thư giãn hỗ trợ vào giấc: Kỹ thuật thở 4-7-8, giãn cơ lũy tiến (Progressive Muscle Relaxation), quy tắc 20 phút rời giường khi mất ngủ.
4. Quản lý giấc ngủ ngắn (Power Nap): 10 - 20 phút buổi trưa (12:30 - 13:30), tránh ngủ quá 30 phút gây quán tính giấc ngủ (Sleep Inertia).

[RANH GIỚI VÀ QUY TẮC BẮT BUỘC]:
- KHÔNG BAO GIỜ đưa ra chẩn đoán y khoa hoặc kê đơn, khuyên dùng bất kỳ loại thuốc ngủ/thuốc an thần nào.
- Luôn kết thúc bằng lưu ý ngắn: Lời khuyên mang tính chất hỗ trợ cải thiện thói quen, không thay thế chỉ định y tế.
```

### 3.2. Tiêm ngữ cảnh dữ liệu người dùng (Context Injection)
Hệ thống tự động đọc dữ liệu từ `SleepProvider` và `DatabaseHelper` để tạo ngữ cảnh đầu vào:
```text
[DỮ LIỆU THỰC TẾ CỦA NGƯỜI DÙNG TỪ DCSLEEP]:
- Giờ ngủ mục tiêu: 23:00 - Giờ thức mục tiêu: 07:00 (Thời lượng: 8.0 giờ).
- Tỷ lệ tuân thủ lịch ngủ 7 ngày qua: 72%.
- Nhật ký đêm qua: Ngủ lúc 00:30, thức dậy 06:15 (Tổng: 5.75 giờ, Cảm nhận: Hơi mệt).

[CÂU HỎI CỦA NGƯỜI DÙNG]:
"{user_prompt}"
```

---

## 4. THIẾT KẾ GIAO DIỆN TRÒ CHUYỆN (CHAT UI SPECIFICATION)

Giao diện [ai_assistant_screen.dart](file:///d:/Nhom_mobile/project-ptuddd/nhom07-65ktpm/src/lib/screens/ai_assistant/ai_assistant_screen.dart) tuân thủ bảng mã màu chủ đạo của DCSleep (Deep Navy & Cyan Accent).

```
┌────────────────────────────────────────────────────────┐
│ [←] AI Sleep Assistant                   [Xóa lịch sử] │
├────────────────────────────────────────────────────────┤
│ [ Khó ngủ làm sao? ] [ Ngủ trưa bao lâu? ] [ Thở 4-7-8 ]│ <- Quick Chips
├────────────────────────────────────────────────────────┤
│                                                        │
│ ┌────────────────────────────────────────────────┐     │
│ │ Bot: Chào bạn! Tôi có thể hỗ trợ gì cho bạn?   │     │ <- AI Bubble (Left)
│ └────────────────────────────────────────────────┘     │
│                                                        │
│                     ┌────────────────────────────────┐ │
│                     │ User: Tối qua tôi ngủ hơi ít...│ │ <- User Bubble (Right)
│                     └────────────────────────────────┘ │
│                                                        │
│ ┌────────────────────────────────────────────────┐     │
│ │ Bot: [Đang phân tích thói quen...]             │     │ <- Typing Indicator
│ └────────────────────────────────────────────────┘     │
│                                                        │
├────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ ┌───────┐ │
│ │ Nhập câu hỏi về giấc ngủ...              │ │ [Gửi] │ │ <- Input & Send
│ └──────────────────────────────────────────┘ └───────┘ │
└────────────────────────────────────────────────────────┘
```

### 4.1. Các thành phần giao diện chính
1. **Thanh tiêu đề (AppBar):** 
   - Tên màn hình "AI Sleep Assistant".
   - Nút hành động "Xóa lịch sử" kèm hộp thoại xác nhận (Confirmation Dialog) tránh xóa nhầm dữ liệu.
2. **Thanh gợi ý nhanh (Suggested Prompt Chips):**
   - Danh sách cuộn ngang gồm 4 câu hỏi mẫu thông dụng giúp người dùng bắt đầu nhanh mà không cần gõ phím.
3. **Danh sách tin nhắn (Chat Message List):**
   - **Tin nhắn người dùng (User Bubble):** Nền màu `accentCyan`, chữ tối màu, căn lề bên phải.
   - **Tin nhắn trợ lý (AI Bubble):** Nền màu `surfaceNavy`, chữ sáng màu, căn lề bên trái.
   - Hỗ trợ hiển thị định dạng danh sách (Bullet points), in đậm tiêu đề bằng `flutter_markdown` hoặc Text spans có cấu trúc.
4. **Chỉ báo trạng thái hoạt động (Typing Indicator):**
   - Khi `isThinking == true`, hiển thị bong bóng chat với hiệu ứng 3 chấm nhấp nháy động để người dùng an tâm chờ phản hồi.
5. **Thanh nhập liệu (Bottom Input Bar):**
   - `TextField` bo tròn góc 24px, hỗ trợ tự động xuống dòng tối đa 3 dòng.
   - Nút gửi đổi trạng thái Disable khi chuỗi rỗng và kích hoạt khi có nội dung.
   - Tự động cuộn xuống cuối cùng (`_scrollToBottom()`) sau mỗi lượt gửi/nhận.

---

## 5. XỬ LÝ LỖI VÀ DỰ PHÒNG NGOẠI TUYẾN (RESILIENCE & OFFLINE SAFETY)

### 5.1. Bảng ma trận kịch bản lỗi và phương án xử lý

| Mã lỗi / Tình huống | Nguyên nhân | Phương án xử lý tự động của hệ thống |
| :--- | :--- | :--- |
| **Mất kết nối Internet** (`SocketException`) | Thiết bị offline, máy bay, mất Wi-Fi/4G | Tự động kích hoạt **Hệ tri thức ngoại tuyến (Offline Knowledge Base)** phân tích từ khóa và trả lời tức thì mà không báo lỗi crash app. |
| **Hết hạn mức API (HTTP 429)** | Tài khoản Gemini/OpenAI chạm ngưỡng rate-limit | Trả về thông báo: *"Hệ thống AI trực tuyến đang bận, DCSleep đã chuyển sang chế độ tư vấn ngoại tuyến cho bạn"* và trả lời qua bộ offline. |
| **API Key không hợp lệ (HTTP 401/403)** | Key nhập sai hoặc bị thu hồi | Ghi log an toàn, chuyển tiếp sang bộ tri thức offline và thông báo người dùng kiểm tra API Key trong mục Cài đặt. |
| **Quá thời gian chờ (Timeout > 10s)** | Mạng chập chờn, máy chủ LLM phản hồi chậm | Tự động hủy request và phản hồi thông tin từ tri thức offline. |

### 5.2. Hệ tri thức chuyên gia ngoại tuyến (Rule-based Offline Engine)
Cung cấp sẵn các nhánh câu trả lời chuyên sâu chuẩn y khoa về:
- **Kỹ thuật thở 4-7-8 & Giãn cơ:** Đầy đủ các bước đếm nhịp hít vào, nín thở, thở ra.
- **Giấc ngủ trưa (Power Nap):** Cảnh báo quán tính giấc ngủ nếu ngủ quá 30 phút, khuyến nghị 15-20 phút.
- **Vệ sinh đồ uống:** Nguyên lý bán hủy 5-7 tiếng của Caffeine, hạn chế sau 14:00.
- **Xử lý trằn trọc ban đêm:** Quy tắc rời giường sau 20 phút, điều chỉnh ánh sáng vàng mờ.

---

## 6. THIẾT KẾ CƠ SỞ DỮ LIỆU LƯU TRỮ LỊCH SỬ CHAT (SQLITE SCHEMA)

Lịch sử trò chuyện được lưu trữ bền vững tại cơ sở dữ liệu SQLite cục bộ (`dcsleep.db`) thông qua [database_helper.dart](file:///d:/Nhom_mobile/project-ptuddd/nhom07-65ktpm/src/lib/data/database/database_helper.dart).

### 6.1. Cấu trúc bảng `ai_chat_messages`
```sql
CREATE TABLE ai_chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    text TEXT NOT NULL,
    is_user INTEGER NOT NULL,          -- 1: Tin nhắn người dùng, 0: Tin nhắn AI
    timestamp TEXT NOT NULL            -- Định dạng ISO-8601 (YYYY-MM-DDTHH:mm:ss)
);
```

### 6.2. Các thao tác dữ liệu (Data Access Object)
- `insertMessage(AIMessageModel message)`: Lưu tin nhắn mới vào CSDL.
- `getAllMessages()`: Lấy toàn bộ tin nhắn sắp xếp theo thứ tự `timestamp ASC` để nạp vào màn hình.
- `clearAllMessages()`: Xóa sạch toàn bộ lịch sử khi người dùng nhấn nút "Xóa lịch sử".

---

## 7. GIỚI HẠN AN TOÀN VÀ Y ĐỨC (SAFETY GUARDRAILS & DISCLAIMER)

1. **Medical Disclaimer Cố định:**
   - Tại đầu cuộc trò chuyện hoặc chân trang của màn hình Chat luôn hiển thị khuyến cáo:  
     > *"⚠️ Lưu ý: DCSleep AI cung cấp thông tin khoa học về vệ sinh giấc ngủ nhằm hỗ trợ xây dựng lối sống lành mạnh. Ứng dụng không đưa ra chẩn đoán bệnh lý hoặc thay thế chỉ định của bác sĩ chuyên khoa."*
2. **Từ chối tư vấn dược lý (No Medication Advice):**
   - Bất kỳ câu hỏi nào liên quan đến việc *"uống thuốc ngủ gì"*, *"liều lượng thuốc an thần"* đều được kích hoạt câu trả lời chuẩn:  
     > *"DCSleep AI tuyệt đối không đưa ra hướng dẫn sử dụng hoặc liều lượng các loại thuốc ngủ/thuốc kê đơn. Bạn vui lòng thăm khám trực tiếp tại các bệnh viện hoặc chuyên khoa thần kinh để được bác sĩ chỉ định an toàn."*
3. **Phát hiện dấu hiệu nguy hiểm (Red Flags):**
   - Nếu câu hỏi đề cập đến mất ngủ kinh niên kèm triệu chứng ngưng thở, co giật, hoặc suy nhược nghiêm trọng, hệ thống sẽ ưu tiên đưa ra khuyến cáo đi khám chuyên sâu.

---

## 8. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| STT | Hạng mục kiểm tra | Tiêu chí đạt (Pass Criteria) | Trạng thái |
| :-: | :--- | :--- | :-: |
| 1 | Khởi chạy giao diện | Màn hình `AIAssistantScreen` tải mượt mà, hiển thị đúng theme màu Dark Navy & Cyan của dự án. | Đạt |
| 2 | Gửi nhận tin nhắn | Nhập nội dung và nhấn gửi; tin nhắn người dùng hiển thị bên phải, tin nhắn bot hiển thị bên trái. | Đạt |
| 3 | Tích hợp Gemini API | Khi có kết nối mạng và API Key, hệ thống nhận lời khuyên chất lượng cao từ Gemini 1.5 Flash. | Đạt |
| 4 | Dự phòng ngoại tuyến | Khi bật chế độ máy bay (ngắt mạng), hệ thống vẫn trả lời thông minh dựa trên bộ tri thức offline mà không có bất kỳ thông báo lỗi kỹ thuật nào. | Đạt |
| 5 | Lưu trữ SQLite | Thoát ứng dụng và mở lại, toàn bộ tin nhắn đã gửi trước đó vẫn được khôi phục đầy đủ. | Đạt |
| 6 | Xóa lịch sử | Nút "Xóa lịch sử" xóa sạch dữ liệu trong SQLite và làm mới danh sách tin nhắn trên UI sau khi xác nhận. | Đạt |
| 7 | Giới hạn an toàn | Hỏi về thuốc ngủ hoặc chẩn đoán bệnh, AI từ chối khéo léo và hiển thị khuyến cáo y tế đúng quy chuẩn. | Đạt |
| 8 | Tiêu chuẩn mã nguồn | Mã nguồn không có cảnh báo nghiêm trọng (Zero warnings/errors trên `flutter analyze`), đặt trong đúng cấu trúc thư mục nhóm. | Đạt |

---
*Tài liệu đặc tả này là căn cứ kỹ thuật chính thức để triển khai, kiểm thử và nghiệm thu đồ án môn học cho thành viên Dương Quốc Vượng.*
