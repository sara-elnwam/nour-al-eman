import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'session_model.dart';
import 'group_details_dashboard.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupData> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

// 2. تعديل دالة _fetchGroups لتصبح هكذا:
  Future<void> _fetchGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. هنجيب الـ ID اللي اتخزن فعلياً في الـ Login
      String empId = prefs.getString('user_id') ?? "";

      print("DEBUG: Current Employee ID fetching groups is: $empId");

      // 2. فحص بسيط للتأكد من وجود ID
      if (empId.isEmpty) {
        print("خطأ: لم يتم العثور على ID للمعلم في الـ SharedPreferences");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. الطلب من السيرفر باستخدام الـ ID الديناميكي
      final response = await http.get(
          Uri.parse('https://nour-al-eman.runasp.net/api/Group/GetAllEmployeeGroups?EmpId=$empId')      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // تأكدي أن السيرفر يرجع قائمة في "data"
        if (jsonData["data"] != null) {
          if (mounted) {
            setState(() {
              _groups = (jsonData["data"] as List)
                  .map((x) => GroupData.fromJson(x))
                  .toList();
              _isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        print("Server Error: ${response.statusCode}");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching groups: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _groups.isEmpty
              ? const Center(child: Text("لا توجد مجموعات حالياً"))
              : _buildTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Text("المجموعات الخاصة بالشيخ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('اسم المستوى', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('اسم المجموعة', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('المكتب', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('عدد الطلاب', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
          ],
          rows: _groups.map((group) {
            return DataRow(cells: [
              DataCell(
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailsDashboard(
                          groupId: group.groupId ?? 0,
                          levelId: group.levelId ?? 0,
                          groupName: group.groupName ?? "المجموعة",
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      (group.levelName == null || group.levelName == "null")
                          ? "المستوى"
                          : group.levelName!,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontFamily: 'Almarai',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              DataCell(Text(group.groupName ?? "---", style: const TextStyle(fontFamily: 'Almarai'))),
              DataCell(Text(group.loc ?? "---", style: const TextStyle(fontFamily: 'Almarai'))),
              DataCell(Center(child: Text("${group.studentCount ?? 0}", style: const TextStyle(fontFamily: 'Almarai')))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}