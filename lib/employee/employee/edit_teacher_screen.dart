import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class EditTeacherScreen extends StatefulWidget {
  final Map<String, dynamic> staffData;

  const EditTeacherScreen({super.key, required this.staffData});

  @override
  State<EditTeacherScreen> createState() => _EditTeacherScreenState();
}

class _EditTeacherScreenState extends State<EditTeacherScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ssnController;
  late TextEditingController _eduController;
  late TextEditingController _joinDateController;

  String? _selectedLocId;
  List<dynamic> _locations = [];
  bool _isLoadingLocations = true;
  bool _isSaving = false;

  final Color primaryBlue = const Color(0xFF07427C);
  final Color orangeButton = const Color(0xFFD37421);

  @override
  void initState() {
    super.initState();
    // استخراج البيانات مع التأكد من الهيكل القادم من الـ API
    var data = widget.staffData['data'] ?? widget.staffData;

    _nameController = TextEditingController(text: data['name']?.toString() ?? "");
    _phoneController = TextEditingController(text: data['phone']?.toString() ?? "");
    _ssnController = TextEditingController(text: data['ssn']?.toString() ?? "");
    _eduController = TextEditingController(text: data['educationDegree']?.toString() ?? "");
    _joinDateController = TextEditingController(text: _formatDate(data['joinDate']));

    _selectedLocId = data['locId']?.toString();
    _fetchLocations();
  }
  String _formatDate(dynamic date) {
    // إذا كان التاريخ نل أو فارغ أو يحتوي على أصفار (غير منطقي)
    if (date == null ||
        date.toString().isEmpty ||
        date.toString().startsWith("0001")) {
      // إرجاع تاريخ النهاردة بتنسيق YYYY-MM-DD
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    String d = date.toString();
    return d.contains('T') ? d.split('T')[0] : d;
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('https://nour-al-eman.runasp.net/api/Locations/GetAll'));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        setState(() {
          if (decodedData is List) {
            _locations = decodedData;
          } else if (decodedData is Map && decodedData['data'] is List) {
            _locations = decodedData['data'];
          }
          _isLoadingLocations = false;
          // التحقق من أن locId ما زال موجوداً في القائمة
          bool exists = _locations.any((loc) => loc['id'].toString() == _selectedLocId);
          if (!exists) _selectedLocId = null;
        });
      }
    } catch (e) {
      debugPrint("Error fetching locations: $e");
      setState(() => _isLoadingLocations = false);
    }
  }
  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      // 1. استخراج الـ ID بدقة
      final data = widget.staffData['data'] ?? widget.staffData;
      final teacherId = data['id'];

      print("Editing Teacher ID: $teacherId"); // تأكد ان الرقم ده 1297

      final Map<String, dynamic> updateData = {
        "id": teacherId,
        "name": _nameController.text,
        "phone": _phoneController.text,
        "ssn": _ssnController.text,
        "locId": int.tryParse(_selectedLocId!) ?? 0,
        "educationDegree": _eduController.text,
        // التأكد من وجود قيمة في الـ controller وإلا إرسال تاريخ اليوم بتنسيق السيرفر
        "joinDate": _joinDateController.text.isNotEmpty
            ? "${_joinDateController.text}T00:00:00.000Z"
            : "${DateFormat('yyyy-MM-dd').format(DateTime.now())}T00:00:00.000Z",
        "employeeTypeId": "1",
        "type": "1"
      };

      print("Sending Payload to Server: ${json.encode(updateData)}");

      final response = await http.put(
        Uri.parse('https://nour-al-eman.runasp.net/api/Employee/Update'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
        },
        body: json.encode(updateData),
      );

      print("Server Status Code: ${response.statusCode}");
      print("Server Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        // نجح الحفظ
        Navigator.pop(context, true);
      } else {
        print("Failed to update. Check if the ID or fields are correct.");
      }
    } catch (e) {
      print("Error during save: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          title: const Text("تعديل بيانات الشيخ",
              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: primaryBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField("الإسم *", _nameController, Icons.person_outline),
                _buildField("رقم الهاتف *", _phoneController, Icons.phone_android_outlined, isNumber: true),
                _buildField("الرقم القومي *", _ssnController, Icons.badge_outlined, isNumber: true),
                _buildField("المؤهل الدراسي *", _eduController, Icons.school_outlined),

                const Text("المكتب التابع له *", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _isLoadingLocations
                      ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                      : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLocId,
                      isExpanded: true,
                      hint: const Text("اختر المكتب"),
                      items: _locations.map((loc) {
                        return DropdownMenuItem<String>(
                          value: loc['id'].toString(),
                          child: Text(loc['name']?.toString() ?? ""),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedLocId = val),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildField("تاريخ الانضمام *", _joinDateController, Icons.calendar_month_outlined, readOnly: true, onTap: _selectDate),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orangeButton,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("حفظ التعديلات", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, bool readOnly = false, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryBlue, size: 22),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryBlue, width: 1.5), borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _joinDateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }
}