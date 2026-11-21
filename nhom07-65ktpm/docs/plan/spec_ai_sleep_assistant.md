# ĐẶC TẢ KỸ THUẬT PHÂN HỆ: TRỢ LÝ AI TƯ VẤN GIẤC NGỦ (AI SLEEP ASSISTANT)

> **Dự án:** DCSleep – Ứng dụng Hỗ trợ Xây dựng Kỷ luật và Cải thiện Thói quen Ngủ bằng Trí tuệ Nhân tạo  
> **Học phần:** Phát triển ứng dụng cho các thiết bị di động (PTUDDD)  
> **Giảng viên hướng dẫn:** ThS. Đỗ Oanh Cường  
> **Lớp sinh hoạt:** 65KTPM – Nhóm 07  
> **Sinh viên phụ trách:** **Dương Quốc Vượng** (Mã sinh viên: **2351170634** – Thành viên)  
> **Phiên bản tài liệu:** 1.1 (Cập nhật chuẩn API Gemini 2.5, Bộ nhớ hội thoại & Cơ chế an toàn 2 lớp)  
> **Ngày cập nhật:** 21/11/2026  

---

## 1. TỔNG QUAN VÀ MỤC TIÊU PHÂN HỆ

### 1.1. Bối cảnh
Trong hệ thống DCSleep, người dùng (đặc biệt là sinh viên và người trẻ) thường gặp các vấn đề đa dạng về giấc ngủ như: khó vào giấc, thức khuya do áp lực học tập, sử dụng thiết bị điện tử ban đêm, hoặc ngủ trưa sai cách dẫn đến mệt mỏi. Phân hệ **AI Sleep Assistant** đóng vai trò là một người bạn đồng hành 24/7, cung cấp giải pháp tư vấn khoa học dựa trên phương pháp Vệ sinh giấc ngủ (Sleep Hygiene) và nhịp sinh học (Circadian Rhythm).

### 1.2. Mục tiêu chức năng & Kỹ thuật
1. Cung cấp giao diện trò chuyện dạng hội thoại trực quan (Chat UI) thân thiện, tích hợp chỉ báo trạng thái trực tuyến / ngoại tuyến rõ ràng.
2. Tích hợp mô hình ngôn ngữ lớn thế hệ mới (**Google Gemini 2.5 Flash**) qua lớp dịch vụ (Service Layer) trừu tượng, sẵn sàng mở rộng cho OpenAI API.
3. **Bộ nhớ hội thoại đa lượt (Multi-turn Conversational Memory):** Duy trì ngữ cảnh trao đổi qua cơ chế cửa sổ trượt (Sliding Window 4–6 tin nhắn gần nhất) giúp AI hiểu được các câu hỏi nối tiếp của người dùng.
4. **Kỹ thuật Prompt cá nhân hóa:** Tự động trích xuất dữ liệu nhật ký giấc ngủ (thời lượng ngủ, tỷ lệ tuân thủ) của người dùng để tiêm ngữ cảnh (Context Injection).
5. **Khả năng chịu lỗi và chạy ngoại tuyến 100%:** Tích hợp bộ tri thức chuyên gia dự phòng (Offline Expert Knowledge Base) đảm bảo trải nghiệm liền mạch khi không có Internet.
6. **Cơ chế an toàn 2 lớp (Two-Layer Safety Guardrails):** Bộ lọc cục bộ chặn tức thì (Local Pre-filter) kết hợp chỉ thị hệ thống nghiêm ngặt, từ chối tư vấn dược lý và nhận diện dấu hiệu nguy hiểm (Red Flags).
7. **Bảo mật API Key:** Sử dụng cơ chế lưu trữ an toàn phần cứng (`flutter_secure_storage`) và truyền khóa qua HTTP Header thay vì URL Query Parameter.
8. Lưu trữ dữ liệu lịch sử hội thoại vào cơ sở dữ liệu SQLite cục bộ.

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
                            │ (Gọi hàm trừu tượng với History)
┌───────────────────────────▼────────────────────────────┘
│                     «interface»                        │
│                      AIService                         │
│  + askAssistant(prompt, context, history): Future     │
└───────────────▲────────────────────────▲───────────────┘
                │                        │
┌───────────────┴──────────────┐ ┌───────┴───────────────┐
│       GeminiAIService        │ │        OpenAIService  │
│  - Model: gemini-2.5-flash   │ │  - Model: gpt-4o-mini │
│  - Header: x-goog-api-key    │ │  - REST Endpoint      │
└──────────────────────────────┘ └───────────────────────┘
```

### 2.1. Định nghĩa Interface chung (`ai_service.dart`)
Bổ sung tham số danh sách lịch sử tin nhắn gần nhất (`history`) để hỗ trợ hội thoại nhiều lượt:

```dart
abstract class AIService {
  Future<String> askAssistant({
    required String prompt,
    String? sleepContext,
    List<AIMessageModel> history = const [],
  });

  void setApiKey(String key);
  bool get hasApiKey;
}
```

### 2.2. Triển khai Gemini Service (`gemini_ai_service.dart` - Mặc định)
- **Endpoint chính thức:** `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`  
  *(Áp dụng dòng mô hình **Gemini 2.5 Flash** thay thế cho dòng 1.5 đã ngừng hỗ trợ, đảm bảo tốc độ phản hồi nhanh và chi phí tối ưu).*
- **Phương thức:** `POST`
- **Bảo mật Header:** Truyền khóa API qua Header chuyên dụng `x-goog-api-key` để tránh lộ khóa trong URL:
  ```http
  POST /v1beta/models/gemini-2.5-flash:generateContent HTTP/1.1
  Host: generativelanguage.googleapis.com
  Content-Type: application/json
  x-goog-api-key: {SECURE_API_KEY}
  ```
- **Cấu trúc Payload chuẩn chuẩn hóa (Dùng đúng trường `system_instruction`):**
  Tách biệt chỉ thị hệ thống khỏi nội dung người dùng để triệt tiêu nguy cơ tấn công Prompt Injection:
  ```json
  {
    "system_instruction": {
      "parts": [
        {
          "text": "Bạn là chuyên gia tư vấn giấc ngủ khoa học của DCSleep..."
        }
      ]
    },
    "contents": [
      {
        "role": "user",
        "parts": [{"text": "Tôi hay bị khó ngủ lúc nửa đêm"}]
      },
      {
        "role": "model",
        "parts": [{"text": "Bạn có thể thử áp dụng kỹ thuật thở 4-7-8..."}]
      },
      {
        "role": "user",
        "parts": [{"text": "Kỹ thuật đó làm cụ thể thế nào?"}]
      }
    ],
    "generationConfig": {
      "temperature": 0.7,
      "topP": 0.95,
      "maxOutputTokens": 1024
    }
  }
  ```
- **Xử lý cửa sổ trượt (Sliding Window):** Chỉ trích xuất từ 4 đến 6 tin nhắn mới nhất trong `history` đưa vào mảng `contents` để duy trì ngữ cảnh mà không làm bùng nổ số lượng token sử dụng.
- **Giới hạn Output Token:** Đặt `maxOutputTokens: 1024` đảm bảo câu trả lời tiếng Việt có đầy đủ cấu trúc giải pháp và lời dặn an toàn mà không bị đứt câu giữa chừng.

### 2.3. Triển khai OpenAI Service (`openai_ai_service.dart` - Module mở rộng)
- **Endpoint:** `https://api.openai.com/v1/chat/completions`
- **Model:** `gpt-4o-mini`
- **Headers:** `Authorization: Bearer {API_KEY}`, `Content-Type: application/json`

### 2.4. Quản lý và Lưu trữ Khóa API An toàn (Security Architecture)
1. **Giai đoạn Phát triển (Development):**
   - Đọc khóa API từ biến môi trường qua tham số `--dart-define=GEMINI_API_KEY=xxx` hoặc file cấu hình `.env` cục bộ.
   - Thư mục `.env` đã được cấu hình loại trừ trong `.gitignore` cấp cao nhất của dự án để ngăn rò rỉ lên GitHub.
2. **Giai đoạn Triển khai Ứng dụng (Runtime / Settings):**
   - Trong trường hợp người dùng/giảng viên cấu hình khóa API tùy chỉnh tại màn hình Cài đặt, ứng dụng sử dụng thư viện **`flutter_secure_storage`** (lưu trữ mã hóa bằng Android Keystore và iOS Keychain), tuyệt đối **không** lưu trữ khóa dạng văn bản thuần (plain-text) trong `SharedPreferences`.
3. **Môi trường Mạng (Network Transmission):**
   - Không nối chuỗi `?key={API_KEY}` vào URL query string để tránh việc khóa API bị ghi nhận trong máy chủ proxy, log mạng hoặc lịch sử duyệt web.

---

## 3. THIẾT KẾ KỸ THUẬT PROMPT & TIÊM NGỮ CẢNH (PROMPT ENGINEERING)

### 3.1. Chỉ thị hệ thống cốt lõi (System Instruction)
Chỉ thị hệ thống được đính kèm vào trường `system_instruction` của API:

```text
[VAI TRÒ VÀ TÍNH CÁCH]:
Bạn là Chuyên gia Tư vấn Giấc ngủ Khoa học của ứng dụng DCSleep. Hãy trả lời ấm áp, thấu cảm, khoa học, súc tích bằng tiếng Việt. Độ dài câu trả lời lý tưởng dưới 200 từ.

[PHẠM VI TRI THỨC ĐƯỢC PHÉP TƯ VẤN]:
1. Nguyên tắc Vệ sinh Giấc ngủ (Sleep Hygiene): Ánh sáng, nhiệt độ phòng ngủ (20-24°C), kiểm soát caffeine (tránh sau 14h), hạn chế ánh sáng xanh từ thiết bị số.
2. Nhịp sinh học (Circadian Rhythm): Quy tắc thức ngủ đều đặn, chu kỳ giấc ngủ 90 phút (REM & NREM).
3. Kỹ thuật thư giãn hỗ trợ vào giấc: Kỹ thuật thở 4-7-8, giãn cơ lũy tiến (PMR), quy tắc 20 phút rời giường khi mất ngủ.
4. Quản lý giấc ngủ ngắn (Power Nap): 10 - 20 phút buổi trưa (12:30 - 13:30), tránh ngủ quá 30 phút gây quán tính giấc ngủ (Sleep Inertia).

[RANH GIỚI VÀ QUY TẮC BẮT BUỘC]:
- KHÔNG BAO GIỜ đưa ra chẩn đoán y khoa hoặc kê đơn, hướng dẫn liều lượng bất kỳ loại thuốc ngủ/thuốc an thần nào.
- Luôn kết thúc bằng lưu ý ngắn: Lời khuyên mang tính chất hỗ trợ xây dựng lối sống khoa học, không thay thế chỉ định y tế.
```

### 3.2. Tiêm ngữ cảnh dữ liệu người dùng (Context Injection)
Hệ thống tự động đọc dữ liệu từ `SleepProvider` để làm giàu câu hỏi của người dùng:
```text
[DỮ LIỆU THỰC TẾ TỪ DCSLEEP]:
- Giờ ngủ mục tiêu: 23:00 - Giờ thức mục tiêu: 07:00 (Thời lượng: 8.0 giờ).
- Tỷ lệ tuân thủ lịch ngủ 7 ngày qua: 72%.
- Nhật ký đêm qua: Ngủ lúc 00:30, thức dậy 06:15 (5.75 giờ, Cảm nhận: Hơi mệt).

[CÂU HỎI HIỆN TẠI]:
"{user_prompt}"
```

---

## 4. THIẾT KẾ GIAO DIỆN TRÒ CHUYỆN (CHAT UI & UX SPECIFICATION)

Giao diện tại đường dẫn `src/lib/screens/ai_assistant/ai_assistant_screen.dart` tuân thủ bảng mã màu Dark Navy & Cyan Accent của dự án.

```
┌────────────────────────────────────────────────────────┐
│ [←] AI Sleep Assistant                   [Xóa lịch sử] │
├────────────────────────────────────────────────────────┤
│ ⚠️ Đang hoạt động ở chế độ ngoại tuyến (Tri thức tĩnh)  │ <- Offline Mode Banner (Chỉ hiện khi offline)
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

### 4.1. Các thành phần giao diện & Trạng thái UX
1. **Thanh trạng thái Ngoại tuyến (Offline Mode Banner):**
   - Khi phát hiện mất mạng hoặc đang chạy qua bộ cứu hộ cục bộ, một dải banner nhỏ màu vàng mờ xuất hiện dưới AppBar: *"Đang hoạt động ở chế độ ngoại tuyến (Tri thức cục bộ)"*.
   - Trên mỗi bong bóng tin nhắn trả lời từ nguồn offline có gắn tag nhỏ `[Ngoại tuyến]` để đảm bảo tính minh bạch tuyệt đối với người dùng.
2. **Thanh gợi ý nhanh (Suggested Prompt Chips):**
   - Danh sách cuộn ngang gồm 4 câu hỏi mẫu thông dụng giúp người dùng bắt đầu nhanh mà không cần gõ phím.
3. **Danh sách tin nhắn (Chat Message List):**
   - **Tin nhắn người dùng (User Bubble):** Nền màu `accentCyan`, chữ tối màu, căn lề bên phải.
   - **Tin nhắn trợ lý (AI Bubble):** Nền màu `surfaceNavy`, chữ sáng màu, căn lề bên trái.
   - Hỗ trợ định dạng in đậm, danh sách gạch đầu dòng (bullet points) rõ ràng.
4. **Chỉ báo trạng thái hoạt động (Typing Indicator):**
   - Khi `isThinking == true`, hiển thị bong bóng chat với hiệu ứng 3 chấm nhấp nháy động để người dùng an tâm chờ phản hồi.
5. **Thanh nhập liệu (Bottom Input Bar):**
   - `TextField` bo tròn góc 24px, tự động cuộn xuống cuối cùng (`_scrollToBottom()`) sau mỗi lượt gửi/nhận.

---

## 5. XỬ LÝ LỖI VÀ DỰ PHÒNG NGOẠI TUYẾN (RESILIENCE & OFFLINE SAFETY)

### 5.1. Bảng ma trận kịch bản lỗi và phương án xử lý

| Mã lỗi / Tình huống | Nguyên nhân | Phương án xử lý tự động của hệ thống |
| :--- | :--- | :--- |
| **Mất kết nối Internet** (`SocketException`) | Thiết bị offline, máy bay, mất Wi-Fi/4G | Hiển thị Banner ngoại tuyến; tự động chuyển sang **Hệ tri thức chuyên gia ngoại tuyến (Offline Knowledge Base)** phân tích từ khóa và trả lời tức thì mà không báo lỗi kỹ thuật. |
| **Hết hạn mức API (HTTP 429)** | Tài khoản Gemini chạm ngưỡng giới hạn | Hiển thị Banner thông báo: *"Dịch vụ trực tuyến đang bận, DCSleep chuyển sang chế độ tư vấn ngoại tuyến"* và trả lời qua bộ tri thức offline. |
| **API Key không hợp lệ (HTTP 401/403)** | Key nhập sai hoặc bị thu hồi | Chuyển tiếp sang bộ tri thức offline và thông báo người dùng kiểm tra API Key trong mục Cài đặt. |
| **Quá thời gian chờ (Timeout > 10s)** | Mạng chập chờn, máy chủ LLM phản hồi chậm | Tự động hủy request và phản hồi thông tin từ tri thức offline. |

### 5.2. Hệ tri thức chuyên gia ngoại tuyến (Rule-based Offline Engine)
Cung cấp sẵn các nhánh câu trả lời chuyên sâu chuẩn khoa học y tế:
- **Kỹ thuật thở 4-7-8 & Giãn cơ:** Đầy đủ các bước đếm nhịp hít vào (4s), nín thở (7s), thở ra (8s).
- **Giấc ngủ trưa (Power Nap):** Cảnh báo quán tính giấc ngủ nếu ngủ quá 30 phút, khuyến nghị 15-20 phút.
- **Vệ sinh đồ uống:** Nguyên lý bán hủy 5-7 tiếng của Caffeine, hạn chế sau 14:00.
- **Xử lý trằn trọc ban đêm:** Quy tắc rời giường sau 20 phút, điều chỉnh ánh sáng vàng mờ.

---

## 6. THIẾT KẾ CƠ SỞ DỮ LIỆU LƯU TRỮ LỊCH SỬ CHAT (SQLITE SCHEMA)

Lịch sử trò chuyện được lưu trữ bền vững tại cơ sở dữ liệu SQLite cục bộ (`dcsleep.db`) thông qua tệp mã nguồn `src/lib/data/database/database_helper.dart`.

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
- `clearAllMessages()`: Xóa sạch toàn bộ lịch sử khi người dùng nhấn nút "Xóa lịch sử" trên AppBar.

---

## 7. CƠ CHẾ AN TOÀN 2 LỚP VÀ Y ĐỨC (TWO-LAYER SAFETY GUARDRAILS)

Nhằm đảm bảo an toàn tối đa cho người dùng và vượt qua các yêu cầu nghiệm thu nghiêm ngặt, hệ thống áp dụng cơ chế lọc 2 tầng:

```
[Tin nhắn người dùng]
         │
         ▼
┌────────────────────────────────────────────────────────┐
│ TẦNG 1: Local Pre-filter (Kiểm tra từ khóa cục bộ)     │
│ - Dược lý: thuốc ngủ, seduxen, stilnox, zolpidem...    │
│ - Dấu hiệu nguy cấp: ngưng thở khi ngủ, co giật...     │
└────────┬───────────────────────────────────────────────┘
         │
         ├─► [Phát hiện từ khóa cấm / Red Flag] ──► Trả ngay thông điệp Cảnh báo Chuẩn
         │
         ▼ (An toàn)
┌────────────────────────────────────────────────────────┐
│ TẦNG 2: Model System Prompt Guardrails                 │
│ - Ngăn chặn tấn công bẻ khóa (Jailbreak / Injection)   │
│ - Từ chối các câu hỏi suy diễn bệnh lý chuyên sâu      │
└────────────────────────────────────────────────────────┘
```

### 7.1. Tầng 1: Bộ lọc an toàn cục bộ (Local Pre-filter)
Chạy ngay trên thiết bị trước khi gửi request tới API hoặc Offline Engine:
1. **Từ khóa dược lý nghiêm cấm:** `thuốc ngủ`, `thuốc an thần`, `seduxen`, `stilnox`, `zolpidem`, `diazepam`, `rotunda`, `uống thuốc gì`, `liều lượng thuốc`.
   - *Phản hồi chuẩn:* *"⚠️ DCSleep AI tuyệt đối không đưa ra hướng dẫn sử dụng hoặc liều lượng các loại thuốc ngủ/thuốc kê đơn. Bạn vui lòng thăm khám trực tiếp tại cơ sở y tế chuyên khoa để được bác sĩ chỉ định an toàn."*
2. **Dấu hiệu cảnh báo nguy hiểm (Red Flags):** `ngưng thở khi ngủ`, `co giật`, `ảo giác`, `suy nhược cấp`, `mất ngủ kinh niên nhiều tháng`.
   - *Phản hồi chuẩn:* *"⚠️ Đây là các dấu hiệu cảnh báo bệnh lý giấc ngủ nghiêm trọng. DCSleep khuyến nghị bạn nên đến ngay các bệnh viện hoặc phòng khám chuyên khoa Thần kinh - Hô hấp để được đo đa ký giấc ngủ (Polysomnography) và chẩn đoán kịp thời."*

### 7.2. Tầng 2: Rào cản mô hình (Model Guardrails) & Disclaimer cố định
- Mô hình được chỉ dẫn trong `system_instruction` luôn duy trì vai trò tư vấn thói quen sinh hoạt lành mạnh, từ chối mọi yêu cầu chẩn đoán bệnh lý thay bác sĩ.
- Chân trang màn hình luôn hiển thị dòng khuyến cáo:  
  *“DCSleep AI cung cấp kiến thức vệ sinh giấc ngủ nhằm xây dựng thói quen khoa học, không thay thế chẩn đoán hoặc điều trị y tế.”*

---

## 8. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

| STT | Hạng mục kiểm tra | Tiêu chí đạt (Pass Criteria) | Trạng thái |
| :-: | :--- | :--- | :---: |
| 1 | Khởi chạy giao diện | Màn hình `AIAssistantScreen` tải mượt mà, hiển thị đúng theme màu Dark Navy & Cyan của dự án. | Chưa kiểm thử |
| 2 | Gửi nhận tin nhắn | Nhập nội dung và nhấn gửi; tin nhắn người dùng hiển thị bên phải, tin nhắn bot hiển thị bên trái. | Chưa kiểm thử |
| 3 | Tích hợp Gemini 2.5 Flash | Kết nối API thành công qua header `x-goog-api-key`, nhận phản hồi chính xác và câu trả lời hoàn chỉnh (< 1024 tokens). | Chưa kiểm thử |
| 4 | Bộ nhớ hội thoại đa lượt | Hỏi câu nối tiếp (ví dụ: "cách thứ 2 làm thế nào?"), AI nhận diện đúng ngữ cảnh câu trước dựa trên sliding window 4–6 tin nhắn. | Chưa kiểm thử |
| 5 | Dự phòng ngoại tuyến & UX | Khi ngắt mạng, hệ thống tự động phản hồi từ bộ tri thức offline và hiển thị dải thông báo chế độ ngoại tuyến rõ ràng. | Chưa kiểm thử |
| 6 | Cơ chế an toàn 2 lớp | Hỏi về tên thuốc ngủ hoặc triệu chứng ngưng thở, Local Pre-filter chặn ngay lập tức và đưa ra cảnh báo y tế chuẩn. | Chưa kiểm thử |
| 7 | Lưu trữ SQLite bền vững | Thoát ứng dụng và mở lại, toàn bộ tin nhắn đã gửi trước đó vẫn được khôi phục đầy đủ; nút "Xóa lịch sử" hoạt động chính xác. | Chưa kiểm thử |
| 8 | Bảo mật khóa API | Khóa API không bị hardcode trong mã nguồn, không lộ trên URL query string và được lưu trữ an toàn khi người dùng cấu hình tùy chỉnh. | Chưa kiểm thử |

---
*Tài liệu đặc tả kỹ thuật này là căn cứ chính thức để triển khai, kiểm thử và nghiệm thu đồ án môn học cho thành viên Dương Quốc Vượng.*
