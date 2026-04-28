import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _hasError = false;
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
    try { return DateTime.parse(dateStr); } catch (_) {}
    try { return DateFormat("M/d/yyyy").parse(dateStr); } catch (_) {}
    try { return DateFormat("MM/dd/yyyy").parse(dateStr); } catch (_) {}
    try { return DateFormat("M/dd/yyyy").parse(dateStr); } catch (_) {}
    return null;
  }

  // ✅ السيرفر هو المصدر الوحيد - لا كاش محلي إطلاقاً
  Future<void> _fetchAttendanceLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final url =
          'https://nourelman.runasp.net/api/Locations/GetAll-employee-attendance-ByEmpId?EmpId=${widget.employeeId}';
      final prefs = await SharedPreferences.getInstance();
      final String token = prefs.getString('user_token') ?? '';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'] ?? [];
        debugPrint("📡 Server returned ${data.length} records for employee ${widget.employeeId}");

        final List<AttendanceRecord> records =
        data.map((item) => AttendanceRecord.fromJson(item)).toList();

        _processData(records);
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
        setState(() => _hasError = true);
      }
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<AttendanceRecord> rawData) {
    final validData =
    rawData.where((r) => _parseDate(r.date) != null).toList();
    validData.sort((a, b) =>
        _parseDate(b.date)!.compareTo(_parseDate(a.date)!));

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
            : _hasError
            ? _buildErrorState()
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "تعذر تحميل البيانات من السيرفر",
            style: TextStyle(color: Colors.grey, fontFamily: 'Almarai'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _fetchAttendanceLogs,
            child: const Text("إعادة المحاولة"),
          ),
        ],
      ),
    );
  }
}