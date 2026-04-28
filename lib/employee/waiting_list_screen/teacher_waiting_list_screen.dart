import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color _kOrange = Color(0xFFC66422);
const Color _kDark = Color(0xFF2E3542);

class TeacherWaitingListScreen extends StatefulWidget {
  const TeacherWaitingListScreen({super.key});
  @override
  State<TeacherWaitingListScreen> createState() => _TeacherWaitingListScreenState();
}

class _TeacherWaitingListScreenState extends State<TeacherWaitingListScreen> {
  List<dynamic> allTeachers = [];
  List<dynamic> filteredTeachers = [];
  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() { super.initState(); _fetchTeachers(); }

  Future<void> _fetchTeachers() async {
    try {
      setState(() => isLoading = true);
      final response = await http.get(Uri.parse('https://nourelman.runasp.net/api/Employee/GetByStatus?status=false&type=1'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() { allTeachers = data is List ? data : []; filteredTeachers = allTeachers; isLoading = false; });
      } else { setState(() => isLoading = false); }
    } catch (e) { setState(() => isLoading = false); }
  }

  void _filterTeachers(String query) {
    setState(() {
      filteredTeachers = allTeachers.where((t) =>
      (t['name'] ?? "").toString().contains(query) ||
          (t['ssn'] ?? "").toString().contains(query)).toList();
    });
  }

  Future<void> _handleAction(int id, bool isAccept) async {
    Navigator.pop(context);
    setState(() => isLoading = true);
    try {
      final endpoint = isAccept ? 'SubmitUserLogin' : 'RefuseUserLogin';
      final response = await http.post(Uri.parse('https://nourelman.runasp.net/api/Account/$endpoint?id=$id&type=1'));
      if (response.statusCode == 200) {
        await _fetchTeachers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAccept ? "تم قبول المعلم بنجاح" : "تم رفض الطلب بنجاح",
                style: const TextStyle(fontFamily: 'Almarai', color: Colors.white)),
            backgroundColor: isAccept ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ));
        }
      } else { setState(() => isLoading = false); }
    } catch (e) { setState(() => isLoading = false); }
  }
  void _showConfirmDialog(int id, bool isAccept) => _showWaitingDialog(context, id, isAccept, _handleAction);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: _buildAppBar(),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: _kOrange))
            : filteredTeachers.isEmpty ? _buildEmpty()
            : RefreshIndicator(
          color: _kOrange,
          onRefresh: _fetchTeachers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTable(),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white, elevation: 0, surfaceTintColor: Colors.white,
    title: isSearching
        ? TextField(
        controller: _searchController, autofocus: true,
        style: const TextStyle(fontFamily: 'Almarai', fontSize: 14, color: _kDark),
        decoration: InputDecoration(hintText: "ابحث بالاسم أو الرقم القومي...", border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Almarai')),
        onChanged: _filterTeachers)
        : const Text("طلبات تسجيل المعلمين",
        style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, fontSize: 16, color: _kDark)),
    actions: [
      Container(
        margin: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
        decoration: BoxDecoration(color: _kOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: IconButton(
          icon: Icon(isSearching ? Icons.close : Icons.search, color: _kOrange, size: 20),
          onPressed: () => setState(() {
            isSearching = !isSearching;
            if (!isSearching) { _searchController.clear(); _filterTeachers(""); }
          }),
        ),
      ),
    ],
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
        child: Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
      ),
      const SizedBox(height: 20),
      const Text("لا يوجد طلبات تسجيل جديدة",
          style: TextStyle(fontFamily: 'Almarai', fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
      const SizedBox(height: 8),
      Text("اسحب للأسفل للتحديث", style: TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.grey.shade400)),
    ]),
  );

  Widget _buildTable() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 4))]),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FB)),
        headingRowHeight: 52, dataRowMinHeight: 56, dataRowMaxHeight: 56,
        columnSpacing: 24, dividerThickness: 0.5,
        columns: ["الإسم", "الهاتف", "الرقم القومي", "المكتب", "الخيارات"]
            .map((c) => DataColumn(label: Expanded(child: Center(child: Text(c,
            style: const TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, color: _kDark, fontSize: 13))))))
            .toList(),
        rows: filteredTeachers.map((t) => DataRow(cells: [
          DataCell(Center(child: Text(t['name'] ?? "", style: _cell()))),
          DataCell(Center(child: Text(t['phone'] ?? "", style: _cell()))),
          DataCell(Center(child: Text(t['ssn'] ?? "", style: _cell()))),
          DataCell(Center(child: Text(t['loc']?['name'] ?? "", style: _cell()))),
          DataCell(Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            _actionBtn(Icons.check_rounded, const Color(0xFF2E7D32), () => _showConfirmDialog(t['id'], true)),
            const SizedBox(width: 8),
            _actionBtn(Icons.close_rounded, const Color(0xFFC62828), () => _showConfirmDialog(t['id'], false)),
          ]))),
        ])).toList(),
      ),
    ),
  );

  TextStyle _cell() => const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: _kDark);

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Icon(icon, color: color, size: 16),
    ),
  );
}

void _showWaitingDialog(BuildContext context, int id, bool isAccept, Future<void> Function(int, bool) onAction) {
  showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: (isAccept ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(isAccept ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                size: 40, color: isAccept ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
          ),
          const SizedBox(height: 20),
          Text(isAccept ? "تأكيد القبول" : "تأكيد الرفض",
              style: const TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2E3542))),
          const SizedBox(height: 10),
          Text(isAccept ? "هل تريد قبول هذا الطلب؟" : "هل أنت متأكد من رفض هذا الطلب؟",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Almarai', fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai', color: Color(0xFF2E3542))),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => onAction(id, isAccept),
              style: ElevatedButton.styleFrom(
                  backgroundColor: isAccept ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(isAccept ? "قبول" : "رفض",
                  style: const TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ]),
      ),
    ),
  );
}