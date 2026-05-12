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

class _MainAttendanceScreenState extends State<MainAttendanceScreen>
    with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();

  String _currentLocationText = "جاري تحديد موقعك...";
  String _currentTime = "";
  String _checkType = "check-in";
  late Timer _timer;
  Position? _myPosition;
  Map<String, dynamic>? _selectedOffice;
  String? _selectedLocationName;
  bool _isInRange = false;
  bool _isLoadingStatus = false;
  bool _isLoading = false;
  List<dynamic> _apiOffices = [];

  @override
  void initState() {
    super.initState();
    _checkUserGuid();
    WidgetsBinding.instance.addObserver(this);
    _updateTime();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (timer) => _updateTime());
    Future.microtask(() async {
      await _initLocation();
      await _fetchOffices();
    });
  }

  Future<void> _checkUserGuid() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_guid');
    debugPrint("👤 Stored user_guid: $userId");
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedOffice != null) {
      debugPrint("🔄 App resumed: refreshing status...");
      _checkCurrentStatus();
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatted = intl.DateFormat('hh:mm a')
        .format(now)
        .replaceFirst('AM', 'ص')
        .replaceFirst('PM', 'م');
    if (mounted) setState(() => _currentTime = formatted);
  }

  Future<void> _fetchOffices() async {
    try {
      final response = await http
          .get(Uri.parse('https://nourelman.runasp.net/api/Locations/Getall'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newOffices = data['data'] ?? data;
        setState(() {
          _apiOffices = newOffices;
          if (_selectedOffice != null) {
            final matched = newOffices.firstWhere(
                  (o) => o['id'].toString() == _selectedOffice!['id'].toString(),
              orElse: () => null,
            );
            _selectedOffice = matched;
          }
        });
      }
    } catch (e) {
      _showSnackBar("تعذر الاتصال بالسيرفر", Colors.red);
    }
  }

  Future<void> _checkCurrentStatus({bool silent = false}) async {
    if (_selectedOffice == null) {
      if (!silent && mounted) setState(() => _isLoadingStatus = false);
      return;
    }

    if (!silent && mounted) setState(() => _isLoadingStatus = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('user_guid');
      final String token = prefs.getString('user_token') ?? '';

      if (userId == null || userId.isEmpty || userId == 'null') {
        debugPrint("❌ userId غير صالح: $userId");
        if (!silent && mounted) setState(() => _isLoadingStatus = false);
        return;
      }

      final int locationId = int.tryParse(_selectedOffice!['id'].toString()) ?? 0;
      if (locationId == 0) {
        debugPrint("❌ locationId غير صالح");
        if (!silent && mounted) setState(() => _isLoadingStatus = false);
        return;
      }

      // ✅ استخدم userId و locId (بحرف i صغير)
      final url = 'https://nourelman.runasp.net/api/Locations/get-employee-attendance-status?userId=$userId&locId=$locationId';

      debugPrint("🌐 Calling API: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint("📦 Status Code: ${response.statusCode}");
      debugPrint("📦 RAW BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ المفتاح هو: checkType موجود داخل data['data']
        String checkTypeValue = '';

        if (data['data'] != null && data['data'] is Map) {
          final innerData = data['data'] as Map;
          if (innerData['checkType'] != null) {
            checkTypeValue = innerData['checkType'].toString().trim();
          }
        }

        // لو لسه مفيش، جرب data['data'] لو كان String
        if (checkTypeValue.isEmpty && data['data'] != null && data['data'] is String) {
          checkTypeValue = data['data'].toString().trim();
        }

        // لو لسه مفيش، جرب data نفسها لو كان String
        if (checkTypeValue.isEmpty && data is String) {
          checkTypeValue = data.trim();
        }

        debugPrint("✅ checkTypeValue final = '$checkTypeValue'");

        if (mounted) {
          String newCheckType;
          // ✅ المنطق: آخر عملية كانت check-in يبقى الزرار check-out والعكس
          if (checkTypeValue == 'check-in') {
            newCheckType = 'check-out';
          } else if (checkTypeValue == 'check-out') {
            newCheckType = 'check-in';
          } else {
            newCheckType = 'check-in';
          }

          if (newCheckType != _checkType) {
            debugPrint("🔄 _checkType: $_checkType => $newCheckType");
            setState(() => _checkType = newCheckType);
          }
        }
      } else {
        debugPrint("❌ Non-200 response: ${response.statusCode}");
        debugPrint("❌ Response body: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Status check error: $e");
    } finally {
      if (!silent && mounted) setState(() => _isLoadingStatus = false);
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
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
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
      if (lat != null && lng != null)
        polygonPoints.add({'lat': lat, 'lng': lng});
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

      double distToCenter = Geolocator.distanceBetween(
          _myPosition!.latitude,
          _myPosition!.longitude,
          centerLat,
          centerLng);
      result = distToCenter <= (maxRadius + 150);
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
      _checkCurrentStatus();
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
        _showSnackBar(
            "البصمة غير مدعومة أو غير مفعلة على هذا الجهاز. يرجى تفعيلها من إعدادات الهاتف.",
            Colors.red);
        return;
      }

      bool authenticated = false;
      try {
        authenticated = await auth.authenticate(
          localizedReason: 'تأكيد الحضور في $_selectedLocationName',
        );
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('user_cancel') ||
            msg.contains('notavailable') ||
            msg.contains('canceled')) {
          return;
        }
        _showSnackBar(
            "يرجى التأكد من نظافة الحساس ووضع إصبعك بشكل صحيح، أو تأكد من تسجيل بصمتك في إعدادات الهاتف.",
            Colors.orange);
        return;
      }

      if (authenticated) await _sendAttendanceToServer();
    } catch (e) {
      debugPrint("خطأ غير متوقع في البصمة: $e");
    }
  }

  Future<void> _sendAttendanceToServer() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userGuid = prefs.getString('user_guid');
      final String token = prefs.getString('user_token') ?? '';

      if (_selectedOffice == null || _myPosition == null) {
        _showSnackBar("بيانات الموقع أو المكتب غير مكتملة", Colors.orange);
        return;
      }

      final int selectedLocId = int.parse(_selectedOffice!['id'].toString());

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

      debugPrint("📤 Sending attendance: ${json.encode(attendanceData)}");

      final response = await http
          .post(
        Uri.parse('https://nourelman.runasp.net/api/Locations/employee-attendance'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
        body: json.encode(attendanceData),
      ).timeout(const Duration(seconds: 15));

      debugPrint("📦 Attendance response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          _checkType == "check-in"
              ? "✅ تم تسجيل الحضور بنجاح"
              : "✅ تم تسجيل الانصراف بنجاح",
          Colors.green,
        );

        // ✅ بعد تسجيل العملية، جيب الحالة الجديدة
        await _checkCurrentStatus();

      } else {
        _showSnackBar("فشل في تسجيل العملية (${response.statusCode})", Colors.red);
      }
    } catch (e) {
      debugPrint("❌ Send attendance error: $e");
      _showSnackBar("لا يوجد اتصال بالإنترنت", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          centerTitle: true,
        ),
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
                color: _selectedOffice != null ? kActiveBlue : kBorderColor),
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
    Color activeColor = (_checkType == "check-in") ? kActiveBlue : Colors.red;

    return Column(
      children: [
        GestureDetector(
          onTap: canPress
              ? _startBiometricAuth
              : () {
            if (_selectedOffice == null) {
              _showSnackBar("برجاء اختيار المكتب أولاً", Colors.orange);
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
              _checkType == "check-in"
                  ? Icons.fingerprint
                  : Icons.exit_to_app,
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