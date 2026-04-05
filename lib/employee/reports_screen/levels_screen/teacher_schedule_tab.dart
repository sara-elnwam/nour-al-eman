import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'teacher_schedule_model.dart';

class TeacherScheduleTab extends StatefulWidget {
  final int empId;

  const TeacherScheduleTab({super.key, required this.empId});

  @override
  State<TeacherScheduleTab> createState() => _TeacherScheduleTabState();
}

class _TeacherScheduleTabState extends State<TeacherScheduleTab> {
  bool _isLoading = true;
  List<TeacherScheduleModel> _scheduleList = [];

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    try {
      // الرابط بناءً على الصور المرفقة
      final url = 'https://nour-al-eman.runasp.net/api/Employee/GetSessionRecord?emp_id=${widget.empId}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _scheduleList = teacherScheduleFromJson(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching schedule: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF07427C)))
        : _scheduleList.isEmpty
        ? const Center(child: Text("لا يوجد جدول متاح حالياً", style: TextStyle(fontFamily: 'Almarai')))
        : Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "جدول الشيخ",
            style: TextStyle(
              color: Color(0xFF07427C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columnSpacing: 25,
                      columns: const [
                        DataColumn(label: Text('اليوم', style: _headerStyle)),
                        DataColumn(label: Text('الساعة', style: _headerStyle)),
                        DataColumn(label: Text('المجموعة', style: _headerStyle)),
                        DataColumn(label: Text('المستوى', style: _headerStyle)),
                        DataColumn(label: Text('المكتب', style: _headerStyle)),
                      ],
                      rows: _buildRows(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildRows() {
    List<DataRow> rows = [];
    for (var record in _scheduleList) {
      if (record.groupSessions != null) {
        for (var session in record.groupSessions!) {
          rows.add(DataRow(cells: [
            DataCell(Text(session.dayName, style: _cellStyle)),
            DataCell(Text(session.hour ?? "--:--", style: _cellStyle)),
            DataCell(Text(record.name ?? "", style: _cellStyle)),
            DataCell(Text(record.level?.name ?? "", style: _cellStyle)),
            DataCell(Text(record.loc?.name ?? "", style: _cellStyle)),
          ]));
        }
      }
    }
    return rows;
  }

  static const TextStyle _headerStyle = TextStyle(
    color: Color(0xFF64748B),
    fontWeight: FontWeight.bold,
    fontFamily: 'Almarai',
    fontSize: 13,
  );

  static const TextStyle _cellStyle = TextStyle(
    color: Color(0xFF2E3542),
    fontFamily: 'Almarai',
    fontSize: 12,
  );
}