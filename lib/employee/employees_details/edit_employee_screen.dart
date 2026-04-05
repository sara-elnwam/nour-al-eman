import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

class EditEmployeeScreen extends StatefulWidget {
  final int empId;
  EditEmployeeScreen({required this.empId});

  @override
  _EditEmployeeScreenState createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _joinDateController = TextEditingController();

  PlatformFile? _pickedFile;

  // المواقع (ديناميكية من API)
  List<dynamic> _locationsList = [];
  bool _isLoadingLocations = true;

  // المسميات الوظيفية (ديناميكية من API)
  List<dynamic> _jobTitlesList = [];
  bool _isLoadingJobTitles = true;

  int? _selectedLocationId;
  int? _selectedJobTypeId;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchJobTitles();
    _fetchEmployeeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _educationController.dispose();
    _joinDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocations() async {
    // جرب الـ endpoints المحتملة بالترتيب
    final endpoints = [
      'https://nour-al-eman.runasp.net/api/Locations/GetAll',
      'https://nour-al-eman.runasp.net/api/Location/GetAll',
    ];

    for (final url in endpoints) {
      print("DEBUG: جاري تجربة $url");
      try {
        final response = await http.get(Uri.parse(url));
        print("DEBUG: status = ${response.statusCode} | body = ${response.body}");
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final list = data is List ? data : (data['data'] ?? []);
          print("DEBUG: نجح الـ endpoint: $url | عدد المواقع = ${list.length}");
          setState(() {
            _locationsList = list;
            _isLoadingLocations = false;
          });
          return;
        }
      } catch (e) {
        print("DEBUG: خطأ في $url => $e");
      }
    }

    print("DEBUG: كل الـ endpoints فشلت!");
    setState(() => _isLoadingLocations = false);
  }

  Future<void> _fetchJobTitles() async {
    try {
      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/EmployeeType/GetAll'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data['data'] ?? []);
        setState(() {
          _jobTitlesList = list;
          _isLoadingJobTitles = false;
        });
      } else {
        setState(() => _isLoadingJobTitles = false);
      }
    } catch (e) {
      print("DEBUG: خطأ في جلب المسميات الوظيفية = $e");
      setState(() => _isLoadingJobTitles = false);
    }
  }

  Future<void> _fetchEmployeeData() async {
    try {
      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetById?id=${widget.empId}')
        ,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['error'] != null) {
          _showSnackBar(responseData['error']);
          setState(() => _isLoading = false);
          return;
        }

        final data = responseData['data'];

        if (data == null) {
          _showSnackBar("لم يتم العثور على بيانات لهذا الموظف");
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          _nameController.text = data['name']?.toString() ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _nationalIdController.text = (data['ssn'] ?? '').toString();

          String education = data['educationDegree']?.toString() ?? '';
          _educationController.text = (education.toLowerCase() == "string") ? "" : education;

          if (data['joinDate'] != null && data['joinDate'].toString().startsWith('20')) {
            _joinDateController.text = data['joinDate'].split('T')[0];
          } else {
            _joinDateController.text = DateTime.now().toIso8601String().split('T')[0];
          }

          _selectedLocationId = data['locId'];

          if (data['employeeTypeId'] != null) {
            _selectedJobTypeId = int.tryParse(data['employeeTypeId'].toString());
          } else if (data['employeeType'] != null) {
            _selectedJobTypeId = data['employeeType']['id'];
          }

          _isLoading = false;
        });
      } else {
        _showSnackBar("السيرفر رد بخطأ: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Fetch Error: $e");
      setState(() => _isLoading = false);
      _showSnackBar("خطأ في الاتصال بالخادم");
    }
  }
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }
  Future<void> _updateEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String finalJoinDate;
      if (_joinDateController.text.isEmpty || _joinDateController.text.startsWith('0001')) {
        finalJoinDate = DateTime.now().toIso8601String().split('.')[0];
      } else {
        // إضافة الوقت للتاريخ المختار ليقبله السيرفر
        finalJoinDate = "${_joinDateController.text}T00:00:00";
      }

      final Map<String, dynamic> payload = {
        "id": widget.empId, //
        "name": _nameController.text.trim(), //
        "ssn": _nationalIdController.text.trim(), //
        "phone": _phoneController.text.trim(), //
        "educationDegree": _educationController.text.trim(), //
        "joinDate": finalJoinDate,
        "locId": _selectedLocationId,

        "employeeTypeId": (_selectedJobTypeId ?? 2).toString(), //

        "groups": [],
        "courses": []
      };

      final response = await http.put(
        Uri.parse('https://nour-al-eman.runasp.net/api/Employee/Update'), //
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (responseData['data'] != null && responseData['error'] == null) {
        _showSnackBar("تم التعديل بنجاح ", isError: false);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        String errorMessage = responseData['error'] ?? "خطأ غير معروف في حفظ البيانات";
        _showSnackBar(errorMessage); //
      }

    } catch (e) {
      _showSnackBar("حدث خطأ في الاتصال: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text("تعديل بيانات الموظف",
              style: TextStyle(fontFamily: 'Almarai', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E3542))),
          iconTheme: const IconThemeData(color: Color(0xFF2E3542)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel("الإسم *"),
                _buildTextField(_nameController, validator: (v) => v!.isEmpty ? "مطلوب" : null),

                _buildFieldLabel("الرقم الهاتف *"),
                _buildTextField(_phoneController, isNumber: true, validator: (v) => v!.length < 11 ? "رقم غير صحيح" : null),

                _buildFieldLabel("الرقم القومي *"),
                _buildTextField(_nationalIdController, isNumber: true, validator: (v) => v!.length < 14 ? "يجب أن يكون 14 رقم" : null),

                _buildFieldLabel("المكتب التابع له *"),
                _isLoadingLocations
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : _buildDropdownField(
                  value: _locationsList.any((l) => (l['id'] as num).toInt() == _selectedLocationId) ? _selectedLocationId : null,
                  items: _locationsList.map<DropdownMenuItem<int>>((loc) => DropdownMenuItem<int>(
                    value: (loc['id'] as num).toInt(),
                    child: Text(loc['name']?.toString() ?? "", style: const TextStyle(fontSize: 14, fontFamily: 'Almarai')),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLocationId = val;
                    });
                  },
                ),

                _buildFieldLabel("المؤهل الدراسي *"),
                _buildTextField(_educationController),

                _buildFieldLabel("تاريخ الانضمام *"),
                _buildTextField(_joinDateController, isReadOnly: true, onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _joinDateController.text = picked.toString().split(' ')[0]);
                }),

                _buildFieldLabel("المسمى الوظيفي *"),
                _isLoadingJobTitles
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
                    : _buildDropdownField(
                  value: _jobTitlesList.any((j) => (j['id'] as num).toInt() == _selectedJobTypeId) ? _selectedJobTypeId : null,
                  items: _jobTitlesList.map<DropdownMenuItem<int>>((job) => DropdownMenuItem<int>(
                    value: (job['id'] as num).toInt(),
                    child: Text(job['name']?.toString() ?? "", style: const TextStyle(fontSize: 14, fontFamily: 'Almarai')),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedJobTypeId = val;
                    });
                  },
                ),

                if (_selectedJobTypeId == "معلم/ معلمه") ...[
                  _buildFieldLabel("الدورات الخاصة بك"),
                  _buildFilePicker(),
                ],

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD1782D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _updateEmployee,
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("حفظ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 15),
    child: Text(label, style: const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.redAccent)),
  );

  Widget _buildTextField(TextEditingController controller, {bool isNumber = false, bool isReadOnly = false, VoidCallback? onTap, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      onTap: onTap,
      validator: validator,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
        errorStyle: const TextStyle(fontFamily: 'Almarai', fontSize: 10),
      ),
    );
  }

  Widget _buildDropdownField({int? value, required List<DropdownMenuItem<int>> items, required Function(int?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: const Text("اختر...", style: TextStyle(fontSize: 12, color: Colors.grey)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1976D2)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(_pickedFile?.name ?? "لم يتم اختيار ملف", style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(5)),
              child: const Text("اختيار ملف", style: TextStyle(fontSize: 12, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }
}