import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

// ───────── Models ─────────
class AttendanceData {
  String? date;
  String? checkInTime;
  String? checkOutTime;
  String? workingHours;
  String? userName;
  String? checkType;
  String? locationName;

  AttendanceData({
    this.date,
    this.checkInTime,
    this.checkOutTime,
    this.workingHours,
    this.userName,
    this.checkType,
    this.locationName,
  });

  factory AttendanceData.fromJson(Map<String, dynamic> json) => AttendanceData(
    date: json['date'],
    checkInTime: json['checkInTime'],
    checkOutTime: json['checkOutTime'],
    workingHours: json['workingHours'],
    userName: json['userName'],
    checkType: json['checkType'],
    locationName: json['locationName'],
  );
}

// ───────── Tab Widget ─────────
class AttendanceLogsTab extends StatefulWidget {
  final int empId;

  const AttendanceLogsTab({super.key, required this.empId});

  @override
  State<AttendanceLogsTab> createState() => _AttendanceLogsTabState();
}

class _AttendanceLogsTabState extends State<AttendanceLogsTab> {
  bool _isLoading = true;
  Map<String, List<AttendanceData>> _groupedByMonth = {};
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
      List<AttendanceData> allRecords = [];

      // ── 1. جيب السجلات المحلية أولاً (هي الأدق والأحدث) ──
      // ✅ هذا هو المفتاح الصح - نفس المفتاح اللي بتحفظه شاشة البصمة
      try {
        final prefs = await SharedPreferences.getInstance();
        final localKey = 'local_attendance_${widget.empId}';
        final localJson = prefs.getString(localKey);
        if (localJson != null) {
          final List<dynamic> localList = jsonDecode(localJson);
          for (var item in localList) {
            allRecords.add(AttendanceData(
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

      // ── 2. جيب من السيرفر وأضف اللي مش موجود محلياً ──
      // ✅ endpoint الصح للـ check-in/check-out
      try {
        final prefs2 = await SharedPreferences.getInstance();
        final String token2 = prefs2.getString('user_token') ?? '';
        final String userGuid2 = prefs2.getString('user_guid') ?? '';
        if (userGuid2.isEmpty) return;
        final url =
            'https://nourelman.runasp.net/api/Locations/GetAll-employee-attendance?UserId=$userGuid2';
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

          // عمل set من التواريخ الموجودة محلياً عشان منضفش تكرار
          // ✅ dedup بـ date+checkInTime عشان منحذفش بصمات مختلفة في نفس اليوم
          final Set<String> localKeys = {};
          for (var r in allRecords) {
            if (r.date != null) localKeys.add('${r.date}|${r.checkInTime ?? ""}');
          }

          for (var item in data) {
            final serverRecord = AttendanceData.fromJson(item);
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
      debugPrint("Fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<AttendanceData> rawData) {
    // رتب من الأحدث للأقدم
    final validData = rawData.where((r) => _parseDate(r.date) != null).toList();
    validData.sort((a, b) => _parseDate(b.date)!.compareTo(_parseDate(a.date)!));

    // ✅ كل record يظهر على حدة - مش بنحذف التكرار
    // عشان كل بصمة حضور أو انصراف تظهر في سطر لوحده
    Map<String, List<AttendanceData>> groups = {};
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
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : _availableMonths.isEmpty
          ? _buildEmptyState()
          : Column(
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
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: Row(
        children: [
          _headerItem("اليوم", 2),
          _headerItem("حضور", 2),
          _headerItem("إنصراف", 2),
          _headerItem("ساعات", 1),
        ],
      ),
    );
  }

  Widget _headerItem(String label, int flexValue) {
    return Expanded(
      flex: flexValue,
      child: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Almarai')),
    );
  }

  Widget _buildAttendanceList() {
    final currentMonth = _availableMonths[_currentMonthIndex];
    final logs = _groupedByMonth[currentMonth]!;

    return ListView.builder(
      itemCount: logs.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final log = logs[index];
        final date = _parseDate(log.date);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Almarai'),
                    ),
                    Text(
                      date != null ? DateFormat('MM/dd').format(date) : "",
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
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
                      color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  log.checkOutTime ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  log.workingHours ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "لا توجد سجلات متاحة لهذا الموظف",
            style: TextStyle(color: Colors.grey, fontSize: 15, fontFamily: 'Almarai'),
          ),
        ],
      ),
    );
  }
}