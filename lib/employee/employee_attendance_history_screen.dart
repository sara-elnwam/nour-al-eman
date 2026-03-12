import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'attendance_model.dart';

class EmployeeAttendanceHistoryScreen extends StatefulWidget {
  const EmployeeAttendanceHistoryScreen({super.key});

  @override
  State<EmployeeAttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends State<EmployeeAttendanceHistoryScreen> {
  bool _isLoading = true;
  Map<String, List<AttendanceData>> _groupedAttendance = {};
  List<String> _availableMonths = [];
  int _currentMonthIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceLogs();
  }

  DateTime? _parseServerDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try { return DateTime.parse(dateStr); } catch (_) {}
    try { return DateFormat("M/d/yyyy").parse(dateStr); } catch (_) {}
    try { return DateFormat("MM/dd/yyyy").parse(dateStr); } catch (_) {}
    try { return DateFormat("d/M/yyyy").parse(dateStr); } catch (_) {}
    return null;
  }

  String _normalizeDate(String? dateStr) {
    final parsed = _parseServerDate(dateStr);
    if (parsed == null) return dateStr ?? '';
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  Future<void> _fetchAttendanceLogs() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        _showError("لم يتم العثور على بيانات المستخدم");
        return;
      }

      debugPrint("👤 userId = $userId");

      // ✅ اطبع كل الـ keys عشان نشوف المحلي محفوظ فين
      final allKeys = prefs.getKeys();
      final attendanceKeys = allKeys.where((k) => k.startsWith('local_attendance')).toList();
      debugPrint("🗂️ All attendance keys: $attendanceKeys");

      // ── الخطوة 1: جيب كل السجلات المحلية (من كل الـ keys) ──
      // كل بصمة تظهر لوحدها - مش بنعمل merge بالتاريخ
      final List<AttendanceData> allRecords = [];
      // نستخدم unique key (تاريخ + checkInTime) عشان نمنع التكرار الحقيقي فقط
      final Set<String> addedKeys = {};

      final possibleKeys = {'local_attendance_$userId', ...attendanceKeys};
      debugPrint("🔍 Checking local keys: $possibleKeys");

      for (final localKey in possibleKeys) {
        final String? localJson = prefs.getString(localKey);
        if (localJson == null) continue;
        try {
          final List<dynamic> localList = jsonDecode(localJson);
          debugPrint("📱 Key '$localKey' has ${localList.length} records");
          for (var item in localList) {
            final normDate = _normalizeDate(item['date']?.toString());
            final inTime = item['checkInTime']?.toString() ?? '';
            final uniqueKey = '$normDate|$inTime';
            if (normDate.isEmpty || addedKeys.contains(uniqueKey)) continue;
            addedKeys.add(uniqueKey);
            allRecords.add(AttendanceData(
              userName: item['userName'] ?? item['username'],
              checkType: item['checkType'],
              locationName: item['locationName'],
              date: item['date'],
              checkInTime: item['checkInTime'],
              checkOutTime: item['checkOutTime'],
              workingHours: item['workingHours'],
            ));
          }
        } catch (e) {
          debugPrint('Error loading $localKey: $e');
        }
      }

      try {
        final String token2 = prefs.getString('user_token') ?? '';
        final url =
            "https://nourelman.runasp.net/api/Locations/GetAll-employee-attendance?UserId=${prefs.getString('user_guid') ?? ''}";
        debugPrint("📡 Fetching server: $url");
        final response = await http.get(
          Uri.parse(url),
          headers: {
            if (token2.isNotEmpty && token2 != 'no_token')
              'Authorization': 'Bearer $token2',
          },
        );
        debugPrint("📡 Status: ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final List<dynamic> data = decoded['data'] ?? [];
          debugPrint("📡 Server returned ${data.length} records");

          for (var item in data) {
            final normDate = _normalizeDate(item['date']?.toString());
            final inTime = item['checkInTime']?.toString() ?? '';
            final uniqueKey = '$normDate|$inTime';
            if (normDate.isEmpty || addedKeys.contains(uniqueKey)) continue;
            // ✅ أضف فقط لو مش موجود محلياً (بنفس التاريخ + وقت الحضور)
            addedKeys.add(uniqueKey);
            allRecords.add(AttendanceData(
              userName: item['userName'] ?? item['username'],
              checkType: item['checkType'],
              locationName: item['locationName'],
              date: item['date'],
              checkInTime: item['checkInTime'],
              checkOutTime: item['checkOutTime'],
              workingHours: item['workingHours'],
            ));
          }
        }
      } catch (e) {
        debugPrint('Server fetch error: $e');
      }

      debugPrint("✅ Total records to display: ${allRecords.length}");
      _processData(allRecords);

    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _processData(List<AttendanceData> rawData) {
    List<AttendanceData> validData = rawData
        .where((item) => _parseServerDate(item.date) != null)
        .toList();

    // ✅ كل record يظهر لوحده - مش بنعمل merge
    validData.sort((a, b) =>
        _parseServerDate(b.date)!.compareTo(_parseServerDate(a.date)!));

    Map<String, List<AttendanceData>> groups = {};
    for (var entry in validData) {
      DateTime date = _parseServerDate(entry.date)!;
      String monthYear = DateFormat('MMMM yyyy', 'ar').format(date);
      if (!groups.containsKey(monthYear)) groups[monthYear] = [];
      groups[monthYear]!.add(entry);
    }

    debugPrint("📅 Months: ${groups.keys.toList()}");

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
            ? const Center(child: CircularProgressIndicator())
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
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
            onPressed: _currentMonthIndex > 0
                ? () => setState(() => _currentMonthIndex--)
                : null,
          ),
          const SizedBox(width: 15),
          Text(_availableMonths[_currentMonthIndex],
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          const SizedBox(width: 15),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black87),
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
          border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(children: [
        _headerItem("اليوم"),
        _headerItem("حضور"),
        _headerItem("إنصراف"),
        _headerItem("ساعات العمل"),
      ]),
    );
  }

  Widget _headerItem(String label) {
    return Expanded(
      child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, fontFamily: 'Almarai')),
    );
  }

  Widget _buildAttendanceList() {
    String currentMonth = _availableMonths[_currentMonthIndex];
    List<AttendanceData> logs = _groupedAttendance[currentMonth]!;

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        DateTime? date = _parseServerDate(log.date);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            Expanded(
              child: Column(children: [
                Text(date != null ? DateFormat('EEEE', 'ar').format(date) : "",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(date != null ? DateFormat('yyyy/MM/dd').format(date) : "",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ),
            Expanded(
              child: Text(log.checkInTime ?? "--", textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            Expanded(
              child: Text(log.checkOutTime ?? "--", textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            Expanded(
              child: Text(log.workingHours ?? "--", textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
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
          const Text("لا توجد سجلات حضور متاحة حالياً",
              style: TextStyle(color: Colors.grey, fontFamily: 'Almarai')),
          TextButton(onPressed: _fetchAttendanceLogs, child: const Text("تحديث البيانات"))
        ],
      ),
    );
  }
}