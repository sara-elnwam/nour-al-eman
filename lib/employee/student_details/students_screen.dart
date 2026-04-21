import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_model.dart';
import 'student_details_screen.dart';

class StudentsScreen extends StatefulWidget {
  @override
  _StudentsScreenState createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudentsData();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _fetchStudentsData();
    }
  }


  Future<void> _fetchStudentsData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Student/GetByStatus?status=true');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = studentsFromJson(response.body);
        setState(() {
          _allStudents = data;
          _filteredStudents = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword(int studentId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Student/ResetPassword');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "id": studentId,
          "password": newPassword,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("تم تغيير كلمة المرور بنجاح", Colors.green);
      } else {
        throw Exception();
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء التحديث", Colors.red);
    }
  }

  Future<void> _deleteStudent(int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Account/DeActivate?id=$studentId&type=0');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar("تم حذف الطالب بنجاح", Colors.green);
        _fetchStudentsData();
      } else {
        throw Exception();
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء الحذف", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Almarai')), backgroundColor: color),
    );
  }

  void _showResetPasswordDialog(int studentId, String studentName) {
    final TextEditingController _passController = TextEditingController();
    final TextEditingController _confirmPassController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("إعادة تعيين كلمة السر",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("من فضلك، قم بإدخال كلمة المرور الجديدة للطالب: $studentName",
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
                  const SizedBox(height: 20),
                  _buildPopupTextField("كلمة المرور", _passController),
                  const SizedBox(height: 15),
                  _buildPopupTextField("إعادة إدخال كلمة المرور", _confirmPassController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: Colors.red, fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E3542), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isSubmitting ? null : () async {
                  if (_passController.text.length < 6) return;
                  if (_passController.text != _confirmPassController.text) return;

                  setDialogState(() => _isSubmitting = true);
                  await _updatePassword(studentId, _passController.text);
                  Navigator.pop(context);
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

  void _showDeleteConfirmDialog(int studentId) {
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
            child: Text(
              "هل أنت متأكد من حذف هذا الطالب؟",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2E3542)
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                  "تراجع",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Almarai', fontWeight: FontWeight.bold)
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteStudent(studentId);
              },
              child: const Text(
                  "تأكيد الحذف",
                  style: TextStyle(color: Colors.white, fontFamily: 'Almarai')
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: "أدخل كلمة المرور هنا",
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  void _filterStudents(String query) {
    setState(() {
      _filteredStudents = _allStudents
          .where((student) =>
          student.name!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Color(0xFF2E3542)),
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "ابحث عن اسم الطالب...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            style: const TextStyle(color: Color(0xFF2E3542), fontSize: 16),
            onChanged: _filterStudents,
          )
              : const Text("قائمة الطلاب",
              style: TextStyle(
                  color: Color(0xFF2E3542),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Almarai')),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _filteredStudents = _allStudents;
                  }
                });
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC66422)))
            : RefreshIndicator(
          color: const Color(0xFFC66422),
          onRefresh: _fetchStudentsData,
          child: _filteredStudents.isEmpty
              ? const Center(child: Text("لا يوجد نتائج مطابقة"))
              : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
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
                      ..._filteredStudents.asMap().entries.map((entry) {
                        int index = entry.key;
                        StudentModel student = entry.value;
                        return TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey[200]!, width: 0.5)),
                          ),
                          children: [
                            _buildDataCell("${index + 1}"),
                            _buildDataCell(student.name ?? "---", align: TextAlign.right, isBold: true),

                            _buildActionCell(Icons.person_outline, Colors.blue[800]!, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentDetailsScreen(
                                    studentId: student.id!,
                                    studentName: student.name!,
                                  ),
                                ),
                              );
                            }),

                            _buildActionCell(Icons.lock_open_rounded, Colors.blue[400]!, () {
                              _showResetPasswordDialog(student.id!, student.name!);
                            }),

                            _buildActionCell(Icons.delete_outline, Colors.red[400]!, () {
                              _showDeleteConfirmDialog(student.id!);
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
      ),
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      child: Text(text, textAlign: align,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700], fontFamily: 'Almarai')),
    );
  }

  Widget _buildDataCell(String text, {TextAlign align = TextAlign.center, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      child: Text(text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal, color: const Color(0xFF2E3542), fontFamily: 'Almarai'),
      ),
    );
  }

  Widget _buildActionCell(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}