import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'session_model.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'student_attendance_screen.dart' as attendance;
import 'session_model.dart';
import 'grading_exams_screen.dart';
class GroupDetailsDashboard extends StatefulWidget {
  final int groupId;
  final int levelId;
  final String groupName;

  const GroupDetailsDashboard({
    super.key,
    required this.groupId,
    required this.levelId,
    required this.groupName,
  });

  @override
  State<GroupDetailsDashboard> createState() => _GroupDetailsDashboardState();
}

class _GroupDetailsDashboardState extends State<GroupDetailsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    final String url = 'https://nourelman.runasp.net/api/Group/GetGroupDetails?GroupId=${widget.groupId}&LevelId=${widget.levelId}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List rawStudents = jsonData["data"] is List ? jsonData["data"] : (jsonData["data"]["students"] ?? []);
        setState(() {
          _students = rawStudents.map((x) => Student.fromJson(x)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.groupName,
            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF07427C),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF07427C),
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Almarai',
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Almarai',
                ),
                tabs: const [
                  Tab(text: "الطلاب"),
                  Tab(text: "تسجيل الحضور"),
                  Tab(text: "تصحيح الاختبارات"),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF07427C)))
            : TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStudentsTable(),
            attendance.StudentAttendanceScreen(
              groupId: widget.groupId,
              students: _students.map((s) => attendance.Student(id: s.id, name: s.name)).toList(),
            ),
            GradingExamsScreen(
              groupId: widget.groupId,
              levelId: widget.levelId,
              students: _students,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildStudentsTable() {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            children: const [
              Expanded(flex: 5, child: Center(child: Text("الإسم", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              Expanded(flex: 2, child: Center(child: Text("أبحاث", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              Expanded(flex: 3, child: Center(child: Text("سؤال أسبوعي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              Expanded(flex: 2, child: Center(child: Text("بيانات", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: ListView.separated(
            itemCount: _students.length,
            separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (c, i) {
              final s = _students[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        s.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, fontFamily: 'Almarai'),
                      ),
                    ),
                    // أبحاث
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.search, color: Color(0xFF07427C), size: 20),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (c) => StudentExamsScreen(
                                    studentId: s.id,
                                    studentName: s.name,
                                    groupId: widget.groupId,
                                    levelId: widget.levelId,
                                  )
                              )
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF07427C), size: 18),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => WeeklyQuestionsScreen(studentId: s.id, studentName: s.name))),
                        ),
                      ),
                    ),
                    // بيانات
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.person, color: Color(0xFF07427C), size: 20),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => StudentProfileScreen(studentId: s.id))),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StudentProfileScreen extends StatefulWidget {
  final int studentId;
  const StudentProfileScreen({super.key, required this.studentId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  String _formatDate(dynamic dateValue) {
    final String today = DateTime.now().toString().split(" ")[0];

    if (dateValue == null ||
        dateValue.toString().isEmpty ||
        dateValue.toString().toLowerCase() == "null") {
      return today;
    }

    try {
      String dateStr = dateValue.toString();

      if (dateStr.startsWith("0001") || dateStr.startsWith("1970")) {
        return today;
      }

      if (dateStr.contains("T")) {
        return dateStr.split("T")[0];
      }

      return dateStr;
    } catch (e) {
      return today;
    }
  }
  Future<void> _fetchDetails() async {
    final url = "https://nourelman.runasp.net/api/Student/GetById?id=${widget.studentId}";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        setState(() {
          _data = json.decode(res.body)["data"];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          title: const Text("البيانات الشخصية", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF07427C)))
            : _data == null
            ? const Center(child: Text("خطأ في تحميل البيانات"))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInfoCard(
                title: "بيانات الطالب",
                icon: Icons.badge_outlined,
                rows: [
                  _buildDataRow("اسم الطالب :", _data!["name"] ?? "--"),
                  _buildDataRow("كود الطالب :", _data!["id"].toString()),
                  _buildDataRow("المكتب التابع له :", _data!["loc"]?["name"] ?? "--"),
                  _buildDataRow("اسم المدرسة الحكومية :", _data!["governmentSchool"] ?? "--"),
                  _buildDataRow("موعد الالتحاق :", _formatDate(_data!["joinDate"])),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoCard(
                title: "المدرسة",
                icon: Icons.school_outlined,
                rows: [
                  _buildDataRow("مجموعة :", _data!["group"]?["name"] ?? "--"),
                  _buildDataRow("المستوى :", _data!["level"]?["name"] ?? "--"),
                  _buildDataRow("اسم المعلم :", _data!["group"]?["emp"]?["name"] ?? "--"),
                  _buildDataRow("الحضور :", _data!["attendanceType"]?.toString() ?? "--"),
                  _buildDataRow("موعد الحلقة :", _formatSessions(_data!["group"]?["groupSessions"])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF07427C), size: 22),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF07427C))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)),
          Flexible(child: Text(value, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  String _formatSessions(List? sessions) {
    if (sessions == null || sessions.isEmpty) return "--";
    final days = {1: "السبت", 2: "الأحد", 3: "الإثنين", 4: "الثلاثاء", 5: "الأربعاء", 6: "الخميس", 7: "الجمعة"};
    try {
      return sessions.map((s) => "${days[s['day']]} ${s['hour']}").join(" - ");
    } catch (e) {
      return "--";
    }
  }
}

class WeeklyQuestionsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  const WeeklyQuestionsScreen({super.key, required this.studentId, required this.studentName});

  @override
  State<WeeklyQuestionsScreen> createState() => _WeeklyQuestionsScreenState();
}

class _WeeklyQuestionsScreenState extends State<WeeklyQuestionsScreen> {
  bool _isLoading = true;
  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final String url = "https://nourelman.runasp.net/api/Student/GetAllExamBsedOnType?StId=${widget.studentId}&TypeId=1";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        setState(() => _questions = decoded["data"] ?? []);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGrade(int examId, String grade, String note) async {
    const String postUrl = "https://nourelman.runasp.net/api/StudentCources/AddStudentExamAsync";
    try {
      final response = await http.post(
        Uri.parse(postUrl),
        headers: {"Content-Type": "application/json", "Accept": "text/plain"},
        body: jsonEncode({
          "stId": widget.studentId,
          "examId": examId,
          "grade": int.tryParse(grade) ?? 0,
          "note": note,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(" تم حفظ التقييم بنجاح"), backgroundColor: Colors.green));
          _fetch();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(" خطأ في الإرسال"), backgroundColor: Colors.red));
    }
  }

  void _showGradingDialog(dynamic item, bool isGraded) {
    String safeText(dynamic val) {
      if (val == null) return "";
      final s = val.toString().trim();
      return (s.isEmpty || s.toLowerCase() == "null") ? "" : s;
    }
    final TextEditingController noteController = TextEditingController(text: safeText(item["note"]));
    final TextEditingController gradeController = TextEditingController(text: safeText(item["grade"]));
    final exam = item["exam"] ?? {};
    final int examId = exam["id"] ?? 0;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isGraded ? "التقييم" : "اضافة تقييم",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF07427C))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text("التعليق", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    readOnly: isGraded,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: "اكتب هنا...",
                      filled: isGraded,
                      fillColor: isGraded ? Colors.grey.shade100 : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("نقاط الطالب *", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: gradeController,
                    keyboardType: TextInputType.number,
                    readOnly: isGraded,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: "ادخل النقاط",
                      filled: isGraded,
                      fillColor: isGraded ? Colors.grey.shade100 : null,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD17820), padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () {
                        if (!isGraded) {
                          _submitGrade(examId, gradeController.text, noteController.text);
                        }
                        Navigator.pop(context);
                      },
                      child: Text(isGraded ? "إغلاق" : "حفظ التقييم", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          title: const Text("الأسئلة الأسبوعية", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF07427C)))
            : _questions.isEmpty
            ? const Center(child: Text("لا يوجد بيانات بعد", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
            : Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Center(child: Text("اسم السؤال", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))),
                  Expanded(flex: 3, child: Center(child: Text("وصف السؤال", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text("إجابة الطالب", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text("تقييم الإجابة", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final item = _questions[index];
                  final exam = item["exam"] ?? {};
                  final String? cleanNote = (item["note"] == null || item["note"].toString().trim().isEmpty || item["note"].toString().trim().toLowerCase() == "null") ? null : item["note"].toString().trim();
                  final String? cleanGrade = (item["grade"] == null || item["grade"].toString().trim().isEmpty || item["grade"].toString().trim().toLowerCase() == "null") ? null : item["grade"].toString().trim();
                  final bool isGraded = cleanGrade != null || cleanNote != null;
                  final String studentAnswer = cleanNote ?? "--";
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isGraded ? const Color(0xFF2E7D32) : const Color(0xFFC62828), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Center(child: Text(exam["name"] ?? "--", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
                        Expanded(flex: 3, child: Center(child: Text(exam["description"] ?? "--", style: const TextStyle(fontSize: 12), textAlign: TextAlign.center))),
                        Expanded(flex: 2, child: Center(child: Text(studentAnswer, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)))),
                        Expanded(flex: 2, child: Center(child: InkWell(
                          onTap: () => _showGradingDialog(item, isGraded),
                          child: Text(isGraded ? "رؤية التقييم" : "تقييم الإجابة", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF07427C), decoration: TextDecoration.underline)),
                        ))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentExamsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final int groupId;
  final int levelId;

  const StudentExamsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.groupId,
    required this.levelId,
  });

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String? _cleanValue(dynamic value) {
    if (value == null) return null;
    String str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == "null") return null;
    final lowerStr = str.toLowerCase();
    if (lowerStr.startsWith("null,")) {
      str = str.substring(5).trim();
    } else if (lowerStr.startsWith("null ")) {
      str = str.substring(5).trim();
    }
    if (str.isEmpty) return null;
    return str;
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final String url =
        "https://nourelman.runasp.net/api/Student/GetAllExamBsedOnType?StId=${widget.studentId}&TypeId=2";
    try {
      final res = await http.get(Uri.parse(url));
      debugPrint("StudentExams API Response: ${res.body.substring(0, res.body.length > 300 ? 300 : res.body.length)}");
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        List<dynamic> rawData = decoded["data"] ?? [];
        final normalized = rawData.map((item) {
          debugPrint(" RAW ITEM: ${jsonEncode(item)}");
          final exam = item["exam"] ?? item["ex"] ?? {};
          final studentExams = exam["studentExams"] as List?;
          final firstExam = (studentExams != null && studentExams.isNotEmpty) ? studentExams[0] : null;
          final rawGrade = _cleanValue(item["grade"]) ??
              _cleanValue(item["gr"]) ??
              _cleanValue(firstExam?["grade"]);
          final rawNote = _cleanValue(item["note"]) ??
              _cleanValue(item["no"]) ??
              _cleanValue(firstExam?["note"]);

          debugPrint(" EXAM: ${exam["name"]} | grade=$rawGrade | note=$rawNote | firstExam=$firstExam");
          return {
            "exam": exam,
            "grade": rawGrade,
            "note": rawNote,
            "studentId": item["studentId"] ?? item["stId"] ?? item["st"],
          };
        }).toList();
        setState(() => _tasks = normalized);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _submitGrade(int examId, String grade, String note) async {
    final int gradeInt = int.tryParse(grade) ?? 0;
    debugPrint(" SUBMIT: stId=${widget.studentId}, examId=$examId, grade=$gradeInt, note=$note");
    try {
      final postResponse = await http.post(
        Uri.parse("https://nourelman.runasp.net/api/StudentCources/AddStudentExamAsync"),
        headers: {"Content-Type": "application/json", "Accept": "text/plain"},
        body: jsonEncode({
          "stId": widget.studentId,
          "examId": examId,
          "grade": gradeInt,
          "note": note,
        }),
      );
      debugPrint("📥 POST RESPONSE: ${postResponse.statusCode} | ${postResponse.body}");

      final postBody = jsonDecode(postResponse.body);
      final bool isDuplicate = postBody["error"] != null &&
          postBody["error"].toString().contains("duplicate key");

      if (postResponse.statusCode == 200 && !isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ تم حفظ التقييم"), backgroundColor: Colors.green));
          await _fetch();
        }
        return true;
      }
      if (isDuplicate) {
        debugPrint(" Duplicate key detected, trying PUT UpdateStudentExam...");
        final putUri = Uri.parse(
          "https://nourelman.runasp.net/api/StudentCources/UpdateStudentExam"
              "?StID=${widget.studentId}&ExamId=$examId&Grade=$gradeInt&Note=${Uri.encodeComponent(note)}",
        );
        final putResponse = await http.put(
          putUri,
          headers: {"Accept": "text/plain"},
        );
        debugPrint(" PUT RESPONSE: ${putResponse.statusCode} | ${putResponse.body}");

        if (putResponse.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ تم تحديث التقييم"), backgroundColor: Colors.green));
            await _fetch();
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
    return false;
  }

  void _showGradingDialog(dynamic item, bool isGraded) {
    final exam = item["exam"] ?? item["ex"] ?? {};
    final int examId = exam["id"] ?? 0;
    final TextEditingController gradeController = TextEditingController(
        text: item["grade"]?.toString() ?? "");
    final TextEditingController noteController = TextEditingController(
        text: item["note"]?.toString() ?? "");

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isGraded ? "التقييم" : "اضافة تقييم",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF07427C), fontFamily: "Almarai")),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  if (!isGraded || noteController.text.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("التعليق", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "Almarai")),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      readOnly: isGraded,
                      decoration: InputDecoration(
                        hintText: "اكتب هنا...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: isGraded,
                        fillColor: isGraded ? Colors.grey.shade100 : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text("نقاط الطالب *", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: "Almarai")),
                  const SizedBox(height: 8),
                  TextField(
                    controller: gradeController,
                    keyboardType: TextInputType.number,
                    readOnly: isGraded,
                    decoration: InputDecoration(
                      hintText: "ادخل النقاط",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: isGraded,
                      fillColor: isGraded ? Colors.grey.shade100 : null,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD17820), padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () async {
                        if (!isGraded) {
                          Navigator.pop(ctx);
                          await _submitGrade(examId, gradeController.text, noteController.text);
                        } else {
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(isGraded ? "إغلاق" : "حفظ التقييم", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startDownload(String? relativeUrl, String examName) async {
    if (relativeUrl == null || relativeUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("رابط الملف غير متوفر"), backgroundColor: Colors.red));
      }
      return;
    }
    final String url = relativeUrl.startsWith('http')
        ? relativeUrl
        : "https://nourelman.runasp.net$relativeUrl";
    final String ext = relativeUrl.contains('.')
        ? relativeUrl.split('.').last.split('?').first.toLowerCase()
        : 'pdf';
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) await directory.create(recursive: true);

      String finalFileName = "${examName.replaceAll(' ', '_')}.$ext";

      await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory.path,
        fileName: finalFileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
        headers: {"Accept": "*/*"},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⬇️ جاري التحميل...", style: TextStyle(fontFamily: "Almarai")),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ));
      }
    } catch (e) {
      debugPrint("Download Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("أبحاث: ${widget.studentName}",
              style: const TextStyle(fontFamily: "Almarai", fontSize: 16)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _tasks.isEmpty
            ? const Center(
          child: Text(
            "لا يوجد بيانات بعد",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: "Almarai",
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final item = _tasks[index];
            final exam = item["exam"] ?? {};

            final gradeVal = item["grade"];
            final bool isGraded = gradeVal != null;
            debugPrint(" BUILD item ${exam["name"]} | gradeVal=$gradeVal | isGraded=$isGraded");
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isGraded ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _startDownload(exam["url"], exam["name"] ?? "research"),
                        child: Row(
                          children: const [
                            Icon(Icons.download_rounded, color: Color(0xFFD17820), size: 18),
                            SizedBox(width: 4),
                            Text("تحميل", style: TextStyle(color: Color(0xFFD17820), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showGradingDialog(item, isGraded),
                        child: Text(
                          isGraded ? "رؤية التقييم" : "تقييم البحث",
                          style: const TextStyle(color: Color(0xFF07427C), fontSize: 12, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "الإسم: ${exam["name"] ?? "--"}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "الوصف: ${exam["description"] ?? "--"}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}