import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StudentTestsTab extends StatefulWidget {
  final int studentId;
  const StudentTestsTab({super.key, required this.studentId});

  @override
  State<StudentTestsTab> createState() => _StudentTestsTabState();
}

class _StudentTestsTabState extends State<StudentTestsTab> {
  List<dynamic> tests = [];
  bool isLoading = true;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Student/GetAllExamBsedOnStId?StId=${widget.studentId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          tests = responseData['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF07427C)));
    }

    if (tests.isEmpty) {
      return const Center(
        child: Text(
          "لا يوجد بيانات بعد!",
          style: TextStyle(
            fontFamily: 'Almarai',
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("اسم الاختبار", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: Color(0xFF07427C)))),
                Expanded(flex: 2, child: Text("وصف الاختبار", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: Color(0xFF07427C)))),
                Expanded(flex: 2, child: Text("تعليق المعلم", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: Color(0xFF07427C)))),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final test = tests[index];
                final examInfo = test['exam'] ?? {};
                bool isExpanded = expandedIndex == index;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            _buildCell(examInfo['name'] ?? "---", 2),
                            _buildCell(examInfo['description'] ?? "---", 2),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () => setState(() => expandedIndex = isExpanded ? null : index),
                                child: Text(
                                  isExpanded ? "إخفاء" : "عرض تعليق المعلم",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isExpanded ? Colors.red : const Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        child: isExpanded
                            ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow("التقييم :", "${test['grade'] ?? '0'}", Colors.blue.shade800),
                              const SizedBox(height: 10),
                              _detailRow("تعليق المعلم :", "${test['note'] ?? 'لا توجد ملاحظات إضافية'}", Colors.black87),
                            ],
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontFamily: 'Almarai', color: Colors.black87),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: TextStyle(fontFamily: 'Almarai', fontSize: 13, color: color))),
      ],
    );
  }
}