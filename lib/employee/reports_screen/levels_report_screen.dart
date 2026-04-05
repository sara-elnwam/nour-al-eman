import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LevelsReportScreen extends StatefulWidget {
  @override
  _LevelsReportScreenState createState() => _LevelsReportScreenState();
}

class _LevelsReportScreenState extends State<LevelsReportScreen> {
  LevelModel? selectedLevel;
  StudentModel? selectedStudent;
  List<LevelModel> levels = [];
  List<StudentModel> allStudents = [];
  List<StudentModel> filteredStudents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final resL = await http.get(Uri.parse("https://nour-al-eman.runasp.net/api/Level/Getall")
      );
      final resS = await http.get(Uri.parse("https://nour-al-eman.runasp.net/api/Student/Getall"));
      setState(() {
        levels = (json.decode(utf8.decode(resL.bodyBytes))['data'] as List).map((e) => LevelModel.fromJson(e)).toList();
        allStudents = (json.decode(utf8.decode(resS.bodyBytes))['data'] as List).map((e) => StudentModel.fromJson(e)).toList();
        filteredStudents = allStudents;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("المستوى"),
            _buildLevelsDropdown(),
            const SizedBox(height: 15),
            _buildLabel("الطالب (بحث)"),
            _buildStudentSearchField(),
            const SizedBox(height: 30),
            Center(child: _buildSubmitButton()),
            const SizedBox(height: 20),
            // تم حذف الـ Divider والنص من هنا
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontFamily: 'Almarai', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
  );

  Widget _buildLevelsDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LevelModel>(
          isExpanded: true,
          value: selectedLevel,
          hint: const Text("اختار المستوى", style: TextStyle(fontFamily: 'Almarai', fontSize: 13)),
          items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() {
            selectedLevel = v;
            filteredStudents = allStudents.where((s) => s.levelId == v?.id).toList();
            selectedStudent = null;
          }),
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
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
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
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: "ابحث عن اسم الطالب",
              hintStyle: const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(Icons.person_search_outlined, size: 20, color: Colors.grey),
              suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() => SizedBox(
    width: 200, height: 45,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD97706),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
      ),
      onPressed: () {},
      child: const Text("إرسال الطلب", style: TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );
}

// Models
class LevelModel { final int id; final String name; LevelModel({required this.id, required this.name}); factory LevelModel.fromJson(Map<String, dynamic> json) => LevelModel(id: json['id'] ?? 0, name: json['name'] ?? ''); }
class StudentModel { final int id; final String name; final int? levelId; StudentModel({required this.id, required this.name, this.levelId}); factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(id: json['id'] ?? 0, name: json['name'] ?? '', levelId: json['levelId']); }