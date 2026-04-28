import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const Color _spBlue    = Color(0xFF1976D2);
const Color _spGrey    = Color(0xFF718096);
const Color _spBorder  = Color(0xFFE2E8F0);
final Color _spOrange  = const Color(0xFFC66422);
final Color _spDark    = const Color(0xFF2E3542);

const String _apiBase = 'https://nourelman.runasp.net';
const List<String> _arabicMonths = [
  'يناير','فبراير','مارس','أبريل','مايو','يونيو',
  'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر',
];

class StudentPaymentScreen extends StatefulWidget {
  const StudentPaymentScreen({Key? key}) : super(key: key);

  @override
  State<StudentPaymentScreen> createState() => _StudentPaymentScreenState();
}

class _StudentPaymentScreenState extends State<StudentPaymentScreen> {
  List<Map<String, dynamic>> _payments  = [];
  List<Map<String, dynamic>> _students  = [];
  List<Map<String, dynamic>> _filtered  = [];
  bool   _isLoading       = true;
  String _currentUserName = '---';
  String _searchQuery     = '';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl  = TextEditingController();
  static const double _tableWidth = 580.0;
  final ScrollController _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hScroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchCurrentUser();
    await Future.wait([_fetchPayments(), _fetchStudents()]);
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) return;
      final res = await http.get(
          Uri.parse('$_apiBase/api/Employee/GetById?id=$userId'));
      if (res.statusCode == 200) {
        final name = jsonDecode(res.body)['data']?['name'];
        if (name != null && mounted) setState(() => _currentUserName = name);
      }
    } catch (e) { debugPrint(' fetchCurrentUser: $e'); }
  }

  Future<void> _fetchPayments() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = await http.get(
          Uri.parse('$_apiBase/api/StudentPayment/Getall'));
      debugPrint('📥 StudentPayment: ${res.statusCode}');
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body)['data'] ?? [];
        final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) setState(() { _payments = list; _applySearch(); });
      }
    } catch (e) { debugPrint(' fetchPayments: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchStudents() async {
    try {
      final res = await http.get(
          Uri.parse('$_apiBase/api/Student/Getall'));
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body)['data'] ?? [];
        if (mounted) setState(() =>
        _students = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (e) { debugPrint(' fetchStudents: $e'); }
  }

  Future<void> _addPayment(int studentId, int month, double value) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final res = await http.post(
        Uri.parse('$_apiBase/api/StudentPayment/Save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId' : studentId,
          'month'     : month.toString(),
          'value'     : value,
          'createdBy' : _currentUserName,
          'createdDate': now,
        }),
      );
      debugPrint('📥 Save: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchPayments();
        if (mounted) _showSnack('تمت الإضافة بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل الإضافة: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint(' add: $e'); }
  }

  Future<void> _updatePayment(Map<String, dynamic> item,
      int studentId, int month, double value) async {
    try {
      final res = await http.put(
        Uri.parse('$_apiBase/api/StudentPayment/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id'        : int.parse(item['id'].toString()),
          'studentId' : studentId,
          'month'     : month.toString(),
          'value'     : value,
          'createdBy' : item['createdBy'] ?? _currentUserName,
          'createdDate': item['createdDate'],
        }),
      );
      debugPrint('📥 Update: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        await _fetchPayments();
        if (mounted) _showSnack('تم التعديل بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل التعديل: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint(' update: $e'); }
  }

  void _applySearch() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_payments);
    } else {
      _filtered = _payments.where((p) {
        final stuName = _getStudentName(p).toLowerCase();
        final month   = _getMonthName(p['month']).toLowerCase();
        final value   = '${p['value'] ?? ''}'.toLowerCase();
        return stuName.contains(q) || month.contains(q) || value.contains(q);
      }).toList();
    }
  }

  String _getStudentName(Map<String, dynamic> p) {
    final stu = p['student'];
    if (stu != null && stu is Map) return stu['name']?.toString() ?? '---';
    final sid = p['studentId'];
    if (sid != null) {
      for (final s in _students) {
        if (s['id'].toString() == sid.toString()) return s['name'] ?? '---';
      }
    }
    return '---';
  }

  String _getMonthName(dynamic m) {
    if (m == null) return '---';
    final idx = int.tryParse(m.toString());
    if (idx == null || idx < 1 || idx > 12) return m.toString();
    return _arabicMonths[idx - 1];
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: color,
    ));
  }


  void _showAddDialog() {
    final valueCtrl = TextEditingController();
    int? selectedStudentId;
    int? selectedMonth;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor : Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('إضافة مدفوعات طالب',
                style: TextStyle(color: _spDark,
                    fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _fieldLabel('الطالب *'),
                _studentDropdown(selectedStudentId,
                        (v) => setDlg(() => selectedStudentId = v)),
                const SizedBox(height: 12),
                _fieldLabel('الشهر *'),
                _monthDropdown(selectedMonth,
                        (v) => setDlg(() => selectedMonth = v)),
                const SizedBox(height: 12),
                _fieldLabel('المبلغ *'),
                _inputField(valueCtrl, isNumber: true),
              ]),
            ),
            actions: [_dialogActions(
              onConfirm: () {
                final val = double.tryParse(valueCtrl.text.trim());
                if (selectedStudentId != null && selectedMonth != null && val != null) {
                  Navigator.pop(ctx);
                  _addPayment(selectedStudentId!, selectedMonth!, val);
                }
              },
              confirmLabel: 'إضافة',
              onCancel: () => Navigator.pop(ctx),
            )],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final valueCtrl = TextEditingController(
        text: item['value']?.toString() ?? '');
    int? selectedStudentId = item['studentId'] != null
        ? int.tryParse(item['studentId'].toString()) : null;
    int? selectedMonth = item['month'] != null
        ? int.tryParse(item['month'].toString()) : null;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor : Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('تعديل مدفوعات طالب',
                style: TextStyle(color: _spDark,
                    fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _fieldLabel('الطالب *'),
                _studentDropdown(selectedStudentId,
                        (v) => setDlg(() => selectedStudentId = v)),
                const SizedBox(height: 12),
                _fieldLabel('الشهر *'),
                _monthDropdown(selectedMonth,
                        (v) => setDlg(() => selectedMonth = v)),
                const SizedBox(height: 12),
                _fieldLabel('المبلغ *'),
                _inputField(valueCtrl, isNumber: true),
              ]),
            ),
            actions: [_dialogActions(
              onConfirm: () {
                final val = double.tryParse(valueCtrl.text.trim());
                if (selectedStudentId != null && selectedMonth != null && val != null) {
                  Navigator.pop(ctx);
                  _updatePayment(item, selectedStudentId!, selectedMonth!, val);
                }
              },
              confirmLabel: 'تعديل',
              onCancel: () => Navigator.pop(ctx),
            )],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(label, style: const TextStyle(
          color: _spGrey, fontSize: 13, fontFamily: 'Almarai')),
    ),
  );

  Widget _inputField(TextEditingController ctrl, {bool isNumber = false}) =>
      TextField(
        controller  : ctrl,
        textAlign   : TextAlign.start,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style       : const TextStyle(fontFamily: 'Almarai'),
        decoration  : _inputDeco(),
      );

  Widget _studentDropdown(int? value, ValueChanged<int?> onChanged) =>
      _SearchableStudentPicker(
        students : _students,
        value    : value,
        onChanged: onChanged,
        inputDeco: _inputDeco(),
      );

  Widget _monthDropdown(int? value, ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
        value     : value,
        decoration: _inputDeco(),
        hint: const Text('اختر الشهر',
            style: TextStyle(fontFamily: 'Almarai')),
        items: List.generate(12, (i) => DropdownMenuItem<int>(
          value: i + 1,
          child: Text(_arabicMonths[i],
              style: const TextStyle(fontFamily: 'Almarai')),
        )),
        onChanged: onChanged,
      );

  InputDecoration _inputDeco() => InputDecoration(
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _spBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _spBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _spBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Widget _dialogActions({
    required VoidCallback onConfirm,
    required String confirmLabel,
    required VoidCallback onCancel,
    Color? confirmColor,
    Color? cancelColor,
  }) =>
      Row(children: [
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0),
          onPressed: onConfirm,
          child: Text(confirmLabel, style: const TextStyle(
              color: Colors.white, fontFamily: 'Almarai')),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: cancelColor ?? Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0),
          onPressed: onCancel,
          child: const Text('إلغاء', style: TextStyle(
              color: Colors.white, fontFamily: 'Almarai')),
        )),
      ]);


  Widget _buildHeader() {
    final s = TextStyle(color: _spDark,
        fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 12);
    return Container(
      width: _tableWidth,
      color  : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        SizedBox(width: 36,  child: Text('#',         style: s, textAlign: TextAlign.center)),
        SizedBox(width: 110, child: Text('الطالب',    style: s, textAlign: TextAlign.center)),
        SizedBox(width: 90,  child: Text('الشهر',     style: s, textAlign: TextAlign.center)),
        SizedBox(width: 80,  child: Text('القيمة',    style: s, textAlign: TextAlign.center)),
        Expanded(            child: Text('تعديل', style: s, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _buildDataRow(int index, Map<String, dynamic> item) {
    final main = TextStyle(color: _spDark,   fontFamily: 'Almarai', fontSize: 12);
    const sub  = TextStyle(color: _spGrey,   fontFamily: 'Almarai', fontSize: 12);

    return Container(
      width: _tableWidth,
      color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        SizedBox(width: 36,  child: Text('${index + 1}',
            style: main, textAlign: TextAlign.center)),
        SizedBox(width: 110, child: Text(_getStudentName(item),
            style: sub,  textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis)),
        SizedBox(width: 90,  child: Text(_getMonthName(item['month']),
            style: sub,  textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis)),
        SizedBox(width: 80,  child: Text('${item['value'] ?? '---'}',
            style: main, textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis)),
        Expanded(child: Center(child: IconButton(
          icon      : Icon(Icons.edit_outlined, color: _spOrange, size: 18),
          onPressed : () => _showEditDialog(item),
          padding   : EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ))),
      ]),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontFamily: 'Almarai', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'بحث عن طالب...',
                    hintStyle: const TextStyle(
                        fontFamily: 'Almarai', color: _spGrey, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: _spGrey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close, color: _spGrey, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _searchQuery = ''; _applySearch(); });
                      },
                    ) : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _spBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _spBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _spBlue)),
                  ),
                  onChanged: (v) =>
                      setState(() { _searchQuery = v; _applySearch(); }),
                ),
              ),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color       : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border      : Border.all(color: _spBorder),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(
                      color: _spBlue))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hScroll,
                      child: SizedBox(
                        width: _tableWidth,
                        child: Column(children: [
                          _buildHeader(),
                          const Divider(height: 1, color: _spBorder),
                          Expanded(
                            child: _filtered.isEmpty
                                ? RefreshIndicator(
                              color    : _spOrange,
                              onRefresh: _fetchPayments,
                              child    : ListView(children: const [
                                SizedBox(height: 100),
                                Center(child: Text('لا توجد بيانات',
                                    style: TextStyle(color: Colors.grey,
                                        fontFamily: 'Almarai'))),
                              ]),
                            )
                                : RefreshIndicator(
                              color    : _spOrange,
                              onRefresh: _fetchPayments,
                              child    : Scrollbar(
                                controller     : _scrollController,
                                thumbVisibility: true,
                                child: ListView.separated(
                                  controller      : _scrollController,
                                  padding         : EdgeInsets.zero,
                                  itemCount       : _filtered.length,
                                  separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: _spBorder),
                                  itemBuilder: (ctx, i) =>
                                      _buildDataRow(i, _filtered[i]),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 88, left: 24,
          child: SizedBox(
            width: 60, height: 60,
            child: ElevatedButton(
              onPressed: _showAddDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _spOrange,
                elevation      : 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 34),
            ),
          ),
        ),
      ]),
    );
  }
}
class _SearchableStudentPicker extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final int?                       value;
  final ValueChanged<int?>         onChanged;
  final InputDecoration            inputDeco;

  const _SearchableStudentPicker({
    required this.students,
    required this.value,
    required this.onChanged,
    required this.inputDeco,
  });

  @override
  State<_SearchableStudentPicker> createState() =>
      _SearchableStudentPickerState();
}

