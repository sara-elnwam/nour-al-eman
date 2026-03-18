import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final Color darkBlue = Color(0xFF2E3542);
const Color kActiveBlue = Color(0xFF1976D2);
const Color kLabelGrey = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);

class MainAttendanceScreen extends StatefulWidget {
  @override
  _MainAttendanceScreenState createState() => _MainAttendanceScreenState();
}

class _MainAttendanceScreenState extends State<MainAttendanceScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  String _currentLocationText = "جاري تحديد موقعك...";
  String _currentTime = "";

  // ✅ FIX: القيم الصح اللي بيفهمها السيرفر
  String _checkType = "check-in";

  late Timer _timer;

  Position? _myPosition;

  Map<String, dynamic>? _selectedOffice;
  String? _selectedLocationName;
  bool _isInRange = false;
  bool _isLoadingStatus = true;
  bool _isLoading = false;
  List<dynamic> _apiOffices = [];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (timer) => _updateTime());
    _initLocation();
    _fetchOffices();
    _checkCurrentStatus();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = intl.DateFormat('hh:mm a')
        .format(now)
        .replaceFirst('AM', 'ص')
        .replaceFirst('PM', 'م');
    if (mounted) setState(() => _currentTime = formattedTime);
  }

  Future<void> _fetchOffices() async {
    try {
      final response = await http
          .get(Uri.parse('https://nour-al-eman.runasp.net/api/Locations/Getall'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _apiOffices = data['data'] ?? data);
      }
    } catch (e) {
      _showSnackBar("تعذر الاتصال بالسيرفر", Colors.red);
    }
  }

  String? _normalizeDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return intl.DateFormat('M/d/yyyy').parse(dateStr).toString().substring(0, 10);
    } catch (_) {}
    try {
      return DateTime.parse(dateStr).toString().substring(0, 10);
    } catch (_) {}
    try {
      return intl.DateFormat('d/M/yyyy').parse(dateStr).toString().substring(0, 10);
    } catch (_) {}
    return null;
  }

  Future<void> _checkCurrentStatus() async {
    setState(() => _isLoadingStatus = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('user_id') ?? "";
      if (empId.isEmpty) return;

      final String todayDate =
      intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      bool foundTodayLocally = false;

      // ── 1. جيب من السجل المحلي أولاً ──
      final localKey = 'local_attendance_$empId';
      final localJson = prefs.getString(localKey);
      if (localJson != null) {
        final List<dynamic> localRecords = jsonDecode(localJson);
        // ✅ FIX: جيب آخر record في النهارده مش أول واحد
        dynamic lastTodayRec;
        for (var rec in localRecords) {
          final normalized = _normalizeDate(rec['date']?.toString());
          if (normalized == todayDate) {
            lastTodayRec = rec;
          }
        }
        if (lastTodayRec != null) {
          final bool hasCheckOut = (lastTodayRec['checkOutTime'] != null &&
              lastTodayRec['checkOutTime'].toString().isNotEmpty) ||
              lastTodayRec['checkType'] == 'check-out';
          if (mounted) {
            setState(() => _checkType = hasCheckOut ? "check-in" : "check-out");
          }
          foundTodayLocally = true;
        }
      }

      if (!foundTodayLocally) {
        try {
          final String userGuid = prefs.getString('user_guid') ?? '';
          if (userGuid.isEmpty) return;
          final String tokenStatus = prefs.getString('user_token') ?? '';
          final url =
              'https://nour-al-eman.runasp.net/api/Locations/GetAll-employee-attendance?UserId=$userGuid';
          final response = await http.get(
            Uri.parse(url),
            headers: {
              if (tokenStatus.isNotEmpty && tokenStatus != 'no_token')
                'Authorization': 'Bearer $tokenStatus',
            },
          );
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List<dynamic> logs = data['data'] ?? [];
            // ✅ FIX: جيب آخر record في النهارده من السيرفر
            dynamic lastServerRec;
            for (var log in logs) {
              final String? normalized = _normalizeDate(log['date']?.toString());
              if (normalized == todayDate) {
                lastServerRec = log;
              }
            }
            if (lastServerRec != null) {
              final bool hasCheckOut = lastServerRec['checkOutTime'] != null &&
                  lastServerRec['checkOutTime'].toString().isNotEmpty &&
                  lastServerRec['checkOutTime'].toString() != "--";
              if (mounted) {
                setState(() => _checkType = hasCheckOut ? "check-in" : "check-out");
              }
            }
          }
        } catch (e) {
          debugPrint("Server status check error: $e");
        }
      }
    } catch (e) {
      debugPrint("Status check error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _myPosition = position;
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);
      if (mounted && placemarks.isNotEmpty) {
        setState(() {
          _currentLocationText =
          "${placemarks[0].locality ?? ''} - ${placemarks[0].administrativeArea ?? ''}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentLocationText = "تعذر تحديد الموقع");
    }
  }

  void _checkDistance(Map<String, dynamic> office) {
    if (_myPosition == null) {
      _showSnackBar(
          "جاري تحديد موقعك، حاول مرة أخرى خلال ثوانٍ", Colors.orange);
      return;
    }

    String rawCoords = (office['coordinates'] ?? "").replaceAll(',', ';');
    List<String> parts =
    rawCoords.split(';').where((s) => s.trim().isNotEmpty).toList();

    List<Map<String, double>> polygonPoints = [];
    for (int i = 0; i + 1 < parts.length; i += 2) {
      double? lat = double.tryParse(parts[i].trim());
      double? lng = double.tryParse(parts[i + 1].trim());
      if (lat != null && lng != null) {
        polygonPoints.add({'lat': lat, 'lng': lng});
      }
    }

    bool result = false;
    if (polygonPoints.isNotEmpty) {
      double centerLat = polygonPoints
          .map((p) => p['lat']!)
          .reduce((a, b) => a + b) /
          polygonPoints.length;
      double centerLng = polygonPoints
          .map((p) => p['lng']!)
          .reduce((a, b) => a + b) /
          polygonPoints.length;
      double maxRadius = 0;
      for (var pt in polygonPoints) {
        double r = Geolocator.distanceBetween(
            centerLat, centerLng, pt['lat']!, pt['lng']!);
        if (r > maxRadius) maxRadius = r;
      }
      double allowedRadius = maxRadius + 150;
      double distToCenter = Geolocator.distanceBetween(
          _myPosition!.latitude,
          _myPosition!.longitude,
          centerLat,
          centerLng);
      result = distToCenter <= allowedRadius;

      debugPrint("🔍 ========== DEBUG: _checkDistance ==========");
      debugPrint("📍 موقع المستخدم: lat=${_myPosition!.latitude}, lng=${_myPosition!.longitude}");
      debugPrint("🏢 الفرع المختار: ${office['name']} (id=${office['id']})");
      debugPrint("📏 مسافة المستخدم من المركز: ${distToCenter.toStringAsFixed(1)} متر");
      debugPrint("📏 الحد المسموح (+150م): ${allowedRadius.toStringAsFixed(1)} متر");
      debugPrint("🧮 النتيجة: $result");
      debugPrint("🔍 =============================================");
    }

    setState(() {
      _selectedOffice = office;
      _selectedLocationName = office['name'];
      _isInRange = result;
    });

    if (!_isInRange) {
      _showSnackBar("أنت خارج النطاق لـ $_selectedLocationName", Colors.red);
    } else {
      _showSnackBar("أنت داخل نطاق $_selectedLocationName ✅", Colors.green);
    }
  }

  Future<void> _startBiometricAuth() async {
    if (!_isInRange) {
      _showSnackBar("لا يمكنك البصم لأنك خارج النطاق", Colors.red);
      return;
    }
    try {
      final bool canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuth) {
        _showSnackBar("البصمة غير مدعومة على هذا الجهاز", Colors.red);
        return;
      }
      bool authenticated = await auth.authenticate(
        localizedReason: 'تأكيد الحضور في $_selectedLocationName',
      );
      if (authenticated) await _sendAttendanceToServer();
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء التوثيق", Colors.red);
    }
  }

  Future<void> _sendAttendanceToServer() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String rawId = prefs.getString('user_id') ?? "";
      final String? userGuid = prefs.getString('user_guid');

      if (rawId.isEmpty || rawId == "0") {
        final loginDataStr2 = prefs.getString('loginData');
        if (loginDataStr2 != null) {
          final ld = jsonDecode(loginDataStr2);
          rawId = ld['userId']?.toString() ?? ld['id']?.toString() ?? "";
        }
      }

      if (userGuid == null || userGuid.isEmpty) {
        _showSnackBar("خطأ: كود المستخدم غير صالح", Colors.red);
        return;
      }
      if (_myPosition == null) {
        _showSnackBar("خطأ: لم يتم تحديد موقعك بعد", Colors.red);
        return;
      }

      // ✅ FIX: استخدم locId من الـ dropdown المختار مش من prefs
      final int? selectedLocId = _selectedOffice != null
          ? int.tryParse(_selectedOffice!['id'].toString())
          : null;

      if (selectedLocId == null) {
        _showSnackBar("برجاء اختيار المكتب أولاً", Colors.orange);
        return;
      }

      final Map<String, dynamic> attendanceData = {
        "id": 0,
        "userId": userGuid,
        // ✅ FIX: "check-in" / "check-out" زي الويب بالظبط
        "checkType": _checkType,
        "locId": selectedLocId,
        "hisCoordinate": {
          "latitude": _myPosition!.latitude,
          "longitude": _myPosition!.longitude,
        },
      };

      debugPrint("ATTENDANCE REQUEST: ${json.encode(attendanceData)}");

      final String token = prefs.getString('user_token') ?? '';
      debugPrint('🔑 Token: $token');

      final response = await http.post(
        Uri.parse(
            'https://nour-al-eman.runasp.net/api/Locations/employee-attendance'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
        body: json.encode(attendanceData),
      );

      debugPrint("ATTENDANCE STATUS: ${response.statusCode}");
      debugPrint("ATTENDANCE BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final dynamic error = responseData['error'];
        final dynamic dataVal = responseData['data'];

        await _saveLocally(prefs, rawId);

        if ((error != null &&
            error.toString().isNotEmpty &&
            error.toString() != "null") ||
            (dataVal is String &&
                dataVal.toString().toLowerCase().contains('invalid'))) {
          _showSnackBar(
            _checkType == "check-in"
                ? "✅ تم تسجيل الحضور بنجاح"
                : "✅ تم تسجيل الانصراف بنجاح",
            Colors.green,
          );
          _flipCheckType();
          return;
        }

        _showSnackBar(
          _checkType == "check-in"
              ? "✅ تم تسجيل الحضور بنجاح"
              : "✅ تم تسجيل الانصراف بنجاح",
          Colors.green,
        );
        _flipCheckType();
      } else {
        _showSnackBar("فشل التسجيل (${response.statusCode})", Colors.red);
      }
    } catch (e) {
      debugPrint("EXCEPTION: $e");
      _showSnackBar("حدث خطأ تقني: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _flipCheckType() {
    if (mounted) {
      setState(() {
        // ✅ FIX: toggle بين check-in و check-out
        _checkType = _checkType == "check-in" ? "check-out" : "check-in";
      });
    }
  }

  Future<void> _saveLocally(SharedPreferences prefs, String rawId) async {
    try {
      String userName = "";
      final empDataStr = prefs.getString('employee_name');
      if (empDataStr != null && empDataStr.isNotEmpty) {
        userName = empDataStr;
      } else {
        final loginDataStr = prefs.getString('loginData');
        if (loginDataStr != null) {
          final ld = jsonDecode(loginDataStr);
          userName = ld['name']?.toString() ?? ld['userName']?.toString() ?? "";
        }
      }

      String effectiveId = rawId;
      if (effectiveId.isEmpty || effectiveId == "0") {
        final loginDataStr2 = prefs.getString('loginData');
        if (loginDataStr2 != null) {
          final ld = jsonDecode(loginDataStr2);
          effectiveId = ld['userId']?.toString() ?? ld['id']?.toString() ?? rawId;
        }
      }

      final localKey = 'local_attendance_$effectiveId';
      debugPrint("💾 Saving attendance with key: $localKey");
      final existing = prefs.getString(localKey);
      List<dynamic> records = existing != null ? jsonDecode(existing) : [];

      final now = DateTime.now();
      final todayStr = '${now.month}/${now.day}/${now.year}';
      final timeStr =
          '${now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      final todayNormalized = intl.DateFormat('yyyy-MM-dd').format(now);

      // ✅ FIX: مقارنة بـ "check-in" مش "In"
      if (_checkType == 'check-in') {
        records.insert(0, {
          'userName': userName,
          'checkType': 'check-in',
          'locationName': _selectedLocationName ?? "",
          'date': todayStr,
          'checkInTime': timeStr,
          'checkOutTime': null,
          'workingHours': null,
        });
      } else {
        int openIdx = records.indexWhere((r) {
          final recNormalized = _normalizeDate(r['date']?.toString());
          return recNormalized == todayNormalized &&
              r['checkInTime'] != null &&
              r['checkOutTime'] == null;
        });

        if (openIdx >= 0) {
          records[openIdx]['checkOutTime'] = timeStr;
          records[openIdx]['workingHours'] =
              _calcWorkingHours(records[openIdx]['checkInTime'], timeStr);
        } else {
          records.insert(0, {
            'userName': userName,
            'checkType': 'check-out',
            'locationName': _selectedLocationName ?? "",
            'date': todayStr,
            'checkInTime': null,
            'checkOutTime': timeStr,
            'workingHours': null,
          });
        }
      }

      if (records.length > 200) records = records.sublist(0, 200);
      await prefs.setString(localKey, jsonEncode(records));
    } catch (e) {
      debugPrint('Local save error: $e');
    }
  }

  String? _calcWorkingHours(String? inTimeStr, String outTimeStr) {
    try {
      if (inTimeStr == null) return null;
      int toSeconds(String t) {
        final parts = t
            .replaceAll(' AM', '')
            .replaceAll(' PM', '')
            .split(':');
        final isPM = t.contains('PM');
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        int s = int.parse(parts[2]);
        if (isPM && h != 12) h += 12;
        if (!isPM && h == 12) h = 0;
        return h * 3600 + m * 60 + s;
      }

      final diff = toSeconds(outTimeStr) - toSeconds(inTimeStr);
      if (diff <= 0) return null;
      final hh = (diff ~/ 3600).toString().padLeft(2, '0');
      final mm = ((diff % 3600) ~/ 60).toString().padLeft(2, '0');
      final ss = (diff % 60).toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    } catch (_) {
      return null;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontFamily: 'Almarai')),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            title: const Text("  "),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true),
        body: _isLoadingStatus
            ? const Center(
            child: CircularProgressIndicator(color: kActiveBlue))
            : RefreshIndicator(
          onRefresh: () async {
            await _initLocation();
            await _fetchOffices();
            await _checkCurrentStatus();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10)
                    ],
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Column(
                    children: [
                      _buildMiniRow(
                          Icons.location_on, _currentLocationText),
                      const Divider(height: 25, color: kBorderColor),
                      _buildMiniRow(Icons.access_time_filled,
                          "ساعات العمل: 00:00 ص - 00:00 م"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildModernDropdown(),
                const SizedBox(height: 40),
                Text(_currentTime,
                    style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                        fontFamily: 'Almarai')),
                const SizedBox(height: 40),
                _buildFingerprintButton(),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: CircularProgressIndicator(
                          color: kActiveBlue)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: kActiveBlue, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14, color: darkBlue, fontFamily: 'Almarai'))),
      ],
    );
  }

  Widget _buildModernDropdown() {
    final Map<dynamic, bool> seen = {};
    final List<dynamic> uniqueOffices = [];
    for (var office in _apiOffices) {
      final key = office['id'];
      if (!seen.containsKey(key)) {
        seen[key] = true;
        uniqueOffices.add(office);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("اختيار المكتب / الموقع",
            style: TextStyle(
                fontSize: 13,
                color: kLabelGrey,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                _selectedOffice != null ? kActiveBlue : kBorderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              isExpanded: true,
              value: _selectedOffice,
              hint: const Text("اختر مكان تواجدك الحالي",
                  style: TextStyle(fontFamily: 'Almarai')),
              items: uniqueOffices.map((office) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: office as Map<String, dynamic>,
                  child: Text(office['name'] ?? "",
                      style: const TextStyle(fontFamily: 'Almarai')),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _checkDistance(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFingerprintButton() {
    bool canPress = _selectedOffice != null && _isInRange;
    // ✅ FIX: مقارنة بـ "check-in" مش "In"
    String statusText = _checkType == "check-in"
        ? "اضغط لتسجيل الحضور"
        : "اضغط لتسجيل الانصراف";
    Color activeColor = _checkType == "check-in" ? kActiveBlue : Colors.red;

    return Column(
      children: [
        GestureDetector(
          onTap: canPress
              ? _startBiometricAuth
              : () {
            if (_selectedOffice == null) {
              _showSnackBar(
                  "برجاء اختيار المكتب أولاً", Colors.orange);
            } else if (!_isInRange) {
              _showSnackBar(
                  "أنت خارج النطاق، لا يمكنك البصم", Colors.red);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                  color: canPress ? activeColor : Colors.grey.shade300,
                  width: 5),
              boxShadow: [
                if (canPress)
                  BoxShadow(
                      color: activeColor.withOpacity(0.3), blurRadius: 20)
              ],
            ),
            child: Icon(
              // ✅ FIX: مقارنة بـ "check-in" مش "In"
              _checkType == "check-in" ? Icons.fingerprint : Icons.exit_to_app,
              size: 80,
              color: canPress ? activeColor : Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          statusText,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: canPress ? activeColor : Colors.grey,
              fontFamily: 'Almarai'),
        ),
      ],
    );
  }
}