import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Student {
  final int id;
  final String name;
  Student({required this.id, required this.name});
}

class StudentAttendanceScreen extends StatefulWidget {
  final int groupId;
  final List<Student> students;

  const StudentAttendanceScreen({
    super.key,
    required this.groupId,
    required this.students,
  });

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with WidgetsBindingObserver {

  static const Color kDarkBlue = Color(0xFF07427C);
  static const Color kOrange   = Color(0xFFC66422);
  static const Color kBg       = Color(0xFFF4F6FA);
  static const Color kBorder   = Color(0xFFDDE3EE);

  bool _isLoading = false;
  bool _isSaving  = false;

  Map<int, List<Map<String, dynamic>>> _historyByStudent = {};
  late List<Map<String, dynamic>> _newEntries;

  final List<String> _ratingOptions = ["ممتاز", "جيد جدا", "جيد", "مقبول", "ضعيف"];

  String get _cacheKey =>
      "att_${widget.groupId}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}";

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newEntries = widget.students.map((s) => _emptyEntry(s)).toList();
    _loadCachedThenFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCachedThenFetch();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Persistence
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadCachedThenFetch() async {
    await _loadFromCache();
    await _fetchAndFillForm();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_cacheKey);
      if (raw == null) return;
      final List decoded = json.decode(raw);
      if (!mounted) return;
      setState(() {
        _newEntries = widget.students.map((s) {
          final cached = decoded.firstWhere(
                (e) => e["stId"] == s.id,
            orElse: () => null,
          );
          return cached != null ? Map<String, dynamic>.from(cached) : _emptyEntry(s);
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(_newEntries));
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _emptyEntry(Student s) => {
    "stId"   : s.id,
    "name"   : s.name,
    "status" : false,
    "oldSave": null,
    "newSave": null,
    "note"   : "",
    "points" : "",
  };

  Future<void> _fetchAndFillForm() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final url = "https://nourelman.runasp.net/api/Group/GetGroupAttendace?GroupId=${widget.groupId}";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;

      final List raw           = json.decode(res.body)["data"] ?? [];
      final String todayDate   = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final Map<int, Map<String, dynamic>> todayLatest = {};
      final Map<int, List<Map<String, dynamic>>> history = {};

      for (final item in raw) {
        final int stId        = item["studentId"] ?? 0;
        final String? dateStr = item["createDate"];
        if (dateStr == null) continue;
        final bool isToday = dateStr.substring(0, 10) == todayDate;

        if (isToday) {
          final int currentId  = item["id"] ?? 0;
          final int existingId = todayLatest[stId]?["_id"] ?? -1;
          if (currentId > existingId) {
            todayLatest[stId] = {
              "_id"    : currentId,
              "present": item["isPresent"] ?? false,
              "oldSave": _toRating(item["oldAttendanceNote"]),
              "newSave": _toRating(item["newAttendanceNote"]),
              "note"   : item["note"] ?? "",
              "points" : (item["points"] ?? 0).toString(),
            };
          }
        } else {
          history.putIfAbsent(stId, () => []);
          history[stId]!.add({
            "isPresent"        : item["isPresent"] ?? false,
            "oldAttendanceNote": _toRating(item["oldAttendanceNote"]),
            "newAttendanceNote": _toRating(item["newAttendanceNote"]),
            "note"             : item["note"] ?? "",
            "points"           : item["points"] ?? 0,
            "createDate"       : dateStr,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _historyByStudent = history;
        _newEntries = widget.students.map((s) {
          final rec = todayLatest[s.id];
          if (rec != null) {
            return {
              "stId"   : s.id,
              "name"   : s.name,
              "status" : rec["present"],
              "oldSave": rec["oldSave"],
              "newSave": rec["newSave"],
              "note"   : rec["note"],
              "points" : rec["points"],
            };
          }
          return _newEntries.firstWhere(
                (e) => e["stId"] == s.id,
            orElse: () => _emptyEntry(s),
          );
        }).toList();
      });

      await _saveToCache();
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNewRecords() async {
    setState(() => _isSaving = true);

    final payload = _newEntries.map((s) => {
      "id"               : 0,
      "studentId"        : s["stId"],
      "groupId"          : widget.groupId,
      "isPresent"        : s["status"],
      "points"           : int.tryParse(s["points"]?.toString() ?? "0") ?? 0,
      "note"             : s["note"] ?? "",
      "newAttendanceNote": _toIndex(s["newSave"]),
      "oldAttendanceNote": _toIndex(s["oldSave"]),
      "createDate"       : DateTime.now().toIso8601String(),
      "createBy"         : "Teacher",
      "createFrom"       : "Mobile",
    }).toList();

    try {
      final res = await http.post(
        Uri.parse("https://nourelman.runasp.net/api/StudentAttendance/submit"),
        headers: {"accept": "*/*", "Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _showToast(" تم الحفظ بنجاح", kDarkBlue);
        await _saveToCache();
        _fetchHistoryOnly();
      } else {
        _showToast(" خطأ: ${res.statusCode}", Colors.red);
        debugPrint("Save error body: ${res.body}");
      }
    } catch (e) {
      _showToast(" فشل الاتصال", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _fetchHistoryOnly() async {
    try {
      final url = "https://nourelman.runasp.net/api/Group/GetGroupAttendace?GroupId=${widget.groupId}";
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;

      final List raw         = json.decode(res.body)["data"] ?? [];
      final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final Map<int, List<Map<String, dynamic>>> history = {};
      for (final item in raw) {
        final int stId        = item["studentId"] ?? 0;
        final String? dateStr = item["createDate"];
        if (dateStr == null) continue;
        if (dateStr.substring(0, 10) != todayDate) {
          history.putIfAbsent(stId, () => []);
          history[stId]!.add({
            "isPresent"        : item["isPresent"] ?? false,
            "oldAttendanceNote": _toRating(item["oldAttendanceNote"]),
            "newAttendanceNote": _toRating(item["newAttendanceNote"]),
            "note"             : item["note"] ?? "",
            "points"           : item["points"] ?? 0,
            "createDate"       : dateStr,
          });
        }
      }
      if (mounted) setState(() => _historyByStudent = history);
    } catch (e) {
      debugPrint("History fetch error: $e");
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════════════════

  String? _toRating(dynamic index) {
    if (index == null) return null;
    int i = (index is int) ? index : int.tryParse(index.toString()) ?? 0;
    if (i < 1 || i > _ratingOptions.length) return null;
    return _ratingOptions[i - 1];
  }

  int _toIndex(String? rating) {
    if (rating == null) return 0;
    int i = _ratingOptions.indexOf(rating);
    return i != -1 ? i + 1 : 0;
  }

  void _showToast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBg,
        bottomNavigationBar: _buildSaveButton(),
        body: _isLoading && _newEntries.every((e) => e["status"] == false)
            ? const Center(child: CircularProgressIndicator(color: kDarkBlue))
            : SingleChildScrollView(
          child: Column(
            children: [
              _buildFormSection(),
              const SizedBox(height: 8),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // نسب الأعمدة الثابتة
  // ═══════════════════════════════════════════════════════════════════════════
  static const double _c1  = 44;  // حضور  (ثابت)
  static const double _c4  = 44;  // تعليق (ثابت)
  static const double _gap = 4;

  Widget _buildFormSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // عرض المساحة المتاحة بعد طرح الأعمدة الثابتة والـ padding والـ gaps
          final double available =
              constraints.maxWidth - 16 - _c1 - _c4 - (_gap * 4);
          final double cName   = available * 0.35;
          final double cOldNew = available * 0.325;

          // ── دالة بناء خلية الهيدر بنفس أبعاد خلايا الصف تماماً ──────────
          Widget colHeader(String t, double w) => SizedBox(
            width: w,
            child: Text(
              t,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'Almarai'),
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── هيدر ──────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                decoration: const BoxDecoration(
                  color: kDarkBlue,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13),
                      topRight: Radius.circular(13)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    colHeader("اسم الطالب", cName),
                    SizedBox(width: _gap),
                    colHeader("حضور", _c1),
                    SizedBox(width: _gap),
                    colHeader("حفظ قديم", cOldNew),
                    SizedBox(width: _gap),
                    colHeader("حفظ جديد", cOldNew),
                    SizedBox(width: _gap),
                    colHeader("تعليق", _c4),
                  ],
                ),
              ),
              // ── صفوف الطلاب ───────────────────────────────────────────────
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _newEntries.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: kBorder),
                itemBuilder: (_, i) => _buildRow(i, cName, cOldNew),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(int i, double cName, double cOldNew) {
    final entry   = _newEntries[i];
    final present = entry["status"] == true;
    final hasNote = entry["note"]?.toString().trim().isNotEmpty == true;

    return Container(
      color: i % 2 == 0 ? Colors.white : const Color(0xFFF8F9FC),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── اسم الطالب ────────────────────────────────────────────────────
          SizedBox(
            width: cName,
            child: Text(
              entry["name"],
              textAlign: TextAlign.center, // ✅ محاذاة مطابقة للهيدر
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2340),
                  fontFamily: 'Almarai'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: _gap),

          // ── حضور ─────────────────────────────────────────────────────────
          SizedBox(
            width: _c1,
            child: Center( // ✅ نفس عرض الهيدر + Center
              child: Transform.scale(
                scale: 0.85,
                child: Checkbox(
                  value: present,
                  activeColor: kDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: (v) async {
                    setState(() {
                      final u = Map<String, dynamic>.from(_newEntries[i]);
                      u["status"] = v;
                      if (v == false) {
                        u["oldSave"] = null;
                        u["newSave"] = null;
                      }
                      _newEntries[i] = u;
                    });
                    await _saveToCache();
                  },
                ),
              ),
            ),
          ),
          SizedBox(width: _gap),

          // ── حفظ قديم ─────────────────────────────────────────────────────
          SizedBox(
            width: cOldNew,
            child: _IndependentDrop(
              key: ValueKey("old_${_newEntries[i]['stId']}"),
              value: _newEntries[i]["oldSave"],
              options: _ratingOptions,
              enabled: present,
              onChanged: (val) async {
                setState(() {
                  final u = Map<String, dynamic>.from(_newEntries[i]);
                  u["oldSave"] = val;
                  _newEntries[i] = u;
                });
                await _saveToCache();
              },
            ),
          ),
          SizedBox(width: _gap),

          // ── حفظ جديد ─────────────────────────────────────────────────────
          SizedBox(
            width: cOldNew,
            child: _IndependentDrop(
              key: ValueKey("new_${_newEntries[i]['stId']}"),
              value: _newEntries[i]["newSave"],
              options: _ratingOptions,
              enabled: present,
              onChanged: (val) async {
                setState(() {
                  final u = Map<String, dynamic>.from(_newEntries[i]);
                  u["newSave"] = val;
                  _newEntries[i] = u;
                });
                await _saveToCache();
              },
            ),
          ),
          SizedBox(width: _gap),

          // ── تعليق ─────────────────────────────────────────────────────────
          SizedBox(
            width: _c4,
            child: Center( // ✅ نفس عرض الهيدر + Center
              child: InkWell(
                onTap: present ? () => _showNoteDialog(i) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  decoration: BoxDecoration(
                    color: present
                        ? (hasNote ? kDarkBlue.withOpacity(0.12) : kBg)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasNote ? Icons.comment : Icons.comment_outlined,
                    size: 20,
                    color: present
                        ? (hasNote ? kDarkBlue : Colors.grey.shade400)
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  // زر الحفظ
  // ═══════════════════════════════════
  Widget _buildSaveButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, -3))
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kDarkBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _saveNewRecords,
            icon: _isSaving
                ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
            label: Text(
              _isSaving ? "جاري الحفظ..." : "حفظ التعديلات",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Almarai'),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════
  // History السابق
  // ═══════════════════════════════════
  Widget _buildHistorySection() {
    if (_historyByStudent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: const [
              Icon(Icons.history_rounded, size: 16, color: kDarkBlue),
              SizedBox(width: 6),
              Text("سجل الحضور السابق",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kDarkBlue,
                      fontFamily: 'Almarai')),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          itemCount: widget.students.length,
          itemBuilder: (_, si) {
            final st      = widget.students[si];
            final records = _historyByStudent[st.id] ?? [];
            if (records.isEmpty) return const SizedBox.shrink();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: ExpansionTile(
                tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                childrenPadding:
                const EdgeInsets.fromLTRB(12, 0, 12, 10),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: kDarkBlue.withOpacity(0.1),
                  child: Text(
                    st.name.isNotEmpty ? st.name[0] : "?",
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: kDarkBlue),
                  ),
                ),
                title: Text(st.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2340),
                        fontFamily: 'Almarai')),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kDarkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("${records.length} سجل",
                      style: const TextStyle(
                          fontSize: 11,
                          color: kDarkBlue,
                          fontWeight: FontWeight.bold)),
                ),
                children:
                records.map((rec) => _buildHistoryCard(rec)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> rec) {
    final bool present = rec["isPresent"] == true;
    String dateStr = "--";
    try {
      if (rec["createDate"] != null) {
        final d = DateTime.parse(rec["createDate"]);
        dateStr = DateFormat("yyyy/MM/dd – hh:mm a").format(d);
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(
              color: present ? const Color(0xFF2E7D32) : Colors.red.shade300,
              width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  present ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 15,
                  color: present ? const Color(0xFF2E7D32) : Colors.red),
              const SizedBox(width: 5),
              Text(
                present ? "حضور" : "غياب",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: present ? const Color(0xFF2E7D32) : Colors.red),
              ),
              const Spacer(),
              Text(dateStr,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          if (present) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _Chip(
                    label: "حفظ قديم",
                    value: rec["oldAttendanceNote"] ?? "--",
                    color: kDarkBlue),
                const SizedBox(width: 6),
                _Chip(
                    label: "حفظ جديد",
                    value: rec["newAttendanceNote"] ?? "--",
                    color: kOrange),
                const SizedBox(width: 6),
                _Chip(
                    label: "نقاط",
                    value: "${rec["points"] ?? 0}",
                    color: const Color(0xFF2E7D32)),
              ],
            ),
            if (rec["note"]?.toString().trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.comment_outlined,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(rec["note"],
                        style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  // ديالوج التعليق
  // ═══════════════════════════════════
  void _showNoteDialog(int i) {
    final noteCtrl   = TextEditingController(text: _newEntries[i]["note"]);
    final pointsCtrl = TextEditingController(
        text: _newEntries[i]["points"]?.toString() ?? "");

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text("تعليق ونقاط",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: kDarkBlue,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Almarai')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField("التعليق", noteCtrl, maxLines: 3),
              const SizedBox(height: 12),
              _dialogField("النقاط", pointsCtrl,
                  keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء",
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kDarkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                setState(() {
                  _newEntries[i]["note"]   = noteCtrl.text;
                  _newEntries[i]["points"] = pointsCtrl.text;
                });
                await _saveToCache();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("حفظ",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: kDarkBlue,
                fontFamily: 'Almarai')),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: "اكتب هنا...",
            filled: true,
            fillColor: kBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// Widgets مساعدة
// ══════════════════════════════════════════════════════════

/// StatefulWidget مستقل لكل dropdown مع محاذاة مركزية مطابقة للهيدر
class _IndependentDrop extends StatefulWidget {
  final String? value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _IndependentDrop({
    super.key,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_IndependentDrop> createState() => _IndependentDropState();
}

class _IndependentDropState extends State<_IndependentDrop> {
  String? _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(_IndependentDrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && _localValue == oldWidget.value) {
      setState(() => _localValue = widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeVal = widget.options.contains(_localValue) ? _localValue : null;

    return Container(
      alignment: Alignment.center, // ✅ يضمن محاذاة الـ dropdown تحت الهيدر بالظبط
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeVal,
          isExpanded: true,
          hint: Text(
            "—",
            textAlign: TextAlign.center, // ✅ الـ hint متمركز
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF1A2340),
              fontFamily: 'Almarai'),
          iconSize: 14,
          alignment: Alignment.center, // ✅ محاذاة القيمة المختارة في المنتصف
          onChanged: widget.enabled
              ? (val) {
            setState(() => _localValue = val);
            widget.onChanged(val);
          }
              : null,
          items: widget.options
              .map((e) => DropdownMenuItem<String>(
            value: e,
            alignment: Alignment.center, // ✅ العناصر متمركزة
            child: Text(e, textAlign: TextAlign.center),
          ))
              .toList(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color.withOpacity(0.8))),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    ),
  );
}