class _SearchableStudentPickerState extends State<_SearchableStudentPicker> {
  String _selectedName = '';

  String _nameOf(int? id) {
    if (id == null) return '';
    for (final s in widget.students) {
      if (s['id'].toString() == id.toString()) return s['name'] ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _selectedName = _nameOf(widget.value);
  }

  void _openPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentSearchSheet(students: widget.students),
    );
    if (result != null) {
      setState(() => _selectedName = result['name'] ?? '');
      widget.onChanged(int.tryParse(result['id'].toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openPicker,
      child: InputDecorator(
        decoration: widget.inputDeco.copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down, color: _spGrey),
        ),
        child: Text(
          _selectedName.isEmpty ? 'اختر الطالب' : _selectedName,
          style: TextStyle(
            fontFamily: 'Almarai',
            fontSize: 14,
            color: _selectedName.isEmpty ? _spGrey : _spDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}


class _StudentSearchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  const _StudentSearchSheet({required this.students});

  @override
  State<_StudentSearchSheet> createState() => _StudentSearchSheetState();
}

class _StudentSearchSheetState extends State<_StudentSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.students;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? widget.students
          : widget.students.where((s) =>
          (s['name'] ?? '').toString().toLowerCase()
              .contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.person_search_outlined,
                      color: _spBlue, size: 20),
                  const SizedBox(width: 8),
                  Text('اختر الطالب',
                      style: TextStyle(
                          color: _spDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Almarai')),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: _spGrey),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _ctrl,
                autofocus : true,
                style: const TextStyle(fontFamily: 'Almarai', fontSize: 14),
                decoration: InputDecoration(
                  hintText : 'ابحث باسم الطالب...',
                  hintStyle: const TextStyle(
                      fontFamily: 'Almarai', color: _spGrey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: _spGrey, size: 20),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: _spGrey),
                    onPressed: () { _ctrl.clear(); _filter(''); },
                  ) : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _spBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _spBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _spBlue)),
                ),
                onChanged: _filter,
              ),
            ),
            const Divider(height: 1, color: _spBorder),
            // ── قائمة ──
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: _filtered.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد نتائج',
                    style: TextStyle(
                        color: _spGrey, fontFamily: 'Almarai')),
              )
                  : ListView.separated(
                shrinkWrap: true,
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1, color: _spBorder),
                itemBuilder: (_, i) {
                  final s = _filtered[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: _spBlue.withOpacity(0.12),
                      child: Text(
                        (s['name'] ?? '?')[0],
                        style: const TextStyle(
                            color: _spBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Almarai'),
                      ),
                    ),
                    title: Text(s['name'] ?? '',
                        style: TextStyle(
                            color: _spDark,
                            fontFamily: 'Almarai',
                            fontSize: 14)),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}