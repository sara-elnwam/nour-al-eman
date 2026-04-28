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
          .get(Uri.parse('https://nourelman.runasp.net/api/Locations/Getall'));
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

  // ✅ السيرفر هو المصدر الوحيد لحالة الحضور - لا كاش محلي إطلاقاً
  Future<void> _checkCurrentStatus() async {
    setState(() => _isLoadingStatus = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String empId = prefs.getString('user_id') ?? "";
      if (empId.isEmpty) return;

      final String todayDate =
      intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

      final String userGuid = prefs.getString('user_guid') ?? '';
      final String tokenStatus = prefs.getString('user_token') ?? '';

      if (userGuid.isEmpty) return;

      final url =
          'https://nourelman.runasp.net/api/Locations/GetAll-employee-attendance?UserId=$userGuid';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (tokenStatus.isNotEmpty && tokenStatus != 'no_token')
            'Authorization': 'Bearer $tokenStatus',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> logs = data['data'] ?? [];

        // شوف آخر حالة لليوم ده من السيرفر مباشرة
        String? lastStatusToday;
        for (var log in logs) {
          final String? normalized = _normalizeDate(log['date']?.toString());
          if (normalized == todayDate) {
            final bool hasCheckOut = log['checkOutTime'] != null &&
                log['checkOutTime'].toString().isNotEmpty &&
                log['checkOutTime'].toString() != "--";
            lastStatusToday = hasCheckOut ? "check-in" : "check-out";
            // لا break - نكمل لآخر سجل لليوم ده
          }
        }
        if (lastStatusToday != null && mounted) {
          setState(() => _checkType = lastStatusToday!);
        }
      } else {
        debugPrint("❌ Status check failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Status check error: $e");
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

  // ✅ البصمة تُرسل للسيرفر فقط - لو فشل الإرسال يظهر خطأ ولا يُحفظ محلياً
  Future<void> _sendAttendanceToServer() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userGuid = prefs.getString('user_guid');
      final String token = prefs.getString('user_token') ?? '';

      if (userGuid == null || userGuid.isEmpty) {
        _showSnackBar("خطأ: كود المستخدم غير صالح", Colors.red);
        return;
      }
      if (_myPosition == null) {
        _showSnackBar("خطأ: لم يتم تحديد موقعك بعد", Colors.red);
        return;
      }

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
        "checkType": _checkType,
        "locId": selectedLocId,
        "hisCoordinate": {
          "latitude": _myPosition!.latitude,
          "longitude": _myPosition!.longitude,
        },
      };

      final bool hasToken = token.isNotEmpty && token != 'no_token';

      final response = await http.post(
        Uri.parse('https://nourelman.runasp.net/api/Locations/employee-attendance'),
        headers: {
          'Content-Type': 'application/json',
          if (hasToken) 'Authorization': 'Bearer $token',
        },
        body: json.encode(attendanceData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['error'] == null ||
            responseData['error'].toString() == "null" ||
            responseData['error'].toString().isEmpty) {
          _showSnackBar(
            _checkType == "check-in"
                ? "✅ تم تسجيل الحضور بنجاح"
                : "✅ تم تسجيل الانصراف بنجاح",
            Colors.green,
          );
          _flipCheckType();
        } else {
          _showSnackBar("خطأ: ${responseData['error']}", Colors.red);
        }
      } else {
        _showSnackBar("فشل في الاتصال بالسيرفر (${response.statusCode})", Colors.red);
      }
    } catch (e) {
      debugPrint("❌ Send attendance error: $e");
      // ❌ لا حفظ محلي - لو السيرفر مش متاح يظهر خطأ فقط
      _showSnackBar("لا يوجد اتصال بالإنترنت، لم يتم تسجيل الحضور. حاول مرة أخرى", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _flipCheckType() {
    if (mounted) {
      setState(() {
        _checkType = _checkType == "check-in" ? "check-out" : "check-in";
      });
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