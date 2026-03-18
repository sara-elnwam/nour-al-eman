import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/login_screen.dart';
import 'teacher_model.dart';
import 'attendance_history_screen.dart';
import 'package:project1/teacher/curriculum/curriculum_screen.dart';
import 'sessions_screen.dart';
import 'groups_screen.dart';
import 'main_attendance_widget.dart';

// --- الألوان الثابتة ---
final Color primaryOrange = Color(0xFFC66422);
final Color darkBlue = Color(0xFF2E3542);
const Color kActiveBlue = Color(0xFF1976D2);
const Color kLabelGrey = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);

// --- موديل مواعيد الدرس ---
List<SessionRecord> sessionRecordFromJson(String str) =>
    List<SessionRecord>.from(json.decode(str).map((x) => SessionRecord.fromJson(x)));

class SessionRecord {
  int? id;
  String? name;
  Level? level;
  Location? loc;
  List<GroupSession>? groupSessions;

  SessionRecord({this.id, this.name, this.level, this.loc, this.groupSessions});

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: json["id"],
    name: json["name"],
    level: json["level"] == null ? null : Level.fromJson(json["level"]),
    loc: json["loc"] == null ? null : Location.fromJson(json["loc"]),
    groupSessions: json["groupSessions"] == null
        ? null
        : List<GroupSession>.from(json["groupSessions"].map((x) => GroupSession.fromJson(x))),
  );
}

class Level { String? name; Level({this.name}); factory Level.fromJson(Map<String, dynamic> json) => Level(name: json["name"]); }
class Location { String? name; Location({this.name}); factory Location.fromJson(Map<String, dynamic> json) => Location(name: json["name"]); }
class GroupSession {
  int? day; String? hour;
  GroupSession({this.day, this.hour});
  factory GroupSession.fromJson(Map<String, dynamic> json) => GroupSession(day: json["day"], hour: json["hour"]);

  String get dayName {
    switch (day) {
      case 1: return "السبت"; case 2: return "الأحد"; case 3: return "الإثنين";
      case 4: return "الثلاثاء"; case 5: return "الأربعاء"; case 6: return "الخميس";
      case 7: return "الجمعة"; default: return "";
    }
  }
}

class TeacherHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData; // ← أضف ده
  TeacherHomeScreen({this.loginData});
  @override
  _TeacherHomeScreenState createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  // جعلنا "الرئيسية" هي الصفحة الافتراضية عند الفتح
  String _currentTitle = "الرئيسية";
  bool _isLoading = true;
  TeacherData? teacherData;
  List<SessionRecord> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchTeacherProfile(); // دايماً جيبي البروفايل في البداية
    if (_currentTitle == "مواعيد الدرس") {
      await _fetchSessions();
    }
    if (mounted) setState(() => _isLoading = false);
  }
  Future<void> _fetchTeacherProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginDataStr = prefs.getString('loginData');
      if (loginDataStr == null) return;

      final loginData = jsonDecode(loginDataStr);

      String? numericId = loginData['userId']?.toString();
      String? guid = loginData['user_Id']?.toString() ?? loginData['id']?.toString();

      debugPrint("🔑 numericId=$numericId | guid=$guid");

      // لو عندنا numeric id استخدمه
      if (numericId != null && numericId.isNotEmpty && numericId != "null" && numericId != "0") {
        final response = await http.get(
            Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetById?id=$numericId')
        );
        debugPrint("📥 Status: ${response.statusCode} | Body: ${response.body}");
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (mounted) setState(() => teacherData = TeacherModel.fromJson(decoded).data);
          // ✅ احفظ locId عشان شاشة الحضور تستخدمه
          final locId = decoded['data']?['locId'];
          if (locId != null) {
            final p = await SharedPreferences.getInstance();
            await p.setInt('user_loc_id', locId as int);
            debugPrint("✅ Teacher Saved user_loc_id: $locId");
          }
        }
      }
      // لو مفيش numeric id، استخدم بيانات الـ loginData مباشرة
      else if (guid != null && guid.isNotEmpty) {
        debugPrint("⚠️ No numeric ID, using loginData directly");
        if (mounted) {
          setState(() {
            teacherData = TeacherData(
              id: null,
              name: loginData['userName']?.toString(),
              phone: loginData['phoneNumber']?.toString(),
              joinDate: null,
              educationDegree: null,
              loc: null,
              courses: null,
            );
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }
  Future<void> _fetchSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('user_id');

      if (id == null || id.isEmpty) {
        print("Error: No User ID found");
        return;
      }

      final response = await http.get(Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetSessionRecord?emp_id=$id'));
      if (response.statusCode == 200) {
        setState(() => _sessions = sessionRecordFromJson(response.body));
      }
    } catch (e) { debugPrint(e.toString()); }
    setState(() => _isLoading = false);
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
          title: Text(_currentTitle, style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 16)),
          centerTitle: true,
          iconTheme: IconThemeData(color: darkBlue),
        ),
        drawer: _buildTeacherSidebar(context),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _isLoading
              ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator(color: kActiveBlue))
              : KeyedSubtree(key: ValueKey(_currentTitle), child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTitle) {
      case "الرئيسية":
        return MainAttendanceScreen();
      case "البيانات الشخصية":
        return _buildProfileBody();
      case "المنهج / المقرر":
        return CurriculumScreen();
      case "المجموعات":
        return GroupsScreen();
      case "مواعيد الدرس":
        return _buildSessionsBody();
      default:
        return Center(child: Text("قريباً: $_currentTitle", style: TextStyle(fontFamily: 'Almarai', color: darkBlue)));
    }
  }

  Widget _buildProfileBody() {
    if (teacherData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text("تعذر تحميل البيانات", style: TextStyle(fontFamily: 'Almarai', color: Colors.red, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Almarai')),
              onPressed: () async {
                setState(() => _isLoading = true);
                await _fetchTeacherProfile();
                if (mounted) setState(() => _isLoading = false);
              },
            ),
          ],
        ),
      );
    }

    // تاريخ الالتحاق بأمان
    String joinDateStr = "---";
    if (teacherData!.joinDate != null) {
      final d = teacherData!.joinDate!;
      joinDateStr = "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard("بيانات المعلم", Icons.badge_outlined, [
          _infoRow("اسم المعلم :", teacherData?.name ?? "---"),
          _infoRow("كود المعلم :", teacherData?.id?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", teacherData?.loc?.name ?? "---"),
          _infoRow("تاريخ الالتحاق :", joinDateStr),
          _infoRow("المؤهل الدراسي :", teacherData?.educationDegree ?? "---"),
        ]),
        const SizedBox(height: 16),
        _buildInfoCard("الدورات التدريبية", Icons.school_outlined, [
          if (teacherData?.courses == null || teacherData!.courses!.isEmpty)
            const Center(
              child: Text("لا توجد دورات", style: TextStyle(color: Colors.red, fontFamily: 'Almarai')),
            )
          else
            ...teacherData!.courses!.map((c) => _infoRow("اسم الدورة :", c.toString())).toList(),
        ]),
      ],
    );
  }
  // --- واجهة مواعيد الدرس ---
  Widget _buildSessionsBody() {
    // فحص شامل: مفيش sessions أو كل sessions مفيهاش groupSessions
    final bool hasNoData = _sessions.isEmpty ||
        _sessions.every((s) => s.groupSessions == null || s.groupSessions!.isEmpty);

    if (hasNoData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const SizedBox(height: 16),
            const Text(
              'لم يتم تحديد المواعيد أو المجموعات بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text("جدول المواعيد", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue, fontFamily: 'Almarai')),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: DataTable(
              columnSpacing: 25,
              headingRowHeight: 50,
              dataRowHeight: 60,
              headingRowColor: WidgetStateProperty.all(kActiveBlue.withOpacity(0.05)),
              columns: const [
                DataColumn(label: Text('اليوم', style: _headerStyle)),
                DataColumn(label: Text('الساعة', style: _headerStyle)),
                DataColumn(label: Text('المجموعة', style: _headerStyle)),
                DataColumn(label: Text('المستوى', style: _headerStyle)),
                DataColumn(label: Text('المكتب', style: _headerStyle)),
              ],
              rows: _buildSessionRows(),
            ),
          ),
        ),
      ],
    );
  }

  List<DataRow> _buildSessionRows() {
    List<DataRow> rows = [];
    for (var record in _sessions) {
      if (record.groupSessions != null) {
        for (var s in record.groupSessions!) {
          rows.add(DataRow(cells: [
            DataCell(Center(child: Text(s.dayName, style: _cellStyleBold))),
            DataCell(Center(child: Text(s.hour ?? "", style: _cellStyle))),
            DataCell(Center(child: Text(record.name ?? "", style: _cellStyle))),
            DataCell(Center(child: Text(record.level?.name ?? "", style: _cellStyle))),
            DataCell(Center(child: Text(record.loc?.name ?? "", style: _cellStyle))),
          ]));
        }
      }
    }
    return rows;
  }

  static const TextStyle _headerStyle = TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, color: kActiveBlue, fontSize: 14);
  static const TextStyle _cellStyle = TextStyle(fontFamily: 'Almarai', color: Color(0xFF2E3542), fontSize: 13);
  static const TextStyle _cellStyleBold = TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 13);

  // --- السايدبار الموحد (نسخة مصححة) ---
  Widget _buildTeacherSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // لوجو التطبيق في الأعلى
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            child: Center(
              child: Image.asset(
                'assets/full_logo.png',
                height: 80,
                errorBuilder: (c, e, s) => Icon(Icons.school, size: 60, color: primaryOrange),
              ),
            ),
          ),

          // جميع العناصر في قائمة واحدة قابلة للتمرير
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(Icons.home_outlined, "الرئيسية"), // تأكد أن الاسم يطابق الـ switch case
                _buildSidebarItem(Icons.person_outline, "البيانات الشخصية"),
                _buildSidebarItem(
                  Icons.fact_check_outlined,
                  "الحضور و الإنصراف",
                  isPushScreen: true,
                  screen: AttendanceHistoryScreen(),
                ),
                _buildSidebarItem(Icons.menu_book_outlined, "المنهج / المقرر"),
                _buildSidebarItem(Icons.groups_outlined, "المجموعات"),
                _buildSidebarItem(Icons.access_time, "مواعيد الدرس"),
              ],
            ),
          ),

          const Divider(height: 1),
          SafeArea(
            top: false, // مش عايزين مساحة من فوق
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0), // مسافة بسيطة
              child: _buildSidebarItem(
                Icons.logout,
                "تسجيل الخروج",
                color: Colors.redAccent,
                isLogout: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSidebarItem(IconData icon, String title,
      {Color? color, bool isLogout = false, bool isPushScreen = false, Widget? screen}) {
    bool isSelected = _currentTitle == title;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? kActiveBlue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isSelected ? kActiveBlue : (color ?? darkBlue),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? kActiveBlue : (color ?? darkBlue),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Almarai',
          ),
        ),
        onTap: () async {
          if (isLogout) {
            Navigator.pop(context);
            _showLogoutDialog();
            return;
          }

          if (isPushScreen && screen != null) {
            // نحفظ الصفحة الحالية ونفتح الصفحة الجديدة
            // لما المستخدم يرجع، الـ _currentTitle يفضل على الرئيسية مش على البيانات الشخصية
            setState(() => _currentTitle = "الرئيسية");
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
            return;
          }

          // نحدث الـ state أولاً قبل إغلاق الدراور — يمنع الـ lag
          if (_currentTitle != title) {
            setState(() => _currentTitle = title);
          }
          Navigator.pop(context);

          if (title == "مواعيد الدرس" && _sessions.isEmpty) {
            setState(() => _isLoading = true);
            await _fetchSessions();
            if (mounted) setState(() => _isLoading = false);
          }

          if (title == "البيانات الشخصية" && teacherData == null) {
            setState(() => _isLoading = true);
            await _fetchTeacherProfile();
            if (mounted) setState(() => _isLoading = false);
          }
        },
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("تسجيل الخروج", style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold)),
          content: const Text("هل أنت متأكد؟", style: TextStyle(fontFamily: 'Almarai')),
          actions: [
            TextButton(child: const Text("إلغاء"), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                // ✅ احتفظ بسجلات الحضور المحلية - امسح بس بيانات الـ session
                final allKeys = prefs.getKeys();
                for (final key in allKeys) {
                  if (!key.startsWith('local_attendance_')) {
                    await prefs.remove(key);
                  }
                }
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => LoginScreen()), (r) => false);
              },
              child: const Text("خروج", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: kActiveBlue, size: 22), const SizedBox(width: 10), Text(title, style: TextStyle(color: kActiveBlue, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Almarai'))]),
          ),
          const Divider(height: 1, color: kBorderColor),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kLabelGrey, fontSize: 14, fontFamily: 'Almarai')),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: TextStyle(color: darkBlue, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Almarai'), textAlign: TextAlign.left)),
        ],
      ),
    );
  }
}