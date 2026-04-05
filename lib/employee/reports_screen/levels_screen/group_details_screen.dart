import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_details_screen.dart';
import 'staff_details_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final int groupId;
  final int levelId;
  final String groupName;
  final String teacherName;
  final int teacherId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.levelId,
    required this.groupName,
    required this.teacherName,
    required this.teacherId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<dynamic> _students = [];
  bool _isLoading = true;
  String? displayGroupName;
  String? displayTeacherName;
  int _resolvedTeacherId = 0;

  // ✅ حفظ بيانات المجموعة الكاملة لاستخدامها في التعديل
  Map<String, dynamic> _currentGroupData = {};

  final Color kPrimaryBlue = const Color(0xFF07427C);
  final Color kTextDark = const Color(0xFF2E3542);
  final Color orangeButton = const Color(0xFFC66422);

  List<dynamic> teachersList = [];
  List<dynamic> locationsList = [];

  // متغيرات التعديل
  int? selectedTeacherId;
  int? selectedLocationId;
  List<int> selectedDays = [];
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    displayGroupName = widget.groupName;
    displayTeacherName = widget.teacherName;
    _resolvedTeacherId = widget.teacherId;
    _fetchGroupData();
    _loadInitialDataForEdit();
  }

  Future<void> _fetchGroupData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      // ✅ Call 1: جلب طلاب المجموعة
      final studentsUrl = Uri.parse(
          'https://nour-al-eman.runasp.net/api/Group/GetGroupDetails?GroupId=${widget.groupId}&LevelId=${widget.levelId}');
      final studentsResponse = await http.get(studentsUrl, headers: {'Authorization': 'Bearer $token'});
      debugPrint("Group Students Response: ${studentsResponse.body}");

      // ✅ Call 2: جلب بيانات المجموعة الكاملة (empId, locId, sessions) من Getall
      final groupUrl = Uri.parse(
          'https://nour-al-eman.runasp.net/api/Group/Getall?levelid=${widget.levelId}');
      final groupResponse = await http.get(groupUrl);
      debugPrint("Groups List Response: ${groupResponse.body}");

      if (studentsResponse.statusCode == 200 && mounted) {
        final Map<String, dynamic> studentsData = json.decode(studentsResponse.body);
        final List<dynamic> studentsList = studentsData['data'] ?? [];

        // ✅ استخراج بيانات المجموعة المحددة من قائمة المجموعات
        Map<String, dynamic> groupInfo = {};
        if (groupResponse.statusCode == 200) {
          final groupsData = json.decode(groupResponse.body);
          final List<dynamic> allGroups = groupsData['data'] ?? [];
          // إيجاد المجموعة بالـ ID
          final matchedGroups = allGroups.where((g) => g['id'] == widget.groupId).toList();
          if (matchedGroups.isNotEmpty) {
            groupInfo = Map<String, dynamic>.from(matchedGroups.first);
            debugPrint("Found Group Info: $groupInfo");
          }
        }

        if (mounted) {
          setState(() {
            _students = studentsList;
            // ✅ حفظ بيانات المجموعة الكاملة من Getall
            _currentGroupData = groupInfo.isNotEmpty ? groupInfo : {};

            // تحديث اسم المجموعة
            if (groupInfo['name'] != null) displayGroupName = groupInfo['name'];

            // ✅ استخراج empId - نستخدم empId مباشرة لأن emp.id بييجي null من API
            final dynamic rawEmpId = groupInfo['empId'] ?? groupInfo['emp']?['id'];
            if (rawEmpId != null) {
              final int parsedId = int.tryParse(rawEmpId.toString()) ?? 0;
              if (parsedId > 0) _resolvedTeacherId = parsedId;
            }
            // fallback من widget.teacherId
            if (_resolvedTeacherId == 0 && widget.teacherId > 0) {
              _resolvedTeacherId = widget.teacherId;
            }
            if (groupInfo['emp']?['name'] != null) displayTeacherName = groupInfo['emp']['name'];

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Group fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInitialDataForEdit() async {
    try {
      final locRes = await http.get(Uri.parse('https://nour-al-eman.runasp.net/api/Locations/Getall'));
      final techRes = await http.get(Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetWithType?type=1'));
      if (mounted) {
        final techBody2 = jsonDecode(techRes.body);
        final teachers = techBody2 is List ? techBody2 : (techBody2['data'] ?? []);
        final locations = jsonDecode(locRes.body)['data'] ?? [];
        debugPrint("Teachers IDs: ${teachers.map((t) => '${t['id']}:${t['name']}').toList()}");
        debugPrint("Locations IDs: ${locations.map((l) => '${l['id']}:${l['name']}').toList()}");
        // تأكد أن الشيخ والمكتب الحاليين موجودين في القوائم
        final List<dynamic> finalTeachers = List.from(teachers);
        final List<dynamic> finalLocations = List.from(locations);

        if (_resolvedTeacherId > 0) {
          final teacherExists = finalTeachers.any((t) => t['id'] == _resolvedTeacherId);
          if (!teacherExists && _currentGroupData['emp'] != null) {
            finalTeachers.add({
              'id': _resolvedTeacherId,
              'name': _currentGroupData['emp']['name'] ?? displayTeacherName ?? widget.teacherName ?? '',
            });
          }
        }

        final dynamic rawLocId2 = _currentGroupData['locId'] ?? _currentGroupData['loc']?['id'];
        if (rawLocId2 != null) {
          final int? locId2 = int.tryParse(rawLocId2.toString());
          if (locId2 != null && locId2 > 0) {
            final locExists = finalLocations.any((l) => l['id'] == locId2);
            if (!locExists && _currentGroupData['loc'] != null) {
              finalLocations.add({
                'id': locId2,
                'name': _currentGroupData['loc']['name'] ?? 'مكتب $locId2',
              });
            }
          }
        }

        setState(() {
          locationsList = finalLocations;
          teachersList = finalTeachers;
        });
      }
    } catch (e) {
      debugPrint("Data Load Error: $e");
    }
  }

  Future<void> _updateGroupApi(String name, BuildContext dialogContext) async {
    // ✅ Validation
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك أدخل اسم المجموعة"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر الشيخ"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر المكتب"), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      String formattedTime = selectedTime != null
          ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
          : "20:00";

      final Map<String, dynamic> requestBody = {
        "Id": widget.groupId,
        "Name": name.trim(),
        "LevelId": widget.levelId,
        "EmpId": selectedTeacherId,
        "LocId": selectedLocationId,
        "Active": true,
        "Status": true,
        "Days": selectedDays.isEmpty ? [1] : selectedDays,
        "Time": formattedTime,
        "GroupSessions": (selectedDays.isEmpty ? [1] : selectedDays).asMap().entries.map((entry) => {
          "Day": entry.value,
          "Hour": formattedTime,
          "Status": true,
          "Serial": entry.key + 1,
        }).toList(),
      };

      debugPrint("Update Group Payload: ${jsonEncode(requestBody)}");

      final response = await http.put(
        Uri.parse('https://nour-al-eman.runasp.net/api/Group/Update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint("Update Group Response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) Navigator.pop(dialogContext);
        _showSnackBar("تم التحديث بنجاح ✅", Colors.green);
        _fetchGroupData();
      } else {
        _showSnackBar("فشل التحديث: ${response.statusCode}", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("خطأ في الاتصال بالسيرفر", Colors.red);
    }
  }

  void _showEditGroupDialog() {
    TextEditingController nameCont = TextEditingController(text: displayGroupName ?? widget.groupName);

    // ✅ الشيخ: من empId في _currentGroupData أو من _resolvedTeacherId
    final dynamic rawEmpId = _currentGroupData['empId'] ?? _currentGroupData['emp']?['id'];
    final int? parsedTeacherId = rawEmpId != null
        ? int.tryParse(rawEmpId.toString())
        : (_resolvedTeacherId > 0 ? _resolvedTeacherId : null);
    // تأكد أن الـ ID موجود فعلاً في القائمة قبل تعيينه
    final teacherIds = teachersList.map((t) => t['id'] as int?).toSet();
    selectedTeacherId = (parsedTeacherId != null && teacherIds.contains(parsedTeacherId))
        ? parsedTeacherId
        : null;

    // ✅ المكتب: من locId في _currentGroupData
    final dynamic rawLocId = _currentGroupData['locId'] ?? _currentGroupData['loc']?['id'];
    final int? parsedLocId = rawLocId != null ? int.tryParse(rawLocId.toString()) : null;
    // تأكد أن الـ ID موجود فعلاً في القائمة قبل تعيينه
    final locationIds = locationsList.map((l) => l['id'] as int?).toSet();
    selectedLocationId = (parsedLocId != null && locationIds.contains(parsedLocId))
        ? parsedLocId
        : null;

    // ✅ الأيام: من groupSessions أو sessions
    final List sessions = _currentGroupData['groupSessions'] ?? _currentGroupData['sessions'] ?? [];
    selectedDays = sessions
        .map<int>((s) {
      final d = s['day'] ?? s['Day'];
      return int.tryParse(d.toString()) ?? 0;
    })
        .where((d) => d > 0)
        .toSet()
        .toList();

    // ✅ الوقت: من أول session أو من حقل time
    String? rawTime = _currentGroupData['time'];
    if (sessions.isNotEmpty) {
      rawTime = sessions[0]['hour'] ?? sessions[0]['Hour'] ?? rawTime;
    }
    if (rawTime != null) {
      final parts = rawTime.toString().split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDs) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(
              child: Text("تعديل المجموعة",
                  style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("اسم المجموعة"),
                    TextField(controller: nameCont, decoration: _inputDecoration("الاسم")),
                    const SizedBox(height: 15),

                    // ✅ الشيخ - يظهر الشيخ الحالي مختاراً
                    _buildLabel("الشيخ"),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedTeacherId,
                      decoration: _inputDecoration("اختر الشيخ"),
                      items: teachersList.map((t) => DropdownMenuItem<int>(
                        value: t['id'],
                        child: Text(t['fullName'] ?? t['name'] ?? "", style: const TextStyle(fontFamily: 'Almarai')),
                      )).toList(),
                      onChanged: (val) {
                        setDs(() => selectedTeacherId = val);
                        setState(() => selectedTeacherId = val);
                      },
                    ),
                    const SizedBox(height: 15),

                    // ✅ الوقت - يظهر الوقت الحالي
                    _buildLabel("وقت الحصة"),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        selectedTime == null ? "اختر الوقت" : selectedTime!.format(context),
                        style: const TextStyle(fontFamily: 'Almarai'),
                      ),
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDs(() => selectedTime = picked);
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    // ✅ المكتب - يظهر المكتب الحالي مختاراً
                    _buildLabel("المكتب"),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedLocationId,
                      decoration: _inputDecoration("اختر المكتب"),
                      items: locationsList.map((l) => DropdownMenuItem<int>(
                        value: l['id'],
                        child: Text(l['name'] ?? "", style: const TextStyle(fontFamily: 'Almarai')),
                      )).toList(),
                      onChanged: (val) {
                        setDs(() => selectedLocationId = val);
                        setState(() => selectedLocationId = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // ✅ الأيام - الأيام الحالية محددة
                    _buildLabel("الأيام"),
                    Wrap(
                      spacing: 5,
                      children: List.generate(7, (i) {
                        final days = ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];
                        bool isSel = selectedDays.contains(i + 1);
                        return FilterChip(
                          label: Text(days[i],
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSel ? Colors.white : Colors.black,
                                  fontFamily: 'Almarai')),
                          selected: isSel,
                          selectedColor: orangeButton,
                          onSelected: (v) => setDs(() =>
                          v ? selectedDays.add(i + 1) : selectedDays.remove(i + 1)),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                onPressed: () => _updateGroupApi(nameCont.text, context),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                child: const Text("حفظ", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<dynamic>> _fetchAvailableStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Student/GetByStatus?status=true');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData is List) return decodedData;
        if (decodedData is Map && decodedData['data'] != null) return decodedData['data'];
      }
    } catch (e) {
      debugPrint("Exception during fetch: $e");
    }
    return [];
  }

  Future<void> _addStudentToGroup(dynamic studentData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Student/Update');

      Map<String, dynamic> updatedPayload = Map<String, dynamic>.from(studentData);
      updatedPayload['groupId'] = widget.groupId;
      updatedPayload['levelId'] = widget.levelId;

      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(updatedPayload),
      );

      if (response.statusCode == 200) {
        _showSnackBar("تم نقل الطالب للمجموعة بنجاح", Colors.green);
        _fetchGroupData();
      } else {
        _showSnackBar("حدث خطأ في تحديث بيانات الطالب", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ في الاتصال", Colors.red);
    }
  }

  void _showAddStudentDialog() {
    List<dynamic> allAvailable = [];
    List<dynamic> filteredAvailable = [];
    bool isFetching = true;
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (allAvailable.isEmpty && isFetching) {
            _fetchAvailableStudents().then((data) {
              setDialogState(() {
                allAvailable = data;
                filteredAvailable = data;
                isFetching = false;
              });
            });
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("إضافة طالب للمجموعة",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Almarai')),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "ابحث باسم الطالب...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredAvailable = allAvailable
                              .where((s) => s['name'].toString().toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: isFetching
                          ? const Center(child: CircularProgressIndicator())
                          : filteredAvailable.isEmpty
                          ? const Center(child: Text("لا توجد نتائج"))
                          : ListView.separated(
                        itemCount: filteredAvailable.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final student = filteredAvailable[index];
                          return ListTile(
                            title: Text(student['name'],
                                style: const TextStyle(fontSize: 13, fontFamily: 'Almarai')),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () {
                                Navigator.pop(context);
                                _addStudentToGroup(student);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updatePassword(int studentId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = Uri.parse('https://nour-al-eman.runasp.net/api/Student/Update');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${prefs.getString('token')}',
          'Content-Type': 'application/json',
        },
        body: json.encode({"id": studentId, "password": newPassword}),
      );
      if (response.statusCode == 200) {
        _showSnackBar("تم تحديث كلمة المرور", Colors.green);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ", Colors.red);
    }
  }

  Future<void> _deleteStudent(int studentId, String studentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // أولاً: جلب بيانات الطالب الكاملة
      final getResponse = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Student/GetById?id=$studentId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (getResponse.statusCode != 200) {
        _showSnackBar("فشل جلب بيانات الطالب", Colors.red);
        return;
      }

      final responseData = jsonDecode(getResponse.body);
      dynamic rawData = responseData['data'];
      Map<String, dynamic> fullData = {};
      if (rawData is List && rawData.isNotEmpty) {
        fullData = Map<String, dynamic>.from(rawData[0]);
      } else if (rawData is Map<String, dynamic>) {
        fullData = Map<String, dynamic>.from(rawData);
      }

      // ثانياً: بناء payload نظيف بدون nested objects
      // السيرفر بيرفض لو group موجود وجواه days/time = null
      final Map<String, dynamic> cleanPayload = {
        "id": fullData['id'],
        "name": fullData['name'],
        "phone": fullData['phone'] ?? "",
        "phone2": fullData['phone2'] ?? "",
        "address": fullData['address'] ?? "",
        "parentJob": fullData['parentJob'] ?? "",
        "governmentSchool": fullData['governmentSchool'] ?? "",
        "attendanceType": fullData['attendanceType'] ?? "",
        "paymentType": fullData['paymentType'] ?? "",
        "documentType": fullData['documentType'] ?? "",
        "typeInfamily": fullData['typeInfamily'] ?? "",
        "birthDate": fullData['birthDate'],
        "joinDate": fullData['joinDate'],
        "locId": fullData['locId'],
        "levelId": fullData['levelId'],
        "groupId": null, // إزالة الطالب من المجموعة
        "days": [],      // مطلوب من السيرفر
        "time": "00:00", // مطلوب من السيرفر
      };

      debugPrint("Clean remove student payload: ${jsonEncode(cleanPayload)}");

      final updateResponse = await http.put(
        Uri.parse('https://nour-al-eman.runasp.net/api/Student/Update'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(cleanPayload),
      );

      debugPrint("Remove Student from Group (${updateResponse.statusCode}): ${updateResponse.body}");

      if (updateResponse.statusCode == 200 || updateResponse.statusCode == 204) {
        _showSnackBar("تم حذف الطالب من المجموعة ✅", Colors.green);
        Future.delayed(const Duration(milliseconds: 300), () => _fetchGroupData());
      } else {
        _showSnackBar("فشل الحذف: ${updateResponse.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ في الاتصال", Colors.red);
      debugPrint("Delete student error: $e");
    }
  }

  void _showResetPasswordDialog(int studentId, String studentName) {
    final TextEditingController passController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("إعادة تعيين كلمة السر", style: TextStyle(fontFamily: 'Almarai')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupTextField("كلمة المرور الجديدة", passController),
                const SizedBox(height: 10),
                _buildPopupTextField("تأكيد كلمة المرور", confirmPassController),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              ElevatedButton(
                onPressed: () async {
                  if (passController.text == confirmPassController.text) {
                    setDialogState(() => isSubmitting = true);
                    await _updatePassword(studentId, passController.text);
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text("تغيير"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(int studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: Text("هل أنت متأكد من حذف $studentName؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await _deleteStudent(studentId, studentName);
              },
              child: const Text("حذف"),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5, top: 5),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Almarai')),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text("طلاب مجموعة: ${displayGroupName ?? widget.groupName}",
              style: const TextStyle(fontFamily: 'Almarai', fontSize: 16)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: "edit_btn",
              onPressed: _showEditGroupDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: "add_student_btn",
              onPressed: _showAddStudentDialog,
              backgroundColor: orangeButton,
              child: const Icon(Icons.person_add, color: Colors.white, size: 28),
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: kPrimaryBlue))
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // بانر الشيخ
              InkWell(
                onTap: () {
                  if (_resolvedTeacherId == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("لا يوجد معرّف للشيخ، تأكد من ربط الشيخ بهذه المجموعة",
                            style: TextStyle(fontFamily: 'Almarai')),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaffDetailsScreen(
                        staffId: _resolvedTeacherId,
                        staffName: displayTeacherName ?? widget.teacherName,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimaryBlue.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: kPrimaryBlue),
                      const SizedBox(width: 10),
                      Text("الشيخ: ",
                          style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold, color: kPrimaryBlue)),
                      Expanded(
                        child: Text(
                          displayTeacherName ?? widget.teacherName,
                          style: TextStyle(fontFamily: 'Almarai', color: kTextDark),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: kPrimaryBlue.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // جدول الطلاب
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: _students.isEmpty
                      ? const Center(child: Text("المجموعة فارغة", style: TextStyle(fontFamily: 'Almarai')))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(4),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                          4: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey[100]),
                            children: [
                              _buildHeaderCell("#"),
                              _buildHeaderCell("الاسم", align: TextAlign.right),
                              _buildHeaderCell("بيانات"),
                              _buildHeaderCell("كلمة المرور"),
                              _buildHeaderCell("حذف"),
                            ],
                          ),
                          ..._students.asMap().entries.map((entry) {
                            int index = entry.key;
                            var student = entry.value;
                            return TableRow(
                              children: [
                                _buildDataCell("${index + 1}"),
                                _buildDataCell(student['name'] ?? "بدون اسم", align: TextAlign.right),
                                _buildActionIcon(Icons.person_outline, Colors.blue, () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) => StudentDetailsScreen(
                                      studentId: student['id'],
                                      studentName: student['name'] ?? "",
                                    ),
                                  ));
                                }),
                                _buildActionIcon(Icons.lock_open, Colors.orange, () {
                                  _showResetPasswordDialog(student['id'], student['name'] ?? "");
                                }),
                                _buildActionIcon(Icons.delete_outline, Colors.red, () {
                                  _showDeleteDialog(student['id'], student['name'] ?? "");
                                }),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.center}) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text, textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Almarai')),
  );

  Widget _buildDataCell(String text, {TextAlign align = TextAlign.center}) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text, textAlign: align, style: const TextStyle(fontSize: 13, fontFamily: 'Almarai')),
  );

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) =>
      IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap);

  Widget _buildPopupTextField(String label, TextEditingController controller) => TextField(
    controller: controller,
    obscureText: true,
    textAlign: TextAlign.right,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  void _showSnackBar(String message, Color color) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: color,
    ),
  );
}