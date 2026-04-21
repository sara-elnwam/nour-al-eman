import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'session_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionsScreen extends StatefulWidget {
  @override
  _SessionsScreenState createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _isLoading = true;
  List<SessionRecord> _sessions = [];
  final Color kActiveBlue = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('user_id') ?? "";

      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetSessionRecord?emp_id=$id'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _sessions = sessionRecordFromJson(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "مواعيد المجموعات",
            style: TextStyle(
              color: kActiveBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              width: double.infinity,
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
                      headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('اليوم', style: _headerStyle)),
                        DataColumn(label: Text('الساعة', style: _headerStyle)),
                        DataColumn(label: Text('المجموعة', style: _headerStyle)),
                        DataColumn(label: Text('المستوى', style: _headerStyle)),
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
    for (var record in _sessions) {
      if (record.groupSessions != null) {
        for (var session in record.groupSessions!) {
          rows.add(DataRow(cells: [
            DataCell(Text(session.dayName, style: _cellStyle)),
            DataCell(Text(session.hour ?? "", style: _cellStyle)),
            DataCell(Text(record.name ?? "", style: _cellStyle)),
            DataCell(Text(record.level?.name ?? "", style: _cellStyle)),
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
    color: Color(0xFF334155),
    fontFamily: 'Almarai',
    fontSize: 12,
  );
}