import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'role_permissions_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<dynamic> staffRoles = [];
  bool isLoading = true;
  bool isError = false;

  final Color primaryOrange = const Color(0xFFC66422);
  final Color successGreen = const Color(0xFF28A745);
  final Color dangerRed = const Color(0xFFDC3545);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchStaffRoles();
    });
  }

  // 1. Endpoint: GetAll (جلب البيانات)
  Future<void> fetchStaffRoles() async {
    final url = Uri.parse('https://nourelman.runasp.net/api/EmployeeType/GetAll');
    try {
      debugPrint("🚀 محاولة جلب البيانات من: $url");
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      debugPrint("📥 [GetAll] Response: ${response.body}"); // طباعة الرد

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (mounted) {
          setState(() {
            staffRoles = responseData['data'] ?? [];
            isLoading = false;
            isError = false;
          });
        }
      } else {
        throw Exception("فشل الجلب: ${response.statusCode}");
      }
    } catch (error) {
      debugPrint("❌ خطأ في الجلب: $error");
      if (mounted) setState(() { isLoading = false; isError = true; });
    }
  }
  Future<void> deleteRole(int id) async {
    final url = Uri.parse('https://nourelman.runasp.net/api/EmployeeType/Delete');
    try {
      debugPrint("🗑️ محاولة حذف ID: $id عبر Body JSON");
      final response = await http.delete(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(id), // نرسل الرقم مباشرة أو كـ {"id": id}
      );

      debugPrint("📥 [Delete] Status Code: ${response.statusCode}");
      debugPrint("📥 [Delete] Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        fetchStaffRoles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم الحذف بنجاح"), backgroundColor: Colors.green),
          );
        }
      } else {
        // إذا فشل هذا أيضاً، سنحتاج لتجربة إرساله كـ Map
        final responseRetry = await http.delete(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"id": id}),
        );

        if (responseRetry.statusCode == 200) {
          fetchStaffRoles();
        } else {
          throw Exception("فشل بجميع الطرق: ${responseRetry.statusCode}");
        }
      }
    } catch (e) {
      debugPrint("⚠️ خطأ نهائي: $e");
    }
  }
  // 2. Endpoint: Add (إضافة وظيفة جديدة)
  Future<void> addRole(String name) async {
    final url =Uri.parse('https://nourelman.runasp.net/api/EmployeeType/Add');
    try {
      debugPrint("📤 جاري إضافة وظيفة جديدة: $name");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name}),
      );

      debugPrint("📥 [Add] Response: ${response.body}"); // طباعة الرد

      if (response.statusCode == 200) {
        fetchStaffRoles(); // تحديث الجدول
      }
    } catch (e) {
      debugPrint("⚠️ خطأ أثناء الإضافة: $e");
    }
  }

  // 3. Endpoint: Update (تعديل وظيفة موجودة)
  Future<void> updateRole(int id, String newName) async {
    final url = Uri.parse('https://nourelman.runasp.net/api/EmployeeType/Update');
    try {
      debugPrint("🔄 جاري تحديث الوظيفة ID: $id إلى: $newName");
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id, "name": newName}),
      );

      debugPrint("📥 [Update] Response: ${response.body}"); // طباعة الرد

      if (response.statusCode == 200) {
        fetchStaffRoles(); // تحديث الجدول
      }
    } catch (e) {
      debugPrint("⚠️ خطأ أثناء التحديث: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("المسمى الوظيفي", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryOrange))
          : isError
          ? Center(child: TextButton(onPressed: fetchStaffRoles, child: const Text("إعادة المحاولة")))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildDataTable(),
            const SizedBox(height: 15),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DataTable(
        columnSpacing: 15,
        headingRowHeight: 45,
        dataRowHeight: 55,
        columns: const [
          DataColumn(label: Expanded(child: Text('الإسم', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
          DataColumn(label: Expanded(child: Center(child: Text('الصلاحيات', style: TextStyle(fontWeight: FontWeight.bold))))),
          DataColumn(label: Expanded(child: Center(child: Text('الخيارات', style: TextStyle(fontWeight: FontWeight.bold))))),
          DataColumn(label: Expanded(child: Center(child: Text('حذف', style: TextStyle(fontWeight: FontWeight.bold))))),
        ],
        rows: staffRoles.map((item) {
          return DataRow(cells: [
            DataCell(Center(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 13)))),
            DataCell(Center(
              child: InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => RolePermissionsScreen(roleName: item['name']))
                ),
                child: const Text("عرض الصلاحيات",
                    style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 11)
                ),
              ),
            )),
            DataCell(
              Center(
                child: IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.black54, size: 22),
                  onPressed: () => _showRoleDialog(isEdit: true, id: item['id'], currentName: item['name']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            DataCell(
              Center(
                child: IconButton(
                  icon: Icon(Icons.delete_outline, color: dangerRed, size: 22),
                  onPressed: () => _showDeleteConfirmation(item['id'], item['name'] ?? ""),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }
  void _showDeleteConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text("هل أنت متأكد من حذف المسمى الوظيفي '$name'؟", textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
            onPressed: () {
              Navigator.pop(context);
              deleteRole(id);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Widget _buildAddButton() {
    return SizedBox(
      width: 100,
      height: 38,
      child: ElevatedButton(
        onPressed: () => _showRoleDialog(isEdit: false),
        style: ElevatedButton.styleFrom(backgroundColor: primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        child: const Text("إضافة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showRoleDialog({required bool isEdit, int? id, String? currentName}) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? "تعديل وظيفة" : "إضافة وظيفة", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("المسمى الوظيفي", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  const Text("*", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "المسمى الوظيفي",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        Navigator.pop(context);
                        isEdit ? updateRole(id!, controller.text) : addRole(controller.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: successGreen),
                    child: Text(isEdit ? "حفظ" : "إضافة", style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: dangerRed),
                    child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}