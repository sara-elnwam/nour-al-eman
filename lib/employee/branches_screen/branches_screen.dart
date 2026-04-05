import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final Color kPrimaryOrange = const Color(0xFFD36B2B);
  final Color kDarkBlue = const Color(0xFF2E3542);
  final Color kBgColor = const Color(0xFFF3F4F6);

  List<dynamic> branchesData = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final TextEditingController lat1Controller = TextEditingController();
  final TextEditingController long1Controller = TextEditingController();
  final TextEditingController lat2Controller = TextEditingController();
  final TextEditingController long2Controller = TextEditingController();
  final TextEditingController lat3Controller = TextEditingController();
  final TextEditingController long3Controller = TextEditingController();
  final TextEditingController lat4Controller = TextEditingController();
  final TextEditingController long4Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchBranches();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchBranches() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse("https://nour-al-eman.runasp.net/api/Locations/GetAll"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            branchesData = decodedData['data'] ?? [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> submitBranch({required bool isEdit, int? id}) async {
    final String endpoint = isEdit ? "Update" : "Save";
    final String url = "https://nour-al-eman.runasp.net/api/Locations/$endpoint";

    String coords =
        "${lat1Controller.text};${long1Controller.text};"
        "${lat2Controller.text};${long2Controller.text};"
        "${lat3Controller.text};${long3Controller.text};"
        "${lat4Controller.text};${long4Controller.text}";

    try {
      final Map<String, dynamic> bodyData = {
        "name": nameController.text,
        "address": addressController.text,
        "coordinates": coords,
        "status": true
      };
      if (isEdit) bodyData["id"] = id;

      final response = isEdit
          ? await http.put(Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: json.encode(bodyData))
          : await http.post(Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: json.encode(bodyData));

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          _showSnackBar("تمت العملية بنجاح", Colors.green);
          Future.delayed(const Duration(milliseconds: 500), () {
            fetchBranches();
          });
        }
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء الحفظ", Colors.red);
    }
  }

  Future<void> deleteBranch(dynamic id) async {
    final backup = List.from(branchesData);
    setState(() {
      branchesData.removeWhere((item) => item['id'].toString() == id.toString());
    });

    if (Navigator.canPop(context)) Navigator.pop(context);

    try {
      final response = await http.post(
        Uri.parse("https://nour-al-eman.runasp.net/api/Locations/Delete?id=$id")
        ,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar("تم الحذف بنجاح", Colors.green);
      } else {
        setState(() => branchesData = backup);
        _showSnackBar("فشل الحذف من السيرفر", Colors.red);
      }
    } catch (e) {
      setState(() => branchesData = backup);
      _showSnackBar("خطأ في الاتصال، حاول لاحقاً", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBgColor,

        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditModal(context, isEdit: false),
          backgroundColor: kPrimaryOrange,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: isLoading && branchesData.isEmpty
            ? Center(child: CircularProgressIndicator(color: kPrimaryOrange))
            : RefreshIndicator(
          onRefresh: fetchBranches,
          color: kPrimaryOrange,
          child: _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 600,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                      left: 12, right: 12, top: 0, bottom: 80),
                  itemCount: branchesData.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildHeader();
                    return _buildRow(branchesData[index - 1]);
                  },
                ),
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
      decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(8))),
      child: const Row(
        children: [
          Expanded(
              flex: 3,
              child: Center(
                  child: Text("اسم الفرع",
                      style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 4,
              child: Center(
                  child: Text("العنوان",
                      style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 1,
              child: Center(
                  child: Text("تعديل",
                      style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
              flex: 1,
              child: Center(
                  child: Text("حذف",
                      style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildRow(dynamic item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child:
              Text(item['name'] ?? "", textAlign: TextAlign.center)),
          Expanded(
              flex: 4,
              child: Text(item['address'] ?? "",
                  textAlign: TextAlign.center, maxLines: 2)),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () {
                List<String> parts =
                (item['coordinates'] ?? "").toString().split(';');
                lat1Controller.text =
                parts.isNotEmpty ? parts[0] : "";
                long1Controller.text =
                parts.length > 1 ? parts[1] : "";
                lat2Controller.text =
                parts.length > 2 ? parts[2] : "";
                long2Controller.text =
                parts.length > 3 ? parts[3] : "";
                lat3Controller.text =
                parts.length > 4 ? parts[4] : "";
                long3Controller.text =
                parts.length > 5 ? parts[5] : "";
                lat4Controller.text =
                parts.length > 6 ? parts[6] : "";
                long4Controller.text =
                parts.length > 7 ? parts[7] : "";
                _showAddEditModal(context, isEdit: true, data: item);
              },
              child:
              Icon(Icons.edit_note, color: kPrimaryOrange, size: 26),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () => _showDeleteDialog(context, item['id']),
              child:
              const Icon(Icons.delete, color: Colors.red, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditModal(BuildContext context,
      {required bool isEdit, dynamic data}) {
    if (!isEdit) {
      nameController.clear();
      addressController.clear();
      lat1Controller.clear();
      long1Controller.clear();
      lat2Controller.clear();
      long2Controller.clear();
      lat3Controller.clear();
      long3Controller.clear();
      lat4Controller.clear();
      long4Controller.clear();
    } else {
      nameController.text = data['name'] ?? "";
      addressController.text = data['address'] ?? "";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? "تعديل بيانات الفرع" : "إضافة فرع جديد",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              _buildInput("اسم الفرع*", nameController),
              _buildInput("عنوان الفرع*", addressController),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("الإحداثيات (4 نقاط)",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              _buildCoordRow("الأولى", lat1Controller, long1Controller),
              _buildCoordRow("الثانية", lat2Controller, long2Controller),
              _buildCoordRow("الثالثة", lat3Controller, long3Controller),
              _buildCoordRow("الرابعة", lat4Controller, long4Controller),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => submitBranch(
                    isEdit: isEdit, id: isEdit ? data['id'] : null),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    minimumSize: const Size(double.infinity, 45)),
                child: const Text("حفظ",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoordRow(String label, TextEditingController latCtrl,
      TextEditingController longCtrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("النقطة $label:",
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _buildInput("Lat", latCtrl)),
              const SizedBox(width: 6),
              Expanded(child: _buildInput("Long", longCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType:
        const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل تريد حذف هذا الفرع نهائياً؟"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => deleteBranch(id),
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
            const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}