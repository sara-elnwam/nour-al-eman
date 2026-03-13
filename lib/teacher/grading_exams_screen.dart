import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session_model.dart';

class GradingExamsScreen extends StatefulWidget {
  final int groupId;
  final int levelId;
  final List<Student> students;

  const GradingExamsScreen({
    super.key,
    required this.groupId,
    required this.levelId,
    required this.students,
  });

  @override
  State<GradingExamsScreen> createState() => _GradingExamsScreenState();
}

class _GradingExamsScreenState extends State<GradingExamsScreen> {
  Student? _selectedStudent;
  dynamic _selectedExam;
  List<dynamic> _exams = [];
  bool _isLoadingExams = true;
  bool _showErrors = false;
  String _statusMessage = "جاري التحميل...";

  final TextEditingController _gradeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    if (!mounted) return;
    setState(() {
      _isLoadingExams = true;
      _statusMessage = "جاري التحميل...";
      _exams = [];
    });

    final url =
        "https://nourelman.runasp.net/api/StudentCources/GetStudentsExamByLevel?levelId=${widget.levelId}";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final decodedData = json.decode(res.body);
        List data = decodedData["data"] ?? [];
        if (decodedData is Map && decodedData.containsKey("data")) {
          data = decodedData["data"] ?? [];
        } else if (decodedData is List) {
          data = decodedData;
        }

        if (mounted) {
          setState(() {
            _exams = data;
            _isLoadingExams = false;
            _statusMessage = data.isEmpty ? "لا توجد اختبارات مضافة" : "اختر اسم الاختبار";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingExams = false;
            _statusMessage = "خطأ من السيرفر: ${res.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingExams = false;
          _statusMessage = "فشل الاتصال.. اضغط للتحديث";
        });
      }
    }
  }

  Future<void> _submitGrading() async {
    setState(() => _showErrors = true);

    if (_selectedStudent == null ||
        _selectedExam == null ||
        _gradeController.text.isEmpty ||
        _noteController.text.isEmpty) {
      return;
    }

    bool confirm = await _showConfirmationDialog();
    if (!confirm) return;

    final int? examId = _selectedExam["id"];

    if (examId == null) {
      _showSnackBar(" خطأ: لم يتم العثور على معرف الاختبار", Colors.red);
      return;
    }

    const String postUrl = "https://nourelman.runasp.net/api/StudentCources/AddStudentExamAsync";

    try {
      final response = await http.post(
        Uri.parse(postUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/plain",
        },
        body: jsonEncode({
          "stId": _selectedStudent!.id,
          "examId": examId,
          "url": "",
          "grade": int.tryParse(_gradeController.text) ?? 0,
          "note": _noteController.text,
        }),
      );

      debugPrint("Submit response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(" تم حفظ التقييم بنجاح", Colors.green);
        _resetForm();
      } else {
        _showSnackBar(" فشل الإرسال: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar(" حدث خطأ في الاتصال", Colors.red);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedStudent = null;
      _selectedExam = null;
      _showErrors = false;
      _gradeController.clear();
      _noteController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("اسم الطالب"),
                _buildDropdown<Student>(
                  hint: "اختر اسم الطالب",
                  value: _selectedStudent,
                  items: widget.students
                      .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name,
                          style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStudent = v),
                ),
                if (_showErrors && _selectedStudent == null)
                  _buildErrorText("برجاء اختيار اسم الطالب"),

                const SizedBox(height: 25),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("اسم الاختبار"),
                          _buildDropdown<dynamic>(
                            hint: _statusMessage,
                            value: _selectedExam,
                            items: _exams.isEmpty
                                ? [
                              DropdownMenuItem(
                                  value: "retry",
                                  child: Text(
                                      "إعادة محاولة التحميل 🔄",
                                      style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 13)))
                            ]
                                : _exams
                                .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                    e["name"] ??
                                        e["examName"] ??
                                        "اختبار بدون اسم",
                                    style: const TextStyle(
                                        fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v == "retry") {
                                _fetchExams();
                              } else {
                                setState(() => _selectedExam = v);
                              }
                            },
                          ),
                          if (_showErrors && _selectedExam == null)
                            _buildErrorText("برجاء اختيار اسم الاختبار!"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("الدرجة"),
                          TextField(
                            controller: _gradeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: _inputDecoration("الدرجة"),
                          ),
                          if (_showErrors && _gradeController.text.isEmpty)
                            _buildErrorText("ادخل الدرجة!"),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                _buildLabel("التعليق"),
                TextField(
                  controller: _noteController,
                  maxLines: 5,
                  decoration: _inputDecoration("اكتب هنا..."),
                ),
                if (_showErrors && _noteController.text.isEmpty)
                  _buildErrorText("تعليق المعلم مطلوب!"),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD17820),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _submitGrading,
                    child: const Text("حفظ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: Colors.red))
          ],
        ),
      ),
    );
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5, right: 5),
      child: Text(text, style: const TextStyle(color: Colors.red, fontSize: 11)),
    );
  }

  Widget _buildDropdown<T>(
      {required String hint,
        T? value,
        required List<DropdownMenuItem<T>> items,
        required Function(T?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          value: items.any((item) => item.value == value) ? value : null,
          items: items,
          onChanged: (val) => onChanged(val),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4)),
      enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4)),
      focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF07427C)),
          borderRadius: BorderRadius.circular(4)),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "تأكيد إرسال تقييم الطالب؟",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD17820)),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD17820),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4))),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("تأكيد",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD17820),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4))),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("إلغاء",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    ) ??
        false;
  }
}