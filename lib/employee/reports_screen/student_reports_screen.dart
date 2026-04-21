import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// استيراد الملفات الجديدة التي صممناها
import 'student_tasks_absence_screen.dart';
import 'levels_report_screen.dart';

class LevelModel {
  final int id;
  final String name;
  LevelModel({required this.id, required this.name});
  factory LevelModel.fromJson(Map<String, dynamic> json) =>
      LevelModel(id: json['id'] ?? 0, name: json['name'] ?? '');
}

class StudentModel {
  final int id;
  final String name;
  final int? levelId;
  StudentModel({required this.id, required this.name, this.levelId});
  factory StudentModel.fromJson(Map<String, dynamic> json) =>
      StudentModel(id: json['id'] ?? 0, name: json['name'] ?? '', levelId: json['levelId']);
}

class ReportResult {
  final String testName;
  final double score;
  final String date;
  ReportResult({required this.testName, required this.score, required this.date});
}

class StudentReportsScreen extends StatefulWidget {
  @override
  _StudentReportsScreenState createState() => _StudentReportsScreenState();
}

class _StudentReportsScreenState extends State<StudentReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  LevelModel? selectedLevel;
  StudentModel? selectedStudent;
  DateTime? fromDate;
  DateTime? toDate;
  final TextEditingController _resultsCountController = TextEditingController();

  List<LevelModel> levels = [];
  List<StudentModel> allStudents = [];
  List<StudentModel> filteredStudents = [];
  List<ReportResult> reportResults = [];

  bool isLoadingLevels = true;
  bool isLoadingStudents = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_fetchLevels(), _fetchStudents()]);
  }

  Future<void> _fetchLevels() async {
    try {
      final response = await http.get(Uri.parse("https://nour-al-eman.runasp.net/api/Level/Getall"));
      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          levels = (data['data'] as List).map((e) => LevelModel.fromJson(e)).toList();
          isLoadingLevels = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingLevels = false);
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final response = await http.get(Uri.parse("https://nour-al-eman.runasp.net/api/Student/Getall")
      );
      if (response.statusCode == 200) {
        var data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          allStudents = (data['data'] as List).map((e) => StudentModel.fromJson(e)).toList();
          filteredStudents = allStudents;
          isLoadingStudents = false;
        });
      }
    } catch (e) {
      setState(() => isLoadingStudents = false);
    }
  }

  Future<void> _submitReportRequest() async {
    setState(() => isSubmitting = true);
    final String apiUrl = "https://nour-al-eman.runasp.net/api/Reports/GetTestsReport"
    ;

    Map<String, dynamic> body = {
      "levelId": selectedLevel?.id,
      "studentId": selectedStudent?.id,
      "fromDate": fromDate != null ? DateFormat('yyyy-MM-dd').format(fromDate!) : null,
      "toDate": toDate != null ? DateFormat('yyyy-MM-dd').format(toDate!) : null,
      "topResults": int.tryParse(_resultsCountController.text) ?? 10,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم جلب البيانات بنجاح")));
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text("تقارير الطلاب ",
            style: TextStyle(color: Color(0xFF2E3542), fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E3542), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          // 1. اجعلها false إذا كنت تريد توزيع التبويبات بالتساوي على عرض الشاشة
          // أو اتركها true إذا كانت النصوص طويلة جداً وتريدها قابلة للتمرير
          isScrollable: false,

          indicatorColor: const Color(0xFFD97706),
          indicatorWeight: 3, // جعل الخط تحت التبويب أكثر وضوحاً
          indicatorSize: TabBarIndicatorSize.label, // الخط يكون على عرض النص فقط وليس التبويب كاملاً

          labelColor: const Color(0xFFD97706),
          unselectedLabelColor: Colors.grey.shade500,

          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
              fontSize: 14
          ),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontFamily: 'Almarai',
              fontSize: 13
          ),

          tabs: const [
            Tab(text: "الاختبارات"),
            Tab(text: "المهام"),
            Tab(text: "الغياب"),
            Tab(text: "المستويات"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. تبويب الاختبارات (الكود الموجود في نفس الملف)
          _buildTestsReportTab(),

          // 2. تبويب المهام (يستخدم الكلاس المشترك)
          StudentTasksAbsenceScreen(title: "", apiEndpoint: "Tasks/Getall"),

          // 3. تبويب الغياب (يستخدم الكلاس المشترك)
          StudentTasksAbsenceScreen(title: "تقارير الغياب", apiEndpoint: "Absence/Getall"),

          // 4. تبويب المستويات (التصميم العرضي)
          LevelsReportScreen(),
        ],
      ),
    );
  }

  // ويدجت محتوى تبويب الاختبارات
  Widget _buildTestsReportTab() {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("من"),
                  _buildDateBox(fromDate, (date) => setState(() => fromDate = date), "yyyy/MM/dd"),

                  const SizedBox(height: 20), // مسافة موحدة

                  _buildLabel("إلى"),
                  _buildDateBox(toDate, (date) => setState(() => toDate = date), "yyyy/MM/dd"),

                  const SizedBox(height: 20), // مسافة موحدة

                  _buildLabel("المستوى"),
                  isLoadingLevels ? const LinearProgressIndicator() : _buildLevelsDropdown(),

                  const SizedBox(height: 20), // مسافة موحدة

                  _buildLabel("الطالب"),
                  _buildStudentSearchField(),

                  const SizedBox(height: 20), // مسافة موحدة

                  _buildLabel("عدد النتائج العليا"),
                  _buildTextField("إختر عدد النتائج", _resultsCountController),

                  const SizedBox(height: 40), // مسافة أكبر قبل الزر ليفصل بين المدخلات والأكشن

                  Center(child: isSubmitting
                      ? const CircularProgressIndicator(color: Color(0xFFD97706))
                      : _buildSubmitButton()
                  ),
                ],
            ),
          ),
        ),
       ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: reportResults.isEmpty
                ? const Center(child: Text("جاري تطوير هذه الصفحة...", style: TextStyle(fontFamily: 'Almarai', color: Colors.red)))
                : ListView.builder(
              itemCount: reportResults.length,
              itemBuilder: (context, index) => ListTile(title: Text(reportResults[index].testName)),
            ),
          ),
        ),
      ],
    );
  }

  // --- دوام بناء عناصر الواجهة الفرعية ---

  Widget _buildLevelsDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LevelModel>(
          dropdownColor: Colors.white,
          value: selectedLevel,
          hint: const Text("اختار المستوى", style: TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.grey)),
          isExpanded: true,
          items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l.name, style: const TextStyle(fontFamily: 'Almarai', fontSize: 13)))).toList(),
          onChanged: (val) {
            setState(() {
              selectedLevel = val;
              filteredStudents = allStudents.where((s) => s.levelId == val?.id).toList();
              selectedStudent = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildStudentSearchField() {
    return Autocomplete<StudentModel>(
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return const Iterable<StudentModel>.empty();
        return filteredStudents.where((s) => s.name.contains(textValue.text));
      },
      // هذا الجزء المسؤول عن جعل القائمة بيضاء
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: Colors.white, // لون القائمة أبيض
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 40, // ضبط العرض
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final StudentModel option = options.elementAt(index);
                  return ListTile(
                    title: Text(option.name, style: const TextStyle(fontFamily: 'Almarai', fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (selection) => setState(() => selectedStudent = selection),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller, // الربط الصحيح للمسح والكتابة
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: "ابحث عن اسم الطالب",
              hintStyle: const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.person_search_outlined, size: 20, color: Colors.grey),
              // إضافة السهم في نهاية الحقل ليصبح مثل المستوى
              suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      },
    );
  }
  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 4), // مسافة بسيطة من اليمين والأسفل
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Almarai',
        fontSize: 14,
        fontWeight: FontWeight.bold, // جعل العنوان بارزاً
        color: Color(0xFF475569),    // لون رمادي غامق احترافي
      ),
    ),
  );

  Widget _buildTextField(String hint, TextEditingController controller) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: hint, border: InputBorder.none)),
  );

  Widget _buildDateBox(DateTime? date, Function(DateTime) onSelect, String placeholder) => InkWell(
    onTap: () async {
      DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
      if (picked != null) onSelect(picked);
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(date == null ? placeholder : DateFormat('yyyy/MM/dd').format(date!), style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
        const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
      ]),
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    width: 200, height: 45,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed: _submitReportRequest,
      child: const Text("إرسال الطلب ", style: TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );
}