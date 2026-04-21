import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'staff_model.dart';
import 'staff_details_screen.dart';

class EmployeesScreen extends StatefulWidget {
  @override
  _EmployeesScreenState createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<StaffModel> _allEmployees = [];
  List<StaffModel> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final Color kPrimaryBlue = const Color(0xFF07427C);
  final Color kTextDark = const Color(0xFF2E3542);

  @override
  void initState() {
    super.initState();
    _fetchTeachersData();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _fetchTeachersData();
    }
  }
  Future<void> _fetchTeachersData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetWithType/?type=1')
      ;

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        List<dynamic> dataList = [];

        if (responseData is Map && responseData.containsKey('data')) {
          dataList = responseData['data'];
        } else if (responseData is List) {
          dataList = responseData;
        }

        List<StaffModel> loadedTeachers = [];
        for (var item in dataList) {
          loadedTeachers.add(StaffModel.fromJson(item));
        }

        setState(() {
          _allEmployees = loadedTeachers;
          _filteredEmployees = _allEmployees;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  Future<void> _deleteEmployee(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url =Uri.parse('https://nour-al-eman.runasp.net/api/Account/DeActivate?id=$id&type=1');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        if (resBody['message'] == "Success") {
          _showSnackBar("تم حذف المدرس بنجاح", Colors.green);
          _fetchTeachersData(); // تحديث الجدول
        } else {
          _showSnackBar("فشل في الحذف: ${resBody['message']}", Colors.red);
        }
      } else {
        _showSnackBar("فشل في الاتصال بالسيرفر: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ غير متوقع", Colors.red);
    }
  }
  Future<void> _updatePassword(int empId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('https://nour-al-eman.runasp.net/api/Student/ResetPassword')
        ,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"id": empId, "password": newPassword}),
      );

      if (response.statusCode == 200) {
        _showSnackBar("تم تغيير كلمة المرور بنجاح", Colors.green);
      } else {
        _showSnackBar("فشل تحديث كلمة المرور", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء التحديث", Colors.red);
    }
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredEmployees = _allEmployees
          .where((emp) => (emp.name ?? "").toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF2E3542)),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _filterSearch,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
              hintText: "ابحث عن موظف...",
              border: InputBorder.none,
              hintStyle: TextStyle(fontFamily: 'Almarai', fontSize: 14)),
        )
            : Text("اسماء المعلمون",
            style: TextStyle(
                fontFamily: 'Almarai',
                fontWeight: FontWeight.bold,
                color: kTextDark,
                fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: kPrimaryBlue),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredEmployees = _allEmployees;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : RefreshIndicator(
        color: kPrimaryBlue,
        onRefresh: _fetchTeachersData,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(4),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                    4: FlexColumnWidth(1.5),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _buildHeaderCell("#"),
                        _buildHeaderCell("الاسم", align: TextAlign.right),
                        _buildHeaderCell("بيانات"),
                        _buildHeaderCell("كلمة المرور"),
                        _buildHeaderCell("حذف"),
                      ],
                    ),
                    ..._filteredEmployees.asMap().entries.map((entry) {
                      int index = entry.key;
                      var teacher = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                        ),
                        children: [
                          _buildDataCell("${index + 1}"),
                          _buildDataCell(teacher.name ?? "---", align: TextAlign.right, isBold: true),
                          _buildActionCell(Icons.person_outline, Colors.blue[800]!, () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (c) => StaffDetailsScreen(staffId: teacher.id!, staffName: teacher.name!),
                            ));
                          }),
                          _buildActionCell(Icons.lock_open_rounded, Colors.blue[400]!, () {
                            _showResetPasswordDialog(teacher.id!, teacher.name ?? "");
                          }),
                          _buildActionCell(Icons.delete_outline, Colors.red[400]!, () {
                            _showDeleteConfirmDialog(teacher.id!);
                          }),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      child: Text(text,
          textAlign: align,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700], fontFamily: 'Almarai')),
    );
  }

  Widget _buildDataCell(String text, {TextAlign align = TextAlign.center, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      child: Text(text,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: kTextDark,
              fontFamily: 'Almarai')),
    );
  }

  Widget _buildActionCell(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: color, size: 22), onPressed: onTap);
  }

  void _showResetPasswordDialog(int empId, String empName) {
    final TextEditingController _passController = TextEditingController();
    final TextEditingController _confirmPassController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("إعادة تعيين كلمة السر",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("إدخال كلمة المرور الجديدة للشيخ: $empName",
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
                  const SizedBox(height: 20),
                  _buildPopupTextField("كلمة المرور", _passController),
                  const SizedBox(height: 15),
                  _buildPopupTextField("تأكيد كلمة المرور", _confirmPassController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: Colors.red, fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                  if (_passController.text.length < 6) {
                    _showSnackBar("كلمة المرور قصيرة جداً", Colors.orange);
                    return;
                  }
                  if (_passController.text != _confirmPassController.text) {
                    _showSnackBar("كلمة المرور غير متطابقة", Colors.orange);
                    return;
                  }
                  setDialogState(() => _isSubmitting = true);
                  await _updatePassword(empId, _passController.text);
                  if (mounted) Navigator.pop(context);
                },
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("تغيير", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(int empId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Text("هل أنت متأكد من حذف هذا المدرس؟",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                _deleteEmployee(empId);
              },
              child: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Almarai'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Almarai')), backgroundColor: color));
  }
}