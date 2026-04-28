import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StudentTasksAbsenceScreen extends StatefulWidget {
  final String title;
  final String apiEndpoint;

  StudentTasksAbsenceScreen({required this.title, required this.apiEndpoint});

  @override
  _StudentTasksAbsenceScreenState createState() => _StudentTasksAbsenceScreenState();
}

class _StudentTasksAbsenceScreenState extends State<StudentTasksAbsenceScreen> {
  LevelModel? selectedLevel;
  StudentModel? selectedStudent;
  DateTime? fromDate;
  DateTime? toDate;
  final TextEditingController _countController = TextEditingController();

  List<LevelModel> levels = [];
  List<StudentModel> allStudents = [];
  List<StudentModel> filteredStudents = [];
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final resLevels = await http.get(Uri.parse("https://nourelman.runasp.net/api/Level/Getall")
      );
      final resStudents = await http.get(Uri.parse("https://nourelman.runasp.net/api/Student/Getall")
      );

      setState(() {
        levels = (json.decode(utf8.decode(resLevels.bodyBytes))['data'] as List).map((e) => LevelModel.fromJson(e)).toList();
        allStudents = (json.decode(utf8.decode(resStudents.bodyBytes))['data'] as List).map((e) => StudentModel.fromJson(e)).toList();
        filteredStudents = allStudents;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    setState(() => isSubmitting = true);
    try {
      final response = await http.post(
        Uri.parse("https://nourelman.runasp.net/api/${widget.apiEndpoint}")
,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "levelId": selectedLevel?.id,
          "studentId": selectedStudent?.id,
          "fromDate": fromDate != null ? DateFormat('yyyy-MM-dd').format(fromDate!) : null,
          "toDate": toDate != null ? DateFormat('yyyy-MM-dd').format(toDate!) : null,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم طلب ${widget.title} بنجاح")));
      }
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("من"),
            _buildDateBox(fromDate, (d) => setState(() => fromDate = d)),
            const SizedBox(height: 15),
            _buildLabel("إلى"),
            _buildDateBox(toDate, (d) => setState(() => toDate = d)),
            const SizedBox(height: 15),
            _buildLabel("المستوى"),
            _buildLevelsDropdown(),
            const SizedBox(height: 15),
            _buildLabel("الطالب"),
            _buildStudentSearchField(),
            const SizedBox(height: 15),
            _buildLabel("عدد النتائج"),
            _buildTextField("إختر عدد النتائج", _countController),
            const SizedBox(height: 30),
            Center(child: isSubmitting ? const CircularProgressIndicator(color: Color(0xFFD97706)) : _buildSubmitBtn()),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontFamily: 'Almarai', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
  );

  Widget _buildDateBox(DateTime? date, Function(DateTime) onSelect) => InkWell(
    onTap: () async {
      DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
      if (picked != null) onSelect(picked);
    },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(date == null ? "yyyy/MM/dd" : DateFormat('yyyy/MM/dd').format(date), style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
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
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              hintText: "ابحث عن اسم الطالب",
              hintStyle: TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.grey),
              prefixIcon: Icon(Icons.person_search_outlined, size: 20, color: Colors.grey),
              suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String h, TextEditingController c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: h, border: InputBorder.none)),
  );

  Widget _buildSubmitBtn() => SizedBox(width: 200, height: 45, child: ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    onPressed: _submitRequest,
    child: const Text("إرسال الطلب", style: TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold)),
  ));
}
class LevelModel {
  final int id; final String name;
  LevelModel({required this.id, required this.name});
  factory LevelModel.fromJson(Map<String, dynamic> json) => LevelModel(id: json['id'] ?? 0, name: json['name'] ?? '');
}
class StudentModel {
  final int id; final String name; final int? levelId;
  StudentModel({required this.id, required this.name, this.levelId});
  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(id: json['id'] ?? 0, name: json['name'] ?? '', levelId: json['levelId']);
}