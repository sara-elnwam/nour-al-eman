import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

// --- Models ---
class AttendanceRecord {
  String? date;
  String? checkInTime;
  String? checkOutTime;
  String? workingHours;
  String? locationName;
  String? userName;
  String? checkType;

  AttendanceRecord({
    this.date,
    this.checkInTime,
    this.checkOutTime,
    this.workingHours,
    this.locationName,
    this.userName,
    this.checkType,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        date: json['date'],
        checkInTime: json['checkInTime'],
        checkOutTime: json['checkOutTime'],
        workingHours: json['workingHours'],
        locationName: json['locationName'],
        userName: json['userName'],
        checkType: json['checkType'],
      );
}

// --- Screen ---
class SpecificEmployeeAttendanceScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const SpecificEmployeeAttendanceScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<SpecificEmployeeAttendanceScreen> createState() =>
      _SpecificEmployeeAttendanceScreenState();
}

class _SpecificEmployeeAttendanceScreenState
    extends State<SpecificEmployeeAttendanceScreen> {
  bool _isLoading = true;
  Map<String, List<AttendanceRecord>> _groupedAttendance = {};
  List<String> _availableMonths = [];
  int _currentMonthIndex = 0;

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
      List<AttendanceRecord> allRecords = [];

      // ── 1. جيب من السيرفر ──
      try {
        final url =
            'https://nour-al-eman.runasp.net/api/Locations/GetAll-employee-attendance-ByEmpId?EmpId=${widget.employeeId}';
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
          for (var item in data) {
            allRecords.add(AttendanceRecord.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint("Server fetch error: $e");
      }

      // ── 2. جيب السجلات المحلية ──
      // ✅ مهم: السجلات المحلية بتبقى أدق لأنها بتحفظ كل بصمة لوحدها
      try {
        final prefs = await SharedPreferences.getInstance();
        final localKey = 'local_attendance_${widget.employeeId}';
        final localJson = prefs.getString(localKey);
        if (localJson != null) {
          final List<dynamic> localList = jsonDecode(localJson);
          for (var item in localList) {
            allRecords.add(AttendanceRecord(
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

      _processData(allRecords);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<AttendanceRecord> rawData) {
    final validData =
    rawData.where((r) => _parseDate(r.date) != null).toList();
    // رتب تنازلياً
    validData.sort((a, b) =>
        _parseDate(b.date)!.compareTo(_parseDate(a.date)!));

    // ✅ كل record يظهر لوحده - مش بنحذف التكرار
    Map<String, List<AttendanceRecord>> groups = {};
    for (var entry in validData) {
      final date = _parseDate(entry.date)!;
      final monthYear = DateFormat('MMMM yyyy', 'ar').format(date);
      if (!groups.containsKey(monthYear)) groups[monthYear] = [];
      groups[monthYear]!.add(entry);
    }

    setState(() {
      _groupedAttendance = groups;
      _availableMonths = groups.keys.toList();
      _currentMonthIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF1976D2)))
            : _availableMonths.isEmpty
            ? _buildEmptyState()
            : Column(
          children: [
            _buildMonthNavigator(),
            _buildTableHeader(),
            Expanded(child: _buildAttendanceList()),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.black87),
            onPressed: _currentMonthIndex > 0
                ? () => setState(() => _currentMonthIndex--)
                : null,
          ),
          Text(
            _availableMonths[_currentMonthIndex],
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai'),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios,
                size: 18, color: Colors.black87),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _headerItem("اليوم"),
          _headerItem("حضور"),
          _headerItem("إنصراف"),
          _headerItem("ساعات العمل"),
        ],
      ),
    );
  }

  Widget _headerItem(String label) {
    return Expanded(
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 13,
              fontFamily: 'Almarai')),
    );
  }

  Widget _buildAttendanceList() {
    final currentMonth = _availableMonths[_currentMonthIndex];
    final logs = _groupedAttendance[currentMonth]!;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final date = _parseDate(log.date);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      date != null
                          ? DateFormat('EEEE', 'ar').format(date)
                          : "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Almarai'),
                    ),
                    Text(
                      date != null ? DateFormat('MM/dd').format(date) : "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
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
                child: Text(
                  log.workingHours ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
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

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "لا توجد بيانات حضور",
        style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Almarai'),
      ),
    );
  }
}