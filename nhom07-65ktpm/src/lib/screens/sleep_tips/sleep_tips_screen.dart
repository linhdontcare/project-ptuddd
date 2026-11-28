import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SleepTipsScreen extends StatefulWidget {
  const SleepTipsScreen({super.key});

  @override
  State<SleepTipsScreen> createState() => _SleepTipsScreenState();
}

class _SleepTipsScreenState extends State<SleepTipsScreen> {
  String _selectedCategory = 'Tất cả';

  static const List<String> _categories = [
    'Tất cả',
    'Thư giãn',
    'Vệ sinh giấc ngủ',
    'Môi trường',
    'Dinh dưỡng',
    'Sinh học',
    'Power Nap',
  ];

  final List<Map<String, String>> _tips = const [
    {
      'title': 'Kỹ thuật thở 4-7-8 giúp thư giãn sâu',
      'category': 'Thư giãn',
      'content':
          'Hít vào bằng mũi trong 4 giây, nín thở trong 7 giây và thở ra từ từ bằng miệng trong 8 giây. Thực hiện 4 chu kỳ giúp kích hoạt hệ thần kinh phó giao cảm và làm chậm nhịp tim.',
    },
    {
      'title': 'Thư giãn cơ bắp tuần tự (PMR)',
      'category': 'Thư giãn',
      'content':
          'Căng từng nhóm cơ (bàn chân, bắp chân, vai, mặt) trong 5 giây rồi thả lỏng hoàn toàn trong 10 giây. Cách này giúp giải phóng căng thẳng tích tụ sau một ngày học tập và làm việc.',
    },
    {
      'title': 'Kỹ thuật "Brain Dump" – Viết ra trước khi ngủ',
      'category': 'Thư giãn',
      'content':
          'Nếu đầu óc cứ nghĩ mãi về việc ngày mai, hãy dành 5 phút viết danh sách việc cần làm ra giấy trước khi lên giường. Não bộ sẽ ngừng "nhắc nhở" và dễ chìm vào giấc ngủ hơn.',
    },
    {
      'title': 'Vệ sinh giấc ngủ: Kiểm soát ánh sáng xanh',
      'category': 'Vệ sinh giấc ngủ',
      'content':
          'Ánh sáng xanh từ màn hình smartphone và máy tính ức chế hormone Melatonin. Hãy bật chế độ Night Light (ánh sáng vàng) hoặc ngừng dùng thiết bị ít nhất 30–60 phút trước khi ngủ.',
    },
    {
      'title': 'Quy tắc 20 phút nếu chưa ngủ được',
      'category': 'Vệ sinh giấc ngủ',
      'content':
          'Nếu nằm trằn trọc quá 20 phút mà vẫn tỉnh táo, hãy rời khỏi giường, đọc vài trang sách dưới ánh đèn vàng dịu nhẹ rồi quay lại khi thấy buồn ngủ. Đừng để não gắn liền chiếc giường với sự lo âu.',
    },
    {
      'title': 'Giữ giờ thức dậy cố định cả cuối tuần',
      'category': 'Vệ sinh giấc ngủ',
      'content':
          'Ngủ bù quá muộn vào thứ 7 và Chủ nhật dễ gây hiện tượng "Social Jetlag", khiến tối Chủ nhật khó ngủ và sáng thứ 2 mệt mỏi. Hãy giữ giờ dậy chênh lệch không quá 1 tiếng.',
    },
    {
      'title': 'Chỉ dùng giường cho giấc ngủ',
      'category': 'Vệ sinh giấc ngủ',
      'content':
          'Tránh làm việc, học bài hoặc lướt mạng xã hội hàng giờ trên giường. Khi giường chỉ gắn với việc ngủ, cơ thể sẽ hình thành phản xạ buồn ngủ nhanh hơn khi nằm xuống.',
    },
    {
      'title': 'Nhiệt độ phòng ngủ tối ưu (20°C – 24°C)',
      'category': 'Môi trường',
      'content':
          'Nhiệt độ cơ thể cần giảm nhẹ để bước vào giấc ngủ sâu. Phòng ngủ mát mẻ từ 20°C đến 24°C giúp giảm tình trạng thức giấc giữa đêm và tăng chất lượng giấc ngủ REM.',
    },
    {
      'title': 'Tối hoàn toàn & giảm tiếng ồn đột ngột',
      'category': 'Môi trường',
      'content':
          'Ánh sáng lọt qua rèm cửa hay đèn LED sạc có thể làm giảm tiết Melatonin. Hãy kéo rèm tối và dùng tiếng ồn trắng (như tiếng mưa, quạt nhẹ) nếu môi trường xung quanh ồn ào.',
    },
    {
      'title': 'Tắm nước ấm 60–90 phút trước khi ngủ',
      'category': 'Môi trường',
      'content':
          'Tắm nước ấm giúp giãn mạch ngoại vi; sau khi bước ra khỏi phòng tắm, nhiệt độ lõi cơ thể hạ xuống nhanh hơn, phát tín hiệu tự nhiên báo hiệu đã đến giờ ngủ.',
    },
    {
      'title': 'Giới hạn Caffeine sau 14h chiều',
      'category': 'Dinh dưỡng',
      'content':
          'Caffeine có thời gian bán hủy từ 5 đến 7 tiếng và chẹn thụ thể Adenosine gây buồn ngủ. Uống cà phê, trà đặc hoặc nước tăng lực vào cuối chiều sẽ làm giảm giấc ngủ sâu.',
    },
    {
      'title': 'Tránh ăn no hoặc đồ cay nóng sát giờ ngủ',
      'category': 'Dinh dưỡng',
      'content':
          'Bữa tối nên kết thúc trước khi ngủ ít nhất 2–3 tiếng. Ăn quá no khiến hệ tiêu hóa phải làm việc liên tục, dễ gây trào ngược và ngủ không sâu giấc.',
    },
    {
      'title': 'Thực phẩm hỗ trợ giấc ngủ tự nhiên',
      'category': 'Dinh dưỡng',
      'content':
          'Một ly sữa ấm, vài quả hạnh nhân, chuối hoặc trà hoa cúc không caffeine vào buổi tối cung cấp Magie và Tryptophan hỗ trợ cơ thể thư giãn tự nhiên.',
    },
    {
      'title': 'Đón ánh nắng tự nhiên 10–15 phút buổi sáng',
      'category': 'Sinh học',
      'content':
          'Ánh sáng mặt trời buổi sáng giúp đồng hồ sinh học (nhịp sinh học) khởi động đúng giờ, tăng tỉnh táo ban ngày và tự động tiết Melatonin sớm hơn vào buổi tối.',
    },
    {
      'title': 'Vận động đều đặn nhưng tránh tập nặng sát giờ ngủ',
      'category': 'Sinh học',
      'content':
          'Tập thể dục 30 phút mỗi ngày giúp tăng thời lượng giấc ngủ sâu. Tuy nhiên, hãy hoàn thành các bài tập cường độ cao ít nhất 3 tiếng trước khi đi ngủ.',
    },
    {
      'title': 'Power Nap chuẩn khoa học: 15–20 phút',
      'category': 'Power Nap',
      'content':
          'Ngủ trưa ngắn 15–20 phút giúp nạp lại sự tỉnh táo và trí nhớ mà không rơi vào giai đoạn ngủ sâu, tránh cảm giác uể oải (Sleep Inertia) khi thức dậy.',
    },
    {
      'title': 'Thời điểm vàng để Power Nap: 12h30 – 14h30',
      'category': 'Power Nap',
      'content':
          'Chợp mắt vào đầu giờ chiều phù hợp với nhịp tụt năng lượng tự nhiên của cơ thể. Tránh ngủ trưa sau 15h30 vì có thể làm giảm cơn buồn ngủ vào ban đêm.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTips = _selectedCategory == 'Tất cả'
        ? _tips
        : _tips.where((t) => t['category'] == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Thư Viện Cải Thiện Giấc Ngủ')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.accentIndigo,
                  backgroundColor: AppTheme.surfaceNavy,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: filteredTips.length,
              itemBuilder: (context, index) {
                final tip = filteredTips[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentIndigo.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tip['category']!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tip['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tip['content']!,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
