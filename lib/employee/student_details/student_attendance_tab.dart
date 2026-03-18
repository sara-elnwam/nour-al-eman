import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color kPrimaryBlue = Color(0xFF07427C);
const Color kHeaderGrey = Color(0xFFF9FAFB);
const Color kSuccessGreen = Color(0xFF16A34A);
const Color kDangerRed = Color(0xFFDC2626);

class StudentAttendanceTab extends StatefulWidget {
  final int studentId;
  const StudentAttendanceTab({super.key, required this.studentId});

  @override
  State<StudentAttendanceTab> createState() => _StudentAttendanceTabState();
}

class _StudentAttendanceTabState extends State<StudentAttendanceTab> {
  List<dynamic> attendanceList = [];
  bool isLoading = true;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  // ترجمة القيمة القادمة من السيرفر (ممكن تكون int أو String)
  String _mapNoteToText(dynamic noteValue) {
    if (noteValue == null) return "غير محدد";

    // لو جاي كـ String جاهز من السيرفر مباشرة
    if (noteValue is String) {
      final trimmed = noteValue.trim();
      if (trimmed.isEmpty) return "غير محدد";
      // لو جاي كرقم بس في شكل String
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return _noteFromInt(asInt);
      return trimmed; // إرجاع النص كما هو
    }

    // لو جاي كـ int
    if (noteValue is int) return _noteFromInt(noteValue);

    return "غير محدد";
  }

  String _noteFromInt(int id) {
    switch (id) {
      case 1: return "ممتاز";
      case 2: return "جيد جداً";
      case 3: return "جيد";
      case 4: return "مقبول";
      case 5: return "ضعيف";
      default: return "غير محدد";
    }
  }

  Future<void> _fetchAttendance() async {
    try {
      final String url = 'https://nour-al-eman.runasp.net/api/Student/GetAttendaceByStudentId?id=${widget.studentId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        debugPrint("🔍 ATTENDANCE RESPONSE: ${response.body}"); // مؤقت للـ debug
        if (mounted) {
          setState(() {
            attendanceList = responseData['data'] ?? []; // سحب الداتا من key: data
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // الهيدر - مطابق تماماً لصورة الويب اللي بعتها
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              color: kHeaderGrey,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("موعد الحلقة", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 1, child: Text("الحضور", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("حفظ قديم", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("حفظ جديد", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("تعليق المعلم", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              itemCount: attendanceList.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final item = attendanceList[index];
                bool isExpanded = expandedIndex == index;

                return Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => expandedIndex = isExpanded ? null : index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                        child: Row(
                          children: [
                            // 1. موعد الحلقة (سحب createDate من الرسبونس)
                            Expanded(flex: 2, child: Text(item['createDate']?.split('T')[0] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),

                            // 2. الحضور (isPresent)
                            Expanded(
                              flex: 1,
                              child: Text(
                                item['isPresent'] == true ? "حضور" : "غياب",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: item['isPresent'] == true ? kSuccessGreen : kDangerRed, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),

                            // 3. حفظ قديم (oldAttendanceNote)
                            Expanded(flex: 2, child: Text(_mapNoteToText(item['oldAttendanceNote']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),

                            // 4. حفظ جديد (newAttendanceNote)
                            Expanded(flex: 2, child: Text(_mapNoteToText(item['newAttendanceNote']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),

                            // 5. زر تعليق المعلم
                            Expanded(
                              flex: 2,
                              child: Text(
                                isExpanded ? "إخفاء" : "تعليق المعلم",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isExpanded ? kDangerRed : kPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 10, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // الأنيميشن بتاع تعليق المعلم والتقييم (سحب note و points)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: double.infinity,
                        height: isExpanded ? null : 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.grey.shade50,
                        child: isExpanded
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // سحب تعليق المعلم الفعلي من السيرفر
                            Expanded(
                              child: Text(
                                  "تعليق المعلم: ${item['note'] ?? 'No comment'}",
                                  style: const TextStyle(color: kSuccessGreen, fontWeight: FontWeight.bold, fontSize: 11)
                              ),
                            ),
                            // سحب التقييم بالنقاط الفعلي من السيرفر
                            Text(
                                "التقييم: ${item['points'] ?? 0} نقاط",
                                style: const TextStyle(color: kSuccessGreen, fontWeight: FontWeight.bold, fontSize: 11)
                            ),
                          ],
                        )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}