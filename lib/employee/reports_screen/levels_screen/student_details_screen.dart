import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// التعديل هنا: التأكد من المسارات الصحيحة
import 'student_tests_tab.dart';
import 'student_attendance_tab.dart';
import 'edit_student_screen.dart';

const Color kPrimaryBlue = Color(0xFF07427C);
const Color kTextDark = Color(0xFF2E3542);
const Color kBgGrey = Color(0xFFF8FAFC);

class StudentDetailsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentDetailsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? studentData;
  bool isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStudentInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "غير محدد";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _fetchStudentInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Student/GetById?id=${widget.studentId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          var rawData = responseData['data'];

          // الحل هنا: لو السيرفر بعت قائمة [ ] ناخد أول عنصر، لو بعت كائن { } ناخده هو
          if (rawData is List && rawData.isNotEmpty) {
            studentData = rawData[0];
          } else if (rawData is Map<String, dynamic>) {
            studentData = rawData;
          }

          isLoadingInfo = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching info: $e");
      setState(() => isLoadingInfo = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBgGrey,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.studentName,
              style: const TextStyle(
                  color: kTextDark,
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: kTextDark),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: kPrimaryBlue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditStudentScreen(
                      studentId: widget.studentId,
                      initialData: studentData,
                    ),
                  ),
                ).then((value) {
                  if (value == true) _fetchStudentInfo();
                });
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: kPrimaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimaryBlue,
            labelStyle: const TextStyle(
                fontFamily: 'Almarai', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: "البيانات"),
              Tab(text: "الغياب"),
              Tab(text: "الاختبارات"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            StudentAttendanceTab(studentId: widget.studentId),
            StudentTestsTab(studentId: widget.studentId),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    if (isLoadingInfo) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
    }
    if (studentData == null) {
      return const Center(child: Text("تعذر تحميل البيانات"));
    }

    String joinDateDisplay;
    if (studentData!['joinDate'] == null) {
      joinDateDisplay = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    } else {
      joinDateDisplay = _formatDate(studentData!['joinDate']);
    }

    String age = "---";
    if (studentData!['birthDate'] != null) {
      try {
        DateTime birth = DateTime.parse(studentData!['birthDate']);
        DateTime today = DateTime.now();
        int years = today.year - birth.year;
        if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) {
          years--;
        }
        age = years.toString();
      } catch (e) {
        age = "---";
      }
    }

    // تجميع مواعيد الحلقة بشكل دقيق
    String sessionTimes = "---";

    if (studentData != null && studentData!['group'] != null) {
      final group = studentData!['group'];

      // الوصول لمصفوفة الجلسات (المواعيد)
      final List? sessions = group['groupSessions'];

      if (sessions != null && sessions.isNotEmpty) {
        // تحويل كل جلسة لنص (يوم وساعة) وجمعهم مع بعض
        sessionTimes = sessions.map((s) {
          String dayName = _getDayName(s['day'] ?? 0);
          String hour = s['hour'] ?? "";
          return "$dayName ($hour)";
        }).join(" - ");
      } else {
        // لو مفيش جلسات، جرب الحقول النصية القديمة كـ Backup
        final String d = group['days']?.toString() ?? "";
        final String t = group['time']?.toString() ?? "";
        if (d.isNotEmpty) sessionTimes = "$d ($t)";
      }
    } else {
      sessionTimes = "غير محدد"; // لو الـ group نفسه نال
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // تصغير البادينج الخارجي
      child: Column(
        children: [
          // الكارت الأول: بيانات الطالب
          _infoCard(
            title: "بيانات الطالب",
            children: [
              _infoRow("اسم الطالب", studentData!['name'] ?? "---"),
              _infoRow("كود الطالب", studentData!['id']?.toString() ?? "---"),
              _infoRow("المكتب التابع له", studentData!['loc']?['name'] ?? "---"),
              _infoRow("موعد الالتحاق بالمدرسة", joinDateDisplay),
              _infoRow("اسم المدرسة الحكومية", studentData!['governmentSchool'] ?? "---"),
              _infoRow("وظيفة ولي الأمر", (studentData!['parentJob'] == null || studentData!['parentJob'] == "") ? "---" : studentData!['parentJob']),
              _infoRow("العنوان", studentData!['address'] ?? "---"),
              _infoRow("رقم هاتف ولي الأمر", studentData!['phone'] ?? "---"),
              _infoRow("حالة الطالب", studentData!['attendanceType'] ?? "---"),
              _infoRow("حالة الدفع", studentData!['paymentType'] ?? "لم يحدد"),
              _infoRow("الكراسة", studentData!['documentType'] ?? "لا يوجد"),
              _infoRow("العمر", age),
            ],
          ),

          const SizedBox(height: 12), // تصغير المسافة بين الكارتين

          // الكارت الثاني: المدرسة
          _infoCard(
            title: "المدرسة",
            children: [
              _infoRow("مجموعة", studentData!['group']?['name'] ?? "---"),
              _infoRow("المستوى", studentData!['level']?['name'] ?? "---"),
              _infoRow("اسم المعلم", studentData!['group']?['emp']?['name'] ?? "---"),
              _infoRow("الحضور", studentData!['attendanceType'] ?? "---"),
              _infoRow("موعد الحلقة", sessionTimes),
            ],
          ),
        ],
      ),
    );
  }
  String _getDayName(int day) {
    switch (day) {
      case 1: return "السبت";
      case 2: return "الأحد";
      case 3: return "الاثنين";
      case 4: return "الثلاثاء";
      case 5: return "الأربعاء";
      case 6: return "الخميس";
      case 7: return "الجمعة";
      default: return "";
    }
  }

  // دالة لحساب العمر من تاريخ الميلاد
  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null) return "---";
    try {
      DateTime birthDate = DateTime.parse(birthDateStr);
      DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age.toString();
    } catch (e) {
      return "---";
    }
  }

  // دالة لتنسيق مواعيد الحلقة
  String _formatSessions(List<dynamic>? sessions) {
    if (sessions == null || sessions.isEmpty) return "---";
    return sessions.map((s) => "${s['day']} (${s['hour']})").join(" - ");
  }

  Widget _infoCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Almarai')),
                const Icon(Icons.info_outline, color: kPrimaryBlue, size: 20),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3), // قللت الـ 6 لـ 3 عشان الصفوف تقرب من بعض
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // عشان لو النص طويل ينزل صح
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 12, fontFamily: 'Almarai')), // صغرت الخط من 13 لـ 12
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Almarai'),
            ),
          ),
        ],
      ),
    );
  }
}