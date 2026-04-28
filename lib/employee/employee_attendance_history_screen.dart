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
  bool _hasError = false;
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

  // ✅ السيرفر هو المصدر الوحيد - لا كاش محلي إطلاقاً
  Future<void> _fetchAttendanceLogs() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        _showError("لم يتم العثور على بيانات المستخدم");
        setState(() => _hasError = true);
        return;
      }

      final String token = prefs.getString('user_token') ?? '';
      final url =
          "https://nourelman.runasp.net/api/Locations/GetAll-employee-attendance?UserId=${prefs.getString('user_guid') ?? ''}";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['data'] ?? [];
        debugPrint("📡 Server returned ${data.length} records");

        final List<AttendanceData> records = [];
        for (var item in data) {
          records.add(AttendanceData(
            userName: item['userName'] ?? item['username'],
            checkType: item['checkType'],
            locationName: item['locationName'],
            date: item['date'],
            checkInTime: item['checkInTime'],
            checkOutTime: item['checkOutTime'],
            workingHours: item['workingHours'],
          ));
        }

        debugPrint("✅ Total records to display: ${records.length}");
        _processData(records);
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
        _showError("فشل في تحميل البيانات من السيرفر (${response.statusCode})");
        setState(() => _hasError = true);
      }
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      _showError("تعذر الاتصال بالسيرفر، تحقق من الإنترنت وحاول مرة أخرى");
      setState(() => _hasError = true);
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
    validData.sort((a, b) {
      final dateA = _parseServerDate(a.date);
      final dateB = _parseServerDate(b.date);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      final dateCmp = dateB.compareTo(dateA);
      if (dateCmp != 0) return dateCmp;
      final inA = a.checkInTime ?? '';
      final inB = b.checkInTime ?? '';
      return inB.compareTo(inA);
    });

    Map<String, List<AttendanceData>> groups = {};
    for (var entry in validData) {
      DateTime date = _parseServerDate(entry.date)!;
      String monthYear = DateFormat('MMMM yyyy', 'ar').format(date);
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
            ? const Center(child: CircularProgressIndicator())
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