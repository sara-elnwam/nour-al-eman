import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_logs_tab.dart';
import 'teacher_schedule_tab.dart';
import 'edit_teacher_screen.dart';
// توحيد الألوان مع تصميم الطالب
const Color kPrimaryBlue = Color(0xFF07427C);
const Color kTextDark = Color(0xFF2E3542);
const Color kBgGrey = Color(0xFFF8FAFC);

class StaffDetailsScreen extends StatefulWidget {
  final int staffId;
  final String staffName;

  const StaffDetailsScreen({super.key, required this.staffId, required this.staffName});

  @override
  _StaffDetailsScreenState createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends State<StaffDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? staffData;
  bool isLoadingInfo = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    // تم تغيير الطول إلى 3
    _tabController = TabController(length: 3, vsync: this);
    _fetchStaffInfo();
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStaffInfo() async {
    setState(() {
      isLoadingInfo = true;
      errorMessage = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // تأكدي من إضافة ${widget.staffId} في نهاية الرابط هنا:
      final String url = 'https://nour-al-eman.runasp.net/api/Employee/GetById?id=${widget.staffId}';
      print("Requesting URL: $url");

      final response = await http.get(
        Uri.parse(url), // استخدام المتغير الذي يحتوي على الـ ID
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      debugPrint("Full Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);

        setState(() {
          if (decoded['error'] == null &&
              decoded['data'] != null &&
              (decoded['data'] as Map).isNotEmpty) {

            staffData = Map<String, dynamic>.from(decoded['data']);
            isLoadingInfo = false;
          } else {
            errorMessage = "الموظف غير موجود أو لا توجد صلاحيات لعرضه (ID: ${widget.staffId})";
            isLoadingInfo = false;
          }
        });
      } else {
        setState(() {
          errorMessage = "خطأ في السيرفر: ${response.statusCode}";
          isLoadingInfo = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() {
        errorMessage = "حدث خطأ أثناء تحميل البيانات: $e";
        isLoadingInfo = false;
      });
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
            staffData?['name'] ?? widget.staffName,
            style: const TextStyle(color: kTextDark, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
          iconTheme: const IconThemeData(color: kTextDark),
          // داخل AppBar في ملف staff_details_screen.dart
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: Color(0xFF1976D2), size: 26),
              onPressed: () {
                if (staffData != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditTeacherScreen(staffData: staffData!),
                    ),
                  ).then((_) => _fetchStaffInfo()); // تحديث البيانات بعد العودة من التعديل
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: kPrimaryBlue,
            indicatorColor: kPrimaryBlue,
            labelStyle: const TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "البيانات الشخصية"),
              Tab(text: "سجل الحضور"),
              Tab(text: "جدول الشيخ"), // التبويب الجديد
            ],
          ),
        ),
        // داخل دالة build في الـ Scaffold body
        body: isLoadingInfo
            ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
            : errorMessage.isNotEmpty
            ? _buildErrorWidget()
            :// 2. في الـ TabBarView استبدلي السطر القديم بـ:
        // ابحثي عن التبويب الثالث وغيريه ليكون هكذا:
        TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            AttendanceLogsTab(empId: widget.staffId),
            TeacherScheduleTab(empId: widget.staffId), // استدعاء الجدول هنا
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Almarai', fontSize: 15)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchStaffInfo,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
            child: const Text("إعادة المحاولة", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
          ),
        ],
      ),
    );
  }
  Widget _buildInfoTab() {
    if (staffData == null) return const Center(child: Text("لا توجد بيانات"));
    // دالة لمعالجة التاريخ: إذا كان نل أو غير منطقي يرجع تاريخ اليوم
    String formatDateTime(dynamic dateValue) {
      if (dateValue == null) return "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

      String dateStr = dateValue.toString();
      if (dateStr.startsWith("0001") || dateStr.isEmpty) {
        return "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      }
      return dateStr.split('T')[0];
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // الكارت الأول: بيانات الموظف
        _buildSectionCard("بيانات الموظف", Icons.badge_outlined, [
          _infoRow("اسم المعلم :", staffData!['name'] ?? "---"),
          _infoRow("كود المعلم :", staffData!['id']?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", staffData!['loc']?['name'] ?? "---"),
          _infoRow("موعد الالتحاق بالمدرسة :", formatDateTime(staffData!['joinDate'])),
          _infoRow("المؤهل الدراسي :", staffData!['educationDegree'] ?? "---"),
        ]),

        const SizedBox(height: 20), // مسافة بين الكارتين

        // الكارت الجديد: الدورات التدريبية الحاصل عليها
        _buildSectionCard("الدورات التدريبية الحاصل عليها", Icons.school_outlined, [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "لا توجد دورات تدريبية",
                style: TextStyle(
                  color: Colors.red, // اللون الأحمر كما طلبتِ
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ]),
      ],
    );
  }
  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              // تم التغيير ليكون المحاذات لليمين (بداية السطر)
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: kPrimaryBlue, size: 20),
                const SizedBox(width: 8), // مسافة صغيرة بين الأيقونة والنص
                Text(
                  title,
                  style: const TextStyle(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Almarai',
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Almarai')),
          Text(value, style: const TextStyle(color: kTextDark, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Almarai')),
        ],
      ),
    );
  }
}