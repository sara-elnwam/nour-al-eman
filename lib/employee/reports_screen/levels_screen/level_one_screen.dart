import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'group_details_screen.dart';

class LevelOneScreen extends StatefulWidget {
  final int levelId;
  final String levelName;

  const LevelOneScreen({super.key, required this.levelId, required this.levelName});

  @override
  State<LevelOneScreen> createState() => _LevelOneScreenState();
}

class _LevelOneScreenState extends State<LevelOneScreen> {
  final Color darkBlue = const Color(0xFF2E3542);
  final Color orangeButton = const Color(0xFFC66422);
  final Color kPrimaryBlue = const Color(0xFF07427C);

  late String displayedLevelName;
  List<dynamic> teachersList = [];
  List<dynamic> locationsList = [];

  // ✅ قائمة المجموعات كـ state بدل FutureBuilder عشان تتحدث بعد الإضافة
  List<dynamic> groupsList = [];
  bool isLoadingGroups = true;

  int? selectedTeacherId;
  int? selectedLocationId;
  List<int> selectedDays = [];
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    displayedLevelName = widget.levelName;
    _loadData();
    _fetchGroups();
  }

  // ✅ جلب المجموعات منفصل عشان نقدر نعيد تحميلها في أي وقت
  Future<void> _fetchGroups() async {
    if (mounted) setState(() => isLoadingGroups = true);
    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Group/Getall?levelid=${widget.levelId}'),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          groupsList = jsonDecode(response.body)['data'] ?? [];
          isLoadingGroups = false;
        });
      } else {
        if (mounted) setState(() => isLoadingGroups = false);
      }
    } catch (e) {
      debugPrint("Fetch Groups Error: $e");
      if (mounted) setState(() => isLoadingGroups = false);
    }
  }

  Future<void> _loadData() async {
    try {
      final locRes = await http.get(Uri.parse('https://nourelman.runasp.net/api/Locations/Getall'));
      final techRes = await http.get(Uri.parse('https://nourelman.runasp.net/api/Employee/GetWithType?type=1'));
      if (mounted) {
        setState(() {
          locationsList = jsonDecode(locRes.body)['data'] ?? [];
          final techBody = jsonDecode(techRes.body);
          teachersList = techBody is List ? techBody : (techBody['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Data Load Error: $e");
    }
  }

  String _getDayName(dynamic day) {
    int dayInt = int.tryParse(day.toString()) ?? 0;
    const days = {1: "السبت", 2: "الأحد", 3: "الاثنين", 4: "الثلاثاء", 5: "الأربعاء", 6: "الخميس", 7: "الجمعة"};
    return days[dayInt] ?? "";
  }

  Future<void> _addGroupApi(String name, BuildContext dialogContext) async {
    // ✅ Validation كامل
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك أدخل اسم المجموعة"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر الشيخ"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر المكتب"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر يوم واحد على الأقل"), backgroundColor: Colors.orange),
      );
      return;
    }

    String formattedTime = selectedTime != null
        ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
        : "00:00";

    // ✅ empId و LocId = int وليس String
    final Map<String, dynamic> payload = {
      "name": name.trim(),
      "levelId": widget.levelId,
      "empId": selectedTeacherId,
      "LocId": selectedLocationId,
      "Active": true,
      "Status": true,
      "days": selectedDays,
      "time": formattedTime,
      "GroupSessions": selectedDays.map((dayId) => {
        "Day": dayId,
        "Hour": formattedTime,
        "Status": true,
        "Serial": 1,
      }).toList(),
    };

    debugPrint("Add Group Payload: ${jsonEncode(payload)}");

    final response = await http.post(
      Uri.parse('https://nourelman.runasp.net/api/Group/Save'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    debugPrint("Add Group Response (${response.statusCode}): ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (mounted) {
        Navigator.pop(dialogContext);
        setState(() {
          selectedDays = [];
          selectedTime = null;
          selectedTeacherId = null;
          selectedLocationId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إضافة المجموعة بنجاح ✅"), backgroundColor: Colors.green),
        );
        _fetchGroups(); // ✅ تحديث القائمة تلقائياً
      }
    } else {
      debugPrint("خطأ من السيرفر: ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الإضافة: ${response.statusCode}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateLevelApi(String newName) async {
    final response = await http.put(
      Uri.parse('https://nourelman.runasp.net/api/Level/Update'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": widget.levelId, "name": newName}),
    );
    if (response.statusCode == 200) {
      setState(() => displayedLevelName = newName);
    }
  }

  Future<void> _deleteGroupApi(int id, String name) async {
    try {
      // السيرفر لا يدعم DELETE ولا POST على هذا الـ endpoint
      // نستخدم Update مع active: false لتعطيل المجموعة وإخفاؤها
      final response = await http.put(
        Uri.parse('https://nourelman.runasp.net/api/Group/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "Id": id,
          "Name": name,
          "Active": false,
          "Status": false,
          "LevelId": groupsList.firstWhere((g) => g['id'] == id, orElse: () => {})['levelId'] ?? widget.levelId,
          "Days": [],
          "Time": "00:00",
          "GroupSessions": [],
        }),
      );

      debugPrint("Deactivate Group (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم حذف المجموعة بنجاح ✅"), backgroundColor: Colors.green),
          );
          _fetchGroups();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل الحذف: ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("حدث خطأ في الاتصال"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddGroupDialog() {
    // ✅ reset القيم عند كل فتح للديالوج
    selectedTeacherId = null;
    selectedLocationId = null;
    selectedDays = [];
    selectedTime = null;
    TextEditingController nameCont = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDs) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(
              child: Text("إضافة مجموعة",
                  style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("اسم المجموعة"),
                    TextField(controller: nameCont, decoration: _inputDecoration("الاسم")),
                    const SizedBox(height: 15),

                    _buildLabel("الشيخ"),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedTeacherId,
                      decoration: _inputDecoration("اختر الشيخ"),
                      items: teachersList.map((t) => DropdownMenuItem<int>(
                        value: t['id'],
                        child: Text(t['fullName'] ?? t['name'] ?? "", style: const TextStyle(fontFamily: 'Almarai')),
                      )).toList(),
                      onChanged: (val) {
                        setDs(() => selectedTeacherId = val);
                        setState(() => selectedTeacherId = val);
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildLabel("وقت الحصة"),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        selectedTime == null ? "اختر الوقت" : selectedTime!.format(dialogCtx),
                        style: const TextStyle(fontFamily: 'Almarai'),
                      ),
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: dialogCtx,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDs(() => selectedTime = picked);
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    _buildLabel("المكتب"),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedLocationId,
                      decoration: _inputDecoration("اختر المكتب"),
                      items: locationsList.map((l) => DropdownMenuItem<int>(
                        value: l['id'],
                        child: Text(l['name'] ?? "", style: const TextStyle(fontFamily: 'Almarai')),
                      )).toList(),
                      onChanged: (val) {
                        setDs(() => selectedLocationId = val);
                        setState(() => selectedLocationId = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("الأيام"),
                    Wrap(
                      spacing: 5,
                      children: List.generate(7, (i) {
                        final days = ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];
                        bool isSel = selectedDays.contains(i + 1);
                        return FilterChip(
                          label: Text(days[i],
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSel ? Colors.white : Colors.black,
                                  fontFamily: 'Almarai')),
                          selected: isSel,
                          selectedColor: orangeButton,
                          onSelected: (v) => setDs(() =>
                          v ? selectedDays.add(i + 1) : selectedDays.remove(i + 1)),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                onPressed: () => _addGroupApi(nameCont.text, dialogCtx),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                child: const Text("إضافة", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditLevelDialog() {
    TextEditingController nameCont = TextEditingController(text: displayedLevelName);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تعديل اسم المستوى", style: TextStyle(fontFamily: 'Almarai')),
          content: TextField(controller: nameCont, decoration: _inputDecoration("اسم المستوى الجديد")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () { _updateLevelApi(nameCont.text); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int groupId, String name) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Almarai')),
          content: Text("هل أنت متأكد من حذف $name؟", style: const TextStyle(fontFamily: 'Almarai')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () { _deleteGroupApi(groupId, name); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("حذف", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Almarai')),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(displayedLevelName,
              style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          iconTheme: IconThemeData(color: darkBlue),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: "edit",
              onPressed: _showEditLevelDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "add",
              onPressed: _showAddGroupDialog,
              backgroundColor: orangeButton,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ],
        ),
        body: isLoadingGroups
            ? const Center(child: CircularProgressIndicator())
            : groupsList.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("لا توجد مجموعات", style: TextStyle(fontFamily: 'Almarai')),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchGroups,
                icon: const Icon(Icons.refresh),
                label: const Text("تحديث", style: TextStyle(fontFamily: 'Almarai')),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _fetchGroups,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 120,
                    headingRowColor: WidgetStateProperty.all(kPrimaryBlue.withOpacity(0.05)),
                    columns: const [
                      DataColumn(label: Text('المجموعة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                      DataColumn(label: Text('الشيخ', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                      DataColumn(label: Text('المكان', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                      DataColumn(label: Text('الطلاب', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                      DataColumn(label: Text('المواعيد', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                      DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                    ],
                    rows: groupsList.map((group) {
                      List sessions = group['sessions'] ?? group['groupSessions'] ?? [];
                      return DataRow(cells: [
                        DataCell(InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupDetailsScreen(
                                groupId: group['id'],
                                levelId: widget.levelId,
                                groupName: group['name'],
                                teacherName: group['emp']?['name'] ?? "غير محدد",
                                teacherId: group['empId'] ?? group['emp']?['id'] ?? 0,
                              ),
                            ),
                          ).then((_) => _fetchGroups()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              group['name'] ?? "---",
                              style: TextStyle(
                                color: kPrimaryBlue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                fontFamily: 'Almarai',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )),
                        DataCell(Text(group['emp']?['name'] ?? "---", style: const TextStyle(fontFamily: 'Almarai'))),
                        DataCell(Text(group['loc']?['name'] ?? "---", style: const TextStyle(fontFamily: 'Almarai'))),
                        DataCell(Center(child: Text(group['studentCount']?.toString() ?? "0", style: const TextStyle(fontFamily: 'Almarai')))),
                        DataCell(Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sessions.map<Widget>((s) => Text(
                              "${_getDayName(s['day'])} (${s['hour']})",
                              style: const TextStyle(fontSize: 11, fontFamily: 'Almarai'),
                            )).toList(),
                          ),
                        )),
                        DataCell(IconButton(
                          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                          onPressed: () => _showDeleteDialog(group['id'], group['name']),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}