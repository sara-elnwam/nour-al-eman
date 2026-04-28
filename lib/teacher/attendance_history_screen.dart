import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'attendance_model.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
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
    try { return DateFormat("M/dd/yyyy").parse(dateStr); } catch (_) {}
    return null;
  }

  String? _toNormalizedDate(String? dateStr) {
    final parsed = _parseServerDate(dateStr);
    if (parsed == null) return null;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  // ✅ FIX: السيرفر هو المصدر الوحيد للحقيقة
  // الكاش المحلي = fallback فقط لو السيرفر مش متاح
  Future<void> _fetchAttendanceLogs() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty || userId == "0") {
        _showError("لم يتم العثور على بيانات المستخدم");
        return;
      }

      final List<AttendanceData> records = [];
      bool serverSuccess = false;

      // 1. السيرفر أولاً
      try {
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
          final List<dynamic> serverData = decoded['data'] ?? [];
          debugPrint("📡 Server returned ${serverData.length} records");

          for (var item in serverData) {
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

          serverSuccess = true;

          // احفظ النسخة الأخيرة في الكاش لتحديثه للـ fallback الجاي
          await prefs.setString('local_attendance_$userId', jsonEncode(serverData));
        }
      } catch (e) {
        debugPrint('Server fetch error: $e');
      }

      // 2. Fallback: لو السيرفر فشل، خذ من الكاش المحلي فقط
      if (!serverSuccess) {
        debugPrint("⚠️ Server unavailable, falling back to local cache");
        final String? localJson = prefs.getString('local_attendance_$userId');
        if (localJson != null) {
          try {
            final List<dynamic> localList = jsonDecode(localJson);
            for (var item in localList) {
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
            debugPrint("📦 Loaded ${records.length} records from local cache");
          } catch (e) {
            debugPrint('Error loading local cache: $e');
          }
        }
      }

      debugPrint("✅ Total records to display: ${records.length}");
      _processData(records);

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
    Map<String, List<AttendanceData>> groups = {};

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
        appBar: AppBar(
          title: const Text("حضور و انصراف المعلم",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 16)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
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
          Text(
            _availableMonths[_currentMonthIndex],
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
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
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12,
            fontFamily: 'Almarai'),
      ),
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
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      date != null ? DateFormat('EEEE', 'ar').format(date) : "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      date != null ? DateFormat('yyyy/MM/dd').format(date) : "",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  log.checkInTime ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  log.checkOutTime ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  log.workingHours ?? "--",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
          const Text("لا توجد سجلات حضور متاحة حالياً",
              style: TextStyle(color: Colors.grey, fontFamily: 'Almarai')),
          TextButton(
              onPressed: _fetchAttendanceLogs, child: const Text("تحديث البيانات"))
        ],
      ),
    );
  }
}