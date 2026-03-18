import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_parent_details_screen.dart';

class AllEmployeesScreen extends StatefulWidget {
  @override
  _AllEmployeesScreenState createState() => _AllEmployeesScreenState();
}

class _AllEmployeesScreenState extends State<AllEmployeesScreen> {
  List<dynamic> _allEmployees = [];
  List<dynamic> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // توحيد الألوان مع شاشة المعلمين
  final Color kPrimaryBlue = const Color(0xFF07427C);
  final Color kTextDark = const Color(0xFF2E3542);

  @override
  void initState() {
    super.initState();
    _fetchAllEmployees();
  }

  // بتتحدث تلقائياً كل ما ترجعي لشاشة الموظفين
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _fetchAllEmployees();
    }
  }

  Future<void> _fetchAllEmployees() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Employee/GetWithType?type=2')
        ,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allEmployees = data;
          _filteredEmployees = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // خاصية البحث المضافة
  void _filterSearch(String query) {
    setState(() {
      _filteredEmployees = _allEmployees
          .where((emp) => (emp['name'] ?? "").toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _updatePassword(int empId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final url =Uri.parse('https://nourelman.runasp.net/api/Student/ResetPassword')
      ;

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "id": empId,
          "password": newPassword,
        }),
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

  Future<void> _deleteEmployee(int id) async {
    try {
      final response = await http.post(
        Uri.parse('https://nourelman.runasp.net/api/Account/DeActivate?id=$id&type=2')
        ,
      );
      if (response.statusCode == 200) {
        _showSnackBar("تم حذف الموظف بنجاح", Colors.green);
        _fetchAllEmployees();
      }
    } catch (e) {
      _showSnackBar("خطأ في الاتصال", Colors.red);
    }
  }

  // --- بوب آب تغيير كلمة المرور (بتصميم موحد) ---
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
                  Text("إدخال كلمة المرور الجديدة للموظف: $empName",
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
                onPressed: _isSubmitting ? null : () async {
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

  // --- بوب آب الحذف (بتصميم موحد) ---
  void _showDeleteConfirmDialog(int empId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text("هل أنت متأكد من حذف هذا الموظف؟",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع", style: TextStyle(fontFamily: 'Almarai'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                Navigator.pop(context);
                _deleteEmployee(empId);
              },
              child: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
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
            : Text("قائمة الموظفين",
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
        onRefresh: _fetchAllEmployees,
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
                    2: FlexColumnWidth(3.5),
                    3: FlexColumnWidth(3),
                    4: FlexColumnWidth(4),
                    5: FlexColumnWidth(3),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey[100]),
                      children: [
                        _buildHeaderCell("#"),
                        _buildHeaderCell("الاسم", align: TextAlign.right),
                        _buildHeaderCell("الوظيفة"),
                        _buildHeaderCell("بيانات"),
                        _buildHeaderCell("كلمة المرور"),
                        _buildHeaderCell("حذف"),
                      ],
                    ),
                    ..._filteredEmployees.asMap().entries.map((entry) {
                      int index = entry.key;
                      var emp = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                        ),
                        children: [
                          _buildDataCell("${index + 1}"),
                          _buildDataCell(emp['name'] ?? "---", align: TextAlign.right, isBold: true),
                          _buildDataCell(emp['employeeType']?['name'] ?? "---"),
                          _buildActionCell(Icons.person_outline, Colors.blue[800]!, () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmployeeParentDetailsScreen(
                                  empId: emp['id'],
                                  empName: emp['name'] ?? "بيانات الموظف",
                                ),
                              ),
                            );
                            _fetchAllEmployees();
                          }),
                          _buildActionCell(Icons.lock_open_rounded, Colors.blue[400]!, () => _showResetPasswordDialog(emp['id'], emp['name'])),
                          _buildActionCell(Icons.delete_outline, Colors.red[400]!, () => _showDeleteConfirmDialog(emp['id'])),
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

  // --- Widgets مساعدة موحدة التنسيق ---
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
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Almarai')), backgroundColor: color),
    );
  }
}