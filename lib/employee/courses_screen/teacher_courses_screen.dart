import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final Color kPrimaryOrange = const Color(0xFFD36B2B);
  final Color kDarkBlue = const Color(0xFF2E3542);
  final Color kBgColor = const Color(0xFFF3F4F6);

  List<dynamic> currentData = [];
  bool isLoading = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
  }
  Future<void> fetchData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("https://nour-al-eman.runasp.net/api/EmployeeCources/GetAll")
        ,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          currentData = decodedData['data'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  Future<void> submitData({required bool isEdit, int? id}) async {
    final String endpoint = isEdit ? "Update" : "Save";
    final String url = "https://nour-al-eman.runasp.net/api/EmployeeCources/$endpoint"
    ;

    try {
      final Map<String, dynamic> bodyData = {
        "name": nameController.text,
        "description": descController.text,
      };

      if (isEdit) bodyData["id"] = id;
      final response = isEdit
          ? await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(bodyData),
      )
          : await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(bodyData),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          fetchData();
          _showSnackBar("تمت العملية بنجاح", Colors.green);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      final response = await http.post(
        Uri.parse("https://nour-al-eman.runasp.net/api/EmployeeCources/Delete?id=$id")
        ,
      );
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          fetchData();
          _showSnackBar("تم الحذف بنجاح", Colors.green);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text("دورات المعلمين",
              style: TextStyle(color: Color(0xFF2E3542), fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
          iconTheme: IconThemeData(color: kDarkBlue),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditModal(context, isEdit: false),
          backgroundColor: kPrimaryOrange,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: isLoading ? Center(child: CircularProgressIndicator(color: kPrimaryOrange)) : _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    if (currentData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              "لا توجد دورات مضافة حالياً",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("تحديث الصفحة"),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryOrange),
            )
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, color: kPrimaryOrange, size: 20),
              const SizedBox(width: 8),
              const Text("قائمة دورات المعلمين", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 550,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: currentData.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildHeader();
                  return _buildRow(currentData[index - 1]);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text("اسم الدورة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 4, child: Text("الوصف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 1, child: Center(child: Text("تعديل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
          Expanded(flex: 1, child: Center(child: Text("حذف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
        ],
      ),
    );
  }

  Widget _buildRow(dynamic item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(item['name'] ?? "", style: const TextStyle(fontSize: 14))),
          Expanded(flex: 4, child: Text(item['description'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () => _showAddEditModal(context, isEdit: true, data: item),
              child: Icon(Icons.edit_note, color: kPrimaryOrange, size: 24),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () => _showDeleteDialog(context, item['id']),
              child: const Icon(Icons.delete, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditModal(BuildContext context, {required bool isEdit, dynamic data}) {
    nameController.text = isEdit ? (data['name'] ?? "") : "";
    descController.text = isEdit ? (data['description'] ?? "") : "";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ),
              Text(isEdit ? "تعديل دورة" : "اضافة دورة",
                  style: TextStyle(color: kDarkBlue, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              _buildInput("ادخل اسم الدورة*", "ادخل اسم الدورة", nameController),
              const SizedBox(height: 15),
              _buildInput("ادخل تفاصيل الدورة*", "ادخل تفاصيل الدورة", descController),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => submitData(isEdit: isEdit, id: isEdit ? data['id'] : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(isEdit ? "حفظ التعديل" : "اضافة", style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
            const SizedBox(height: 15),
            const Text("تأكيد الحذف!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            const Text("هل أنت متأكد من حذف هذا السجل؟", textAlign: TextAlign.center),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => deleteItem(id), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("تأكيد", style: TextStyle(color: Colors.white)))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text("إلغاء", style: TextStyle(color: Colors.white)))),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }
}