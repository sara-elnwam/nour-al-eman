import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/login_screen.dart';
import 'employee_model.dart';
import 'employee_attendance_screen.dart';
import 'student_details/students_screen.dart';
import 'employees_details/all_employees_screen.dart';
import 'employee_attendance_history_screen.dart';
import 'reports_screen/reports_screen.dart';
import 'staff_management_screen/staff_management_screen.dart';
import 'waiting_list_screen/waiting_list_screen.dart';
import 'courses_screen/courses_screen.dart';
import 'branches_screen/branches_screen.dart';
import 'employee/employees_screen.dart';
import 'employee_attendance_screen.dart';
import 'employee_attendance_history_screen.dart';
import 'reports_screen/levels_screen/levels_screen.dart';
import 'facility_type_screen.dart'; // ✅ شاشة أنواع المصروفات
import 'expenses_screen.dart';      // ✅ شاشة المصروفات
import 'expenses_hub_screen.dart';  // ✅ هاب المصروفات


final Color primaryOrange = Color(0xFFC66422);
final Color darkBlue = Color(0xFF2E3542);
const Color kActiveBlue = Color(0xFF1976D2);
const Color kLabelGrey = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);

class EmployeeHomeScreen extends StatefulWidget {
  @override
  _EmployeeHomeScreenState createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  String _currentTitle = "الصفحة الرئيسية";
  int _currentIndex = 0;
  bool _isLoading = true;
  EmployeeData? employeeData;
  Map<String, dynamic>? _rawResponse;
  Key _historyKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _fetchEmployeeProfile();
  }

  Future<void> _fetchEmployeeProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? numericId = prefs.getString('user_id');

      debugPrint("📌 user_id = $numericId");

      if (numericId == null || numericId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final profileResponse = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetById?id=$numericId'),
      );

      debugPrint("📥 Status: ${profileResponse.statusCode}");
      debugPrint("📥 Body: ${profileResponse.body}");

      if (profileResponse.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(profileResponse.body);
        final employeeModel = EmployeeModel.fromJson(decodedData);
        if (mounted) {
          setState(() {
            _rawResponse = decodedData['data'];
            employeeData = employeeModel.data;
          });
        }
        final locId = decodedData['data']?['locId'];
        if (locId != null) {
          await prefs.setInt('user_loc_id', locId as int);
          debugPrint("✅ Saved user_loc_id: $locId");
        }
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(String title, int index) {
    setState(() {
      _currentIndex = index;
      _currentTitle = title;
      if (index == 2) {
        _historyKey = UniqueKey();
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          scrolledUnderElevation: 0,
          title: Text(_currentTitle,
              style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Almarai')),
          iconTheme: IconThemeData(color: darkBlue),
        ),
        drawer: _buildEmployeeSidebar(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kActiveBlue))
            : IndexedStack(
          index: _currentIndex,
          children: [
            MainAttendanceScreen(),                              // 0
            _buildPersonalDataContent(),                         // 1
            EmployeeAttendanceHistoryScreen(key: _historyKey),   // 2
            StudentsScreen(),                                    // 3
            AllEmployeesScreen(),                                // 4
            EmployeesScreen(),                                   // 5
            LevelsScreen(),                                      // 6
            const BranchesScreen(),                              // 7
            const CoursesScreen(),                               // 8
            WaitingListScreen(),                                 // 9
            StaffManagementScreen(),                             // 10
            ReportsScreen(),                                     // 11
            const ExpensesHubScreen(),                           // 12 ✅ هاب المصروفات
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDataContent() {
    String rawDate = employeeData?.joinDate?.toString() ?? "---";
    String formattedDate = (rawDate != "---" && rawDate.length >= 10)
        ? rawDate.substring(0, 10)
        : rawDate;

    String jobTitle = "---";
    if (_rawResponse != null && _rawResponse!['employeeType'] != null) {
      jobTitle = _rawResponse!['employeeType']['name'] ?? "---";
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard("بيانات الموظف", Icons.person_pin_outlined, [
          _infoRow("اسم الموظف :", employeeData?.name ?? "---"),
          _infoRow("كود الموظف :", employeeData?.id?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", employeeData?.loc?.name ?? "---"),
          _infoRow("موعد الالتحاق بالمدرسة :", formattedDate),
          _infoRow("المؤهل الدراسي :", employeeData?.educationDegree ?? "---"),
          _infoRow("المسمى الوظيفي :", jobTitle),
        ]),
      ],
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(child: Text("محتوى قسم: $title",
        style: const TextStyle(color: Colors.grey, fontFamily: 'Almarai')));
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: kActiveBlue, size: 22),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(color: kActiveBlue, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Almarai')),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          Padding(
            padding: const EdgeInsets.all(16),
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
          Text(label, style: const TextStyle(color: kLabelGrey, fontSize: 14, fontFamily: 'Almarai')),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
              style: TextStyle(color: darkBlue, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Almarai'),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            child: Center(
                child: Image.asset('assets/full_logo.png',
                    height: 80,
                    errorBuilder: (c, e, s) => const Icon(Icons.business, size: 50, color: kActiveBlue)
                )
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSidebarItem(Icons.home_outlined, "الصفحة الرئيسية", 0),
                  _buildSidebarItem(Icons.person_outline, "البيانات الشخصية", 1),
                  _buildSidebarItem(Icons.history, "سجل الحضور والإنصراف", 2),
                  _buildSidebarItem(Icons.school_outlined, "الطلاب", 3),
                  _buildSidebarItem(Icons.badge_outlined, "الموظفون", 4),
                  _buildSidebarItem(Icons.person_search_outlined, "المعلمون", 5),
                  _buildSidebarItem(Icons.layers_outlined, "المستويات و المجموعات", 6),
                  _buildSidebarItem(Icons.location_on_outlined, "الفروع", 7),
                  _buildSidebarItem(Icons.menu_book_outlined, "الدورات", 8),
                  _buildSidebarItem(Icons.hourglass_empty, "قائمة الإنتظار", 9),
                  _buildSidebarItem(Icons.manage_accounts_outlined, "إدارة الموظفين", 10),
                  _buildSidebarItem(Icons.assessment_outlined, "التقارير", 11),
                  _buildSidebarItem(Icons.account_balance_wallet_outlined, "المصروفات", 12),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          _buildSidebarItem(
              Icons.logout,
              "تسجيل الخروج",
              -1,
              color: Colors.redAccent,
              isLogout: true
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, int index, {Color? color, bool isLogout = false}) {
    bool isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? kActiveBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white, width: 0.5) : null,
        ),
        child: ListTile(
          visualDensity: VisualDensity.compact,
          leading: Icon(icon, color: isSelected ? Colors.white : (color ?? darkBlue), size: 22),
          title: Text(title, style: TextStyle(
              color: isSelected ? Colors.white : (color ?? darkBlue),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              fontFamily: 'Almarai')),
          onTap: () {
            if (isLogout) {
              _showLogoutDialog();
            } else {
              _onItemTapped(title, index);
            }
          },
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("تسجيل الخروج",
              style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          content: const Text("هل أنت متأكد أنك تريد تسجيل الخروج؟", style: TextStyle(fontFamily: 'Almarai')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Almarai'))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final allKeys = prefs.getKeys();
                for (final key in allKeys) {
                  if (!key.startsWith('local_attendance_')) {
                    await prefs.remove(key);
                  }
                }
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (c) => LoginScreen()),
                          (r) => false
                  );
                }
              },
              child: const Text("خروج", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }
}