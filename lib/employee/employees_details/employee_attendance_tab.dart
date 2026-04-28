import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class _AttendanceRecord {
  String? date;
  String? checkInTime;
  String? checkOutTime;
  String? workingHours;
  String? locationName;
  String? userName;
  String? checkType;

  _AttendanceRecord({
    this.date,
    this.checkInTime,
    this.checkOutTime,
    this.workingHours,
    this.locationName,
    this.userName,
    this.checkType,
  });

  factory _AttendanceRecord.fromJson(Map<String, dynamic> json) => _AttendanceRecord(
    date: json['date'],
    checkInTime: json['checkInTime'],
    checkOutTime: json['checkOutTime'],
    workingHours: json['workingHours'],
    locationName: json['locationName'],
    userName: json['userName'],
    checkType: json['checkType'],
  );
}

class EmployeeAttendanceTab extends StatefulWidget {
  final int empId;

  const EmployeeAttendanceTab({super.key, required this.empId});

  @override
  State<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends State<EmployeeAttendanceTab> {
  bool _isLoading = true;
  Map<String, List<_AttendanceRecord>> _groupedByMonth = {};
  List<String> _availableMonths = [];
  int _currentMonthIndex = 0;

  static const Color kPrimaryBlue = Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _fetchAttendanceLogs();
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {}
    try {
      return DateFormat("M/d/yyyy").parse(dateStr);
    } catch (_) {}
    try {
      return DateFormat("MM/dd/yyyy").parse(dateStr);
    } catch (_) {}
    try {
      return DateFormat("M/dd/yyyy").parse(dateStr);
    } catch (_) {}
    return null;
  }

  Future<void> _fetchAttendanceLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<_AttendanceRecord> allRecords = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        final localKey = 'local_attendance_${widget.empId}';
        final localJson = prefs.getString(localKey);
        if (localJson != null) {
          final List<dynamic> localList = jsonDecode(localJson);
          for (var item in localList) {
            allRecords.add(_AttendanceRecord(
              date: item['date'],
              checkInTime: item['checkInTime'],
              checkOutTime: item['checkOutTime'],
              workingHours: item['workingHours'],
              locationName: item['locationName'],
              userName: item['userName'],
              checkType: item['checkType'],
            ));
          }
        }
      } catch (e) {
        debugPrint("Local fetch error: $e");
      }
      try {
        final url =
            'https://nourelman.runasp.net/api/Locations/GetAll-employee-attendance-ByEmpId?EmpId=${widget.empId}';
        final prefs2 = await SharedPreferences.getInstance();
        final String token2 = prefs2.getString('user_token') ?? '';
        final response = await http.get(
          Uri.parse(url),
          headers: {
            if (token2.isNotEmpty && token2 != 'no_token')
              'Authorization': 'Bearer $token2',
          },
        );
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          final List<dynamic> data = decoded['data'] ?? [];
          final Set<String> localKeys = {};
          for (var r in allRecords) {
            if (r.date != null) localKeys.add('${r.date}|${r.checkInTime ?? ""}');
          }

          for (var item in data) {
            final serverRecord = _AttendanceRecord.fromJson(item);
            final key = '${serverRecord.date}|${serverRecord.checkInTime ?? ""}';
            if (!localKeys.contains(key)) {
              allRecords.add(serverRecord);
            }
          }
        }
      } catch (e) {
        debugPrint("Server fetch error: $e");
      }

      _processData(allRecords);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<_AttendanceRecord> rawData) {
    final validData = rawData.where((r) => _parseDate(r.date) != null).toList();
    validData.sort((a, b) => _parseDate(b.date)!.compareTo(_parseDate(a.date)!));
    Map<String, List<_AttendanceRecord>> groups = {};
    for (var entry in validData) {
      final date = _parseDate(entry.date)!;
      final monthYear = DateFormat('MMMM yyyy', 'ar').format(date);
      if (!groups.containsKey(monthYear)) groups[monthYear] = [];
      groups[monthYear]!.add(entry);
    }

    setState(() {
      _groupedByMonth = groups;
      _availableMonths = groups.keys.toList();
      _currentMonthIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryBlue));
    }

    if (_availableMonths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "لا توجد بيانات حضور",
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Almarai'),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Column(
        children: [
          _buildMonthNavigator(),
          _buildTableHeader(),
          Expanded(child: _buildAttendanceList()),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black87),
            onPressed: _currentMonthIndex > 0
                ? () => setState(() => _currentMonthIndex--)
                : null,
          ),
          Text(
            _availableMonths[_currentMonthIndex],
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black87),
            onPressed: _currentMonthIndex < _availableMonths.length - 1
                ? () => setState(() => _currentMonthIndex++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildHeaderCell("اليوم", 2),
          _buildHeaderCell("حضور", 2),
          _buildHeaderCell("إنصراف", 2),
          _buildHeaderCell("ساعات", 1),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black87,
            fontFamily: 'Almarai'),
      ),
    );
  }

  Widget _buildAttendanceList() {
    final currentMonth = _availableMonths[_currentMonthIndex];
    final logs = _groupedByMonth[currentMonth]!;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final date = _parseDate(log.date);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      date != null ? DateFormat('EEEE', 'ar').format(date) : "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Almarai'),
                    ),
                    Text(
                      date != null ? DateFormat('MM/dd').format(date) : "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  log.checkInTime ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  log.checkOutTime ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  log.workingHours ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E3542)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}