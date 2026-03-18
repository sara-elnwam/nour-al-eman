import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TeacherReportsScreen extends StatefulWidget {
  @override
  _TeacherReportsScreenState createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<TeacherModel> allTeachers = [];
  List<LevelModel> levels = [];

  LevelModel? selectedLevel;
  TeacherModel? selectedTeacher;
  DateTime? fromDate;
  DateTime? toDate;

  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final resTeachers = await http.get(Uri.parse("https://nourelman.runasp.net/api/Employee/Getall")
      );
      final resLevels = await http.get(Uri.parse("https://nourelman.runasp.net/api/Level/Getall")
      );

      if (!mounted) return;

      if (resTeachers.statusCode == 200 && resLevels.statusCode == 200) {
        setState(() {
          allTeachers = (json.decode(utf8.decode(resTeachers.bodyBytes))['data'] as List)
              .map((e) => TeacherModel.fromJson(e)).toList();
          levels = (json.decode(utf8.decode(resLevels.bodyBytes))['data'] as List)
              .map((e) => LevelModel.fromJson(e)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar("خطأ في الاتصال بالسيرفر", isError: true);
      }
    }
  }

  Future<void> _submitRequest(String type) async {
    if (fromDate == null || toDate == null) {
      _showSnackBar("يرجى اختيار الفترة الزمنية", isError: true);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      String endpoint = type == "groups" ? "Teacher/GroupsReport" : "Teacher/AbsenceReport";

      final response = await http.post(
        Uri.parse("https://nourelman.runasp.net/api/$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "teacherId": selectedTeacher?.id,
          "levelId": selectedLevel?.id,
          "fromDate": DateFormat('yyyy-MM-dd').format(fromDate!),
          "toDate": DateFormat('yyyy-MM-dd').format(toDate!),
        }),
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        if (response.statusCode == 200) {
          _showSnackBar("تم إرسال الطلب بنجاح");
        } else {
          _showSnackBar("فشل الطلب: ${response.statusCode}", isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("حدث خطأ: $e", isError: true);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text("تقارير المعلمين",
            style: TextStyle(color: Color(0xFF2E3542), fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E3542), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD97706),
          labelColor: const Color(0xFFD97706),
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: "تقارير المجموعات"), Tab(text: "تقارير الغياب")],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildReportTab("groups"),
          _buildReportTab("absence"),
        ],
      ),
    );
  }

  Widget _buildReportTab(String type) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("من "),
          _buildDateBox(fromDate, (d) => setState(() => fromDate = d), " yyyy/MM/dd "),
          const SizedBox(height: 15),
          _buildLabel("إلى "),
          _buildDateBox(toDate, (d) => setState(() => toDate = d), "yyyy/MM/dd"),
          const SizedBox(height: 15),
          _buildLabel("المستوى "),
          _buildLevelsDropdown(),
          const SizedBox(height: 15),
          _buildLabel("اسم المعلم"),
          _buildTeacherSearchField(),
          const SizedBox(height: 40),
          Center(
            child: isSubmitting
                ? const CircularProgressIndicator(color: Color(0xFFD97706))
            // تم تعديل نص الزر هنا
                : _buildSubmitButton(" إرسال الطلب", type),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 4),
    child: Text(text, style: const TextStyle(fontFamily: 'Almarai', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
  );

  Widget _buildDateBox(DateTime? date, Function(DateTime) onSelect, String hint) => InkWell(
    onTap: () async {
      DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
      if (picked != null) onSelect(picked);
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(date == null ? hint : DateFormat('yyyy/MM/dd').format(date), style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
        const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
      ]),
    ),
  );

  Widget _buildLevelsDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LevelModel>(
          isExpanded: true,
          value: selectedLevel,
          hint: const Text("اختر المستوي", style: TextStyle(fontFamily: 'Almarai', fontSize: 13)),
          items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() => selectedLevel = v),
        ),
      ),
    );
  }

  Widget _buildTeacherSearchField() {
    return Autocomplete<TeacherModel>(
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textValue) {
        if (textValue.text.isEmpty) return const Iterable<TeacherModel>.empty();
        return allTeachers.where((t) => t.name.toLowerCase().contains(textValue.text.toLowerCase()));
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final TeacherModel option = options.elementAt(index);
                  return ListTile(
                    title: Text(option.name, style: const TextStyle(fontFamily: 'Almarai')),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (v) => setState(() => selectedTeacher = v),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              hintText: "ابحث عن اسم المعلم",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.person_search_outlined, size: 20, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton(String text, String type) => SizedBox(
    width: 250, height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      onPressed: () => _submitRequest(type),
      child: Text(text, style: const TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );
}

class LevelModel {
  final int id; final String name;
  LevelModel({required this.id, required this.name});
  factory LevelModel.fromJson(Map<String, dynamic> json) => LevelModel(id: json['id'], name: json['name'] ?? '');
}

class TeacherModel {
  final int id; final String name;
  TeacherModel({required this.id, required this.name});
  factory TeacherModel.fromJson(Map<String, dynamic> json) => TeacherModel(id: json['id'], name: json['fullName'] ?? json['name'] ?? '');
}