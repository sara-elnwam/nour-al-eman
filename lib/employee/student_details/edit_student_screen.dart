import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

// تعريفات الألوان والمقاسات
final Color primaryOrange = Color(0xFFC66422);
final Color darkBlue = Color(0xFF2E3542);
final String baseUrl = 'https://nourelman.runasp.net/api';

class EditStudentScreen extends StatefulWidget {
  final int studentId;
  final Map<String, dynamic>? initialData;

  const EditStudentScreen({super.key, required this.studentId, this.initialData});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController nameController;
  late TextEditingController parentJobController;
  late TextEditingController addressController;
  late TextEditingController phoneController;
  late TextEditingController phone2Controller;
  late TextEditingController schoolController;

  DateTime? birthDate;
  DateTime? joinDate;
  int? selectedLocId;
  String? attendanceType;
  List<dynamic> _locations = [];
  bool _isLoadingLocations = true;
  String? paymentType;
  String? documentType;
  String? typeInfamily;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    nameController = TextEditingController(text: data?['name']?.toString() ?? "");
    parentJobController = TextEditingController(text: data?['parentJob']?.toString() ?? "");
    addressController = TextEditingController(text: data?['address']?.toString() ?? "");
    phoneController = TextEditingController(text: data?['phone']?.toString() ?? "");
    phone2Controller = TextEditingController(text: data?['phone2']?.toString() ?? "");
    schoolController = TextEditingController(text: data?['governmentSchool']?.toString() ?? "");


    selectedLocId = widget.initialData?['locId'];
    attendanceType = widget.initialData?['attendanceType'];
    paymentType = widget.initialData?['paymentType'];
    documentType = widget.initialData?['documentType'];
    typeInfamily = widget.initialData?['typeInfamily'];
    // تحويل النصوص لتواريخ عشان الـ UI
    if (widget.initialData?['birthDate'] != null) {
      birthDate = DateTime.parse(widget.initialData!['birthDate']);
    }
    if (widget.initialData?['joinDate'] != null) {
      joinDate = DateTime.parse(widget.initialData!['joinDate']);
    }
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/Locations/GetAll'));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final list = decoded is List ? decoded : (decoded['data'] ?? []);
        setState(() {
          _locations = list;
          _isLoadingLocations = false;
          // تأكد إن الـ selectedLocId موجود في القائمة
          if (selectedLocId != null) {
            bool exists = _locations.any((loc) => loc['id'] == selectedLocId);
            if (!exists) selectedLocId = null;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching locations: $e");
      setState(() => _isLoadingLocations = false);
    }
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade400)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text("تعديل بيانات الطالب", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 18)),
          centerTitle: true,
          leading: IconButton(icon: Icon(Icons.arrow_back, color: darkBlue), onPressed: () => Navigator.pop(context)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("اسم الطالب", isRequired: true),
                TextFormField(controller: nameController, decoration: _buildInputDecoration("الاسم")),
                const SizedBox(height: 18),
                _buildLabel("وظيفة الأب"),
                TextFormField(controller: parentJobController, decoration: _buildInputDecoration("الوظيفة")),
                const SizedBox(height: 18),
                _buildLabel("العنوان", isRequired: true),
                TextFormField(controller: addressController, decoration: _buildInputDecoration("العنوان بالتفصيل")),
                const SizedBox(height: 18),
                _buildLabel("المكتب التابع له", isRequired: true),
                _isLoadingLocations
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<int>(
                  value: _locations.any((loc) => loc['id'] == selectedLocId) ? selectedLocId : null,
                  decoration: _buildInputDecoration("اختر المكتب"),
                  items: _locations.map<DropdownMenuItem<int>>((loc) {
                    return DropdownMenuItem<int>(
                      value: loc['id'] as int,
                      child: Text(loc['name']?.toString() ?? ""),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedLocId = val),
                  validator: (val) => val == null ? 'اختر المكتب' : null,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("تاريخ الميلاد", isRequired: true),
                          _buildDateBox(birthDate, (date) => setState(() => birthDate = date)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("تاريخ الانضمام", isRequired: true),
                          _buildDateBox(joinDate, (date) => setState(() => joinDate = date)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildLabel("رقم هاتف ولي الأمر (1)", isRequired: true),
                TextFormField(controller: phoneController, keyboardType: TextInputType.phone, decoration: _buildInputDecoration("01xxxxxxxxx")),
                const SizedBox(height: 18),
                _buildLabel("رقم هاتف ولي الأمر (2)"),
                TextFormField(controller: phone2Controller, keyboardType: TextInputType.phone, decoration: _buildInputDecoration("اختياري")),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("حالة الطالب", isRequired: true),
                          DropdownButtonFormField<String>(
                            value: ["عادي", "يتيم", "ثانوي"].contains(typeInfamily) ? typeInfamily : null,
                            decoration: _buildInputDecoration("الحالة"),
                            items: ["عادي", "يتيم", "ثانوي"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => typeInfamily = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("الكراسة", isRequired: true),
                          DropdownButtonFormField<String>(
                            value: ["مجاني", "مدفوع"].contains(documentType) ? documentType : null,
                            decoration: _buildInputDecoration("النوع"),
                            items: ["مجاني", "مدفوع"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => documentType = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildLabel("طريقة الدفع", isRequired: true),
                DropdownButtonFormField<String>(
                  value: ["مجاني", "شهري", "6 شهور"].contains(paymentType) ? paymentType : null,
                  decoration: _buildInputDecoration("اختر طريقة الدفع"),
                  items: ["مجاني", "شهري", "6 شهور"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => paymentType = val),
                ),
                const SizedBox(height: 18),
                _buildLabel("المدرسة الحكومية", isRequired: true),
                TextFormField(controller: schoolController, decoration: _buildInputDecoration("اسم المدرسة")),
                const SizedBox(height: 18),
                _buildLabel("الحضور", isRequired: true),
                DropdownButtonFormField<String>(
                  value: ["اوفلاين", "اونلاين"].contains(attendanceType) ? attendanceType : null,
                  decoration: _buildInputDecoration("اوفلاين / اونلاين"),
                  items: ["اوفلاين", "اونلاين"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => attendanceType = val),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateStudentData,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text("حفــــظ التعديلات", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStudentData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      final String fullUrl = '$baseUrl/Student/Update';

      // تجهيز الداتا بناءً على الـ JSON الفعلي اللي ظهر في الـ Debug عندك
      final Map<String, dynamic> body = {
        "id": widget.studentId,
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "phone2": phone2Controller.text.trim(),
        "address": addressController.text.trim(),
        "parentJob": parentJobController.text.trim(),
        "governmentSchool": schoolController.text.trim(),
        "attendanceType": attendanceType,

        // تنسيق التاريخ ليكون YYYY-MM-DD عشان السيرفر يقبله صح
        "birthDate": birthDate?.toIso8601String().split('T')[0],
        "joinDate": joinDate?.toIso8601String().split('T')[0],

        // إرسال الـ IDs اللي الليدر قال إنها مبتتبعتش
        "locId": selectedLocId ?? widget.initialData?['locId'],
        "levelId": widget.initialData?['levelId'], // دي القيمة 2 اللي في الـ JSON بتاعك
        "groupId": widget.initialData?['groupId'], // دي القيمة 2 اللي في الـ JSON بتاعك

        "paymentType": paymentType ?? "لم يتم التحديد بعد",
        "documentType": documentType ?? "لم يتم التحديد بعد",
        "typeInfamily": typeInfamily ?? "لم يتم التحديد بعد",
      };

// السطر ده مهم جداً عشان تراجع الداتا في الـ Console قبل ما تتبعت
      print("Final Body to Server: ${jsonEncode(body)}");

      // اطبع الـ Body عشان تتأكد إنه مش null
      debugPrint("🚀 Final Body to Server: ${jsonEncode(body)}");

      final response = await http.put(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ تم تحديث بيانات الطالب بنجاح"), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
      } else {
        debugPrint("❌ Server Response Error: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل التحديث: ${response.statusCode}"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      debugPrint("⚠️ Exception: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // محاولة أخيرة برابط مختلف إذا فشل الأول
  Future<void> _updateWithFallback(String? token, Map<String, dynamic> body) async {
    final String fallbackUrl = '$baseUrl/Students';
    final response = await http.put(
      Uri.parse(fallbackUrl),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم التحديث بنجاح (رابط بديل)")));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل التحديث النهائي 404")));
    }
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(text, style: TextStyle(fontSize: 14, color: darkBlue, fontWeight: FontWeight.w600)),
        if (isRequired) Text(" *", style: TextStyle(color: Colors.red)),
      ]),
    );
  }

  Widget _buildDateBox(DateTime? date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2030));
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(date == null ? "التاريخ" : DateFormat('yyyy/MM/dd').format(date), style: TextStyle(color: date == null ? Colors.grey : darkBlue, fontSize: 13)),
            Icon(Icons.calendar_month, color: primaryOrange, size: 18),
          ],
        ),
      ),
    );
  }
}