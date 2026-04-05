import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}
class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final Color kPrimaryOrange = const Color(0xFFD36B2B);
  final Color kDarkBlue = const Color(0xFF2E3542);
  final Color kBgColor = const Color(0xFFF3F4F6);

  List<dynamic> currentData = [];
  bool isLoading = true;
  int _currentTabIndex = 4;


  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  bool isMandatory = false;
  String? selectedLevelId;
  File? selectedFile;
  String? selectedFileName;


  // المستويات (ديناميكية من API)
  List<dynamic> _levelsList = [];
  bool _isLoadingLevels = true;

  final List<Map<String, dynamic>> tabItems = [
    {'title': 'الاختبارات', 'id': 5},
    {'title': 'المناهج التعليمية', 'id': 3},
    {'title': 'الأبحاث', 'id': 2},
    {'title': 'السؤال الأسبوعي', 'id': 1},
    {'title': 'المقررات', 'id': 4},
  ];

  @override
  void initState() {
    super.initState();
    _fetchLevels();
    fetchData(tabItems[4]['id']);
  }


  Future<void> _fetchLevels() async {
    try {
      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Level/Getall'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _levelsList = data['data'] is List ? data['data'] : [];
          _isLoadingLevels = false;
        });
      } else {
        setState(() => _isLoadingLevels = false);
      }
    } catch (e) {
      setState(() => _isLoadingLevels = false);
    }
  }

  Future<void> fetchData(int typeId) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("https://nour-al-eman.runasp.net/api/StudentCources/GetAll?type=$typeId")
        ,
      );
      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          currentData = decodedData['data'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }


  Future<void> deleteItem(int id) async {
    try {

      final response = await http.post(
        Uri.parse("https://nour-al-eman.runasp.net/api/StudentCources/Delete?id=$id"),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        fetchData(tabItems[_currentTabIndex]['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم الحذف بنجاح"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الحذف: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  Future<void> submitData({required bool isEdit, int? id}) async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى اختيار ملف أولاً"), backgroundColor: Colors.red),
      );
      return;
    }

    final String endpoint = isEdit ? "Update" : "Save";

    final String url = "https://nour-al-eman.runasp.net/api/StudentCources/$endpoint"

        "?Name=${Uri.encodeComponent(nameController.text)}"
        "&Description=${Uri.encodeComponent(descController.text)}"
        "&LevelId=${selectedLevelId ?? "1"}"
        "&Mandatory=$isMandatory"
        "&TypeId=${tabItems[_currentTabIndex]['id']}";

    if (isEdit) {
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        selectedFile!.path,
      ));

      var response = await request.send();

      if (response.statusCode == 200) {
        Navigator.pop(context);
        fetchData(tabItems[_currentTabIndex]['id']);

        nameController.clear();
        descController.clear();
        setState(() {
          selectedFile = null;
          selectedFileName = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تمت العملية بنجاح"), backgroundColor: Colors.green),
        );
      } else {

        final respStr = await response.stream.bytesToString();
        debugPrint("خطأ من السيرفر: $respStr");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الطلب: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("Exception: $e");
    }
  }
  Future<void> addItem() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار ملف أولاً")));
      return;
    }

    final String url = "https://nour-al-eman.runasp.net/api/StudentCources/Save"

        "?Name=${nameController.text}"
        "&Description=${descController.text}"
        "&LevelId=${selectedLevelId ?? "1"}"
        "&Mandatory=$isMandatory"
        "&TypeId=${tabItems[_currentTabIndex]['id']}";

    var request = http.MultipartRequest('POST', Uri.parse(url));

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      selectedFile!.path,
    ));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        Navigator.pop(context); // إغلاق المودال
        fetchData(tabItems[_currentTabIndex]['id']); // تحديث الجدول
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت الإضافة بنجاح")));
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }
  Future<void> _pickFile(StateSetter setModalState) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setModalState(() {
        selectedFile = File(result.files.single.path!);
        selectedFileName = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: tabItems.length,
        initialIndex: 4,
        child: Scaffold(
          backgroundColor: kBgColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: const Text("دورات الطلاب", style: TextStyle(color: Color(0xFF2E3542), fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
            bottom: TabBar(
              isScrollable: true,
              indicatorColor: kPrimaryOrange,
              labelColor: kPrimaryOrange,
              onTap: (index) {
                setState(() => _currentTabIndex = index);
                fetchData(tabItems[index]['id']);
              },
              tabs: tabItems.map((item) => Tab(text: item['title'])).toList(),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEditModal(context, isEdit: false),
            backgroundColor: kPrimaryOrange,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: isLoading
              ? Center(child: CircularProgressIndicator(color: kPrimaryOrange))
              : _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, color: kPrimaryOrange, size: 20),
              const SizedBox(width: 8),
              Text("قائمة ${tabItems[_currentTabIndex]['title']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 800,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text("الاسم", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 4, child: Text("الوصف", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text("المستوى", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Center(child: Text("إجباري"))),
          Expanded(flex: 1, child: Center(child: Text("تعديل"))),
          Expanded(flex: 1, child: Center(child: Text("حذف"))),
        ],
      ),
    );
  }

  Widget _buildRow(dynamic item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(item['name'] ?? "")),
          Expanded(flex: 4, child: Text(item['description'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(item['level']?['name'] ?? "-")),
          Expanded(flex: 1, child: Center(child: Icon(item['mandatory'] == true ? Icons.check : Icons.close, color: Colors.red, size: 18))),
          Expanded(flex: 1, child: InkWell(onTap: () => _showAddEditModal(context, isEdit: true, data: item), child: Icon(Icons.edit_note, color: kPrimaryOrange, size: 24))),
          InkWell(
            onTap: () => _showDeleteDialog(context, item['id']), // تأكد أن المفتاح هو 'id' وليس 'Id'
            child: const Icon(Icons.delete, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  void _showAddEditModal(BuildContext context, {required bool isEdit, dynamic data}) {
    nameController.text = isEdit ? (data['name'] ?? "") : "";
    descController.text = isEdit ? (data['description'] ?? "") : "";
    isMandatory = isEdit ? (data['mandatory'] ?? false) : false;
    selectedLevelId = isEdit ? data['levelId']?.toString() : "1";
    selectedFile = null;
    selectedFileName = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.topLeft, child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))),
                _buildInput("الاسم*", nameController),
                _buildInput("التفاصيل*", descController),

                // دروب داون المستويات
                const Align(alignment: Alignment.centerRight, child: Text("المستوى*", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                _isLoadingLevels
                    ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    : DropdownButton<String>(
                  isExpanded: true,
                  value: _levelsList.any((l) => l['id'].toString() == selectedLevelId) ? selectedLevelId : null,
                  items: _levelsList.map((l) => DropdownMenuItem(
                    value: l['id'].toString(),
                    child: Text(l['name']?.toString() ?? ""),
                  )).toList(),
                  onChanged: (val) => setModalState(() => selectedLevelId = val),
                ),

                const SizedBox(height: 15),
                _buildFileSection(setModalState),

                CheckboxListTile(
                  title: const Text("إجباري", style: TextStyle(fontSize: 13)),
                  value: isMandatory,
                  activeColor: kPrimaryOrange,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setModalState(() => isMandatory = val!),
                ),

                ElevatedButton(
                  onPressed: () => submitData(isEdit: isEdit, id: isEdit ? data['id'] : null),
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryOrange, minimumSize: const Size(double.infinity, 45)),
                  child: Text(isEdit ? "حفظ التعديل" : "إضافة", style: const TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          TextField(controller: controller, decoration: const InputDecoration(isDense: true)),
        ],
      ),
    );
  }

  Widget _buildFileSection(StateSetter setModalState) {
    return InkWell(
      onTap: () => _pickFile(setModalState),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Colors.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(selectedFileName ?? "اختيار ملف", style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
  void _showDeleteDialog(BuildContext context, dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
            const SizedBox(height: 15),
            const Text("تأكيد الحذف!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
            const SizedBox(height: 10),
            const Text("هل أنت متأكد من حذف هذا السجل؟", textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
            const SizedBox(height: 25),
            Row(
              children: [
                // زر التأكيد
                // زر التأكيد داخل الـ Row في دالة _showDeleteDialog
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      deleteItem(id); // استدعاء الدالة وتمرير الـ ID
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                // زر الإلغاء
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}