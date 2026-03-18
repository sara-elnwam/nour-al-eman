import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_tests_tab.dart';
import 'student_attendance_tab.dart';
import 'edit_student_screen.dart';

const Color kPrimaryBlue = Color(0xFF07427C);
const Color kTextDark = Color(0xFF2E3542);
const Color kBgGrey = Color(0xFFF8FAFC);

class StudentDetailsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentDetailsScreen({required this.studentId, required this.studentName});

  @override
  _StudentDetailsScreenState createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> with SingleTickerProviderStateMixin {
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
    if (dateStr == null || dateStr.isEmpty) return "---";
    try {
      DateTime dt = DateTime.parse(dateStr);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return "---";
    }
  }

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

  String _getDayName(int day) {
    // السيرفر بيبدأ من 1 = السبت (مطابق للـ Web)
    const days = {
      1: "السبت", 2: "الأحد", 3: "الإثنين", 4: "الثلاثاء", 5: "الأربعاء", 6: "الخميس", 7: "الجمعة",
    };
    return days[day] ?? "";
  }

  Future<void> _fetchStudentInfo() async {
    setState(() => isLoadingInfo = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Student/GetById?id=${widget.studentId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          print("DEBUG STUDENT DATA: ${response.body}");
          studentData = jsonDecode(response.body)['data'];
          isLoadingInfo = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingInfo = false);
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
          elevation: 0.5,
          centerTitle: false,
          title: Text(
            studentData?['name'] ?? widget.studentName, // استخدام الاسم المحدث من السيرفر إذا وجد
            style: const TextStyle(
              color: kTextDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: Color(0xFF1976D2), size: 24),
              onPressed: () {
                // التعديل هنا: تمرير studentData بالكامل
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditStudentScreen(
                      studentId: widget.studentId,
                      initialData: studentData, // البيانات القادمة من الـ API
                    ),
                  ),
                ).then((_) => _fetchStudentInfo()); // إعادة جلب البيانات بعد التعديل
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: kPrimaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kPrimaryBlue,
            tabs: const [
              Tab(text: "البيانات"),
              Tab(text: "الاختبارات"),
              Tab(text: "الحضور"),
            ],
          ),
        ),
        body: isLoadingInfo
            ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
            : TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            StudentTestsTab(studentId: widget.studentId),
            StudentAttendanceTab(studentId: widget.studentId),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    if (studentData == null) return const Center(child: Text("لا توجد بيانات"));

    List sessions = studentData!['group']?['groupSessions'] ?? [];
    String sessionTimes = sessions.map((s) => "${_getDayName(s['day'])} ${s['hour']}").join(' - ');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        _buildSectionCard("بيانات الطالب", [
          _infoRow("اسم الطالب :", studentData!['name'] ?? "---"),
          _infoRow("كود الطالب :", studentData!['id']?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", studentData!['loc']?['name'] ?? "---"),
          _infoRow("موعد الالتحاق بالمدرسة :", _formatDate(studentData!['joinDate'])),
          _infoRow("اسم المدرسة الحكومية :", studentData!['governmentSchool'] ?? "---"),
          _infoRow("وظيفة ولي الأمر :", studentData!['parentJob'] ?? "---"),
          _infoRow("العنوان :", studentData!['address'] ?? "---"),
          _infoRow("رقم هاتف ولي الأمر :", studentData!['phone'] ?? "---"),
          _infoRow("حالة الطالب :", studentData!['typeInfamily'] ?? "لم يتم التحديد بعد"),
          _infoRow("حالة الدفع :", studentData!['paymentType'] ?? "لم يتم التحديد بعد"),
          _infoRow("الكراسة :", studentData!['documentType'] ?? "لم يتم التحديد بعد"),
          _infoRow("العمر :", _calculateAge(studentData!['birthDate'])),
        ]),
        const SizedBox(height: 10),
        _buildSectionCard("المدرسة", [
          _infoRow("مجموعة :", studentData!['group']?['name'] ?? "---"),
          _infoRow("المستوى :", studentData!['level']?['name'] ?? "---"),
          _infoRow("اسم المعلم :", studentData!['group']?['emp']?['name'] ?? "---"),
          _infoRow("الحضور :", studentData!['attendanceType'] ?? "---"),
          _infoRow("موعد الحلقة :", sessionTimes.isEmpty ? "لم يتم التحديد" : sessionTimes),
        ]),
      ],
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                Text(title, style: const TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Almarai')),
                if (title == "المدرسة") const Icon(Icons.school_outlined, color: kPrimaryBlue, size: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Almarai')),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: kTextDark, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Almarai'),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}