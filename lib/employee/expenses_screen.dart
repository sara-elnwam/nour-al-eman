import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const Color kActiveBlue  = Color(0xFF1976D2);
const Color kLabelGrey   = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);
final Color primaryOrange = const Color(0xFFC66422);
final Color darkBlue      = const Color(0xFF2E3542);

const String _apiBase = 'https://nour-al-eman.runasp.net';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({Key? key}) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses      = [];
  List<Map<String, dynamic>> _facilityTypes = [];
  bool   _isLoading       = true;
  String _currentUserName = '---';
  final ScrollController _scrollController   = ScrollController();
  final ScrollController _hScrollController  = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchCurrentUser();
    await Future.wait([_fetchExpenses(), _fetchFacilityTypes()]);
  }

  // ── API ───────────────────────────────────────────────────

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
    } catch (e) { debugPrint('❌ fetchCurrentUser: $e'); }
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
          Uri.parse('$_apiBase/api/FacilityPayment/Getall'));
      debugPrint('📥 FacilityPayment status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List raw = decoded['data'] ?? [];
        // ✅ cast صريح لكل عنصر عشان facilityType يتقرأ صح
        setState(() => _expenses = raw.map((e) =>
        Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (e) {
      debugPrint('❌ fetchExpenses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFacilityTypes() async {
    try {
      final res = await http.get(
          Uri.parse('$_apiBase/api/FacilityTypes/Getall'));
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body)['data'] ?? [];
        setState(() => _facilityTypes = raw.map((e) =>
        Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (e) { debugPrint('❌ fetchFacilityTypes: $e'); }
  }

  Future<void> _addExpense(int facilityTypeId, double value) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final res = await http.post(
        Uri.parse('$_apiBase/api/FacilityPayment/Save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'facilityTypeId': facilityTypeId,
          'value'         : value,
          'createdBy'     : _currentUserName,
          'createdDate'   : now,
        }),
      );
      debugPrint('📥 Save: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchExpenses();
        if (mounted) _showSnack('تمت الإضافة بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل الإضافة: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint('❌ add: $e'); }
  }

  Future<void> _updateExpense(Map<String, dynamic> item,
      int facilityTypeId, double value) async {
    try {
      final res = await http.put(
        Uri.parse('$_apiBase/api/FacilityPayment/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id'            : int.parse(item['id'].toString()),
          'facilityTypeId': facilityTypeId,
          'value'         : value,
          'createdBy'     : _extractStr(item['createdBy']) ?? _currentUserName,
          'createdDate'   : item['createdDate'] ?? item['createdAt'] ?? item['date'],
        }),
      );
      debugPrint('📥 Update: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        await _fetchExpenses();
        if (mounted) _showSnack('تم التعديل بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل التعديل: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint('❌ update: $e'); }
  }

  Future<void> _deleteExpense(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/FacilityPayment/Delete?id=$id'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('📥 Delete: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        await _fetchExpenses();
        if (mounted) _showSnack('تم الحذف بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل الحذف: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint('❌ delete: $e'); }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: color,
    ));
  }

  // ── Helpers ───────────────────────────────────────────────

  // ✅ استخراج String من أي نوع
  String? _extractStr(dynamic v) {
    if (v == null) return null;
    if (v is String) return v.isNotEmpty ? v : null;
    if (v is Map)    return v['name']?.toString();
    return v.toString();
  }

  // ✅ استخراج اسم النوع من facilityType object أو من القائمة
  String _getTypeName(Map<String, dynamic> item) {
    // أولاً: من facilityType object مباشرةً
    final ft = item['facilityType'];
    if (ft != null) {
      final name = (ft as Map)['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    // ثانياً: من القائمة باستخدام facilityTypeId
    final rawId = item['facilityTypeId'];
    if (rawId != null) {
      for (final t in _facilityTypes) {
        if (t['id'].toString() == rawId.toString()) {
          return t['name']?.toString() ?? '---';
        }
      }
    }
    return '---';
  }

  String _formatDate(String? s) {
    if (s == null) return '---';
    try {
      final dt = DateTime.parse(s);
      const mo = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      const dy = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return '${dy[dt.weekday-1]} ${mo[dt.month-1]} ${dt.day} ${dt.year}';
    } catch (_) { return s.length >= 10 ? s.substring(0, 10) : s; }
  }

  // ── Dialogs ───────────────────────────────────────────────

  void _showAddDialog() {
    final valueCtrl = TextEditingController();
    int? selectedTypeId;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor : Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('إضافة مصروف',
                style: TextStyle(color: darkBlue,
                    fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('نوع المدفوعات*'),
                  _typeDropdown(selectedTypeId,
                          (v) => setDlg(() => selectedTypeId = v)),
                  const SizedBox(height: 12),
                  _fieldLabel('المبلغ*'),
                  _inputField(valueCtrl, isNumber: true),
                ],
              ),
            ),
            actions: [_dialogActions(
              onConfirm: () {
                final val = double.tryParse(valueCtrl.text.trim());
                if (selectedTypeId != null && val != null) {
                  Navigator.pop(ctx);
                  _addExpense(selectedTypeId!, val);
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
    int? selectedTypeId;
    final rawId = item['facilityTypeId'] ??
        (item['facilityType'] as Map?)?['id'];
    if (rawId != null) selectedTypeId = int.tryParse(rawId.toString());

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor : Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('تعديل مصروف',
                style: TextStyle(color: darkBlue,
                    fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('نوع المدفوعات*'),
                  _typeDropdown(selectedTypeId,
                          (v) => setDlg(() => selectedTypeId = v)),
                  const SizedBox(height: 12),
                  _fieldLabel('المبلغ*'),
                  _inputField(valueCtrl, isNumber: true),
                ],
              ),
            ),
            actions: [_dialogActions(
              onConfirm: () {
                final val = double.tryParse(valueCtrl.text.trim());
                if (selectedTypeId != null && val != null) {
                  Navigator.pop(ctx);
                  _updateExpense(item, selectedTypeId!, val);
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

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: AlertDialog(
          backgroundColor : Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Text('تأكيد الحذف!', textAlign: TextAlign.center,
              style: TextStyle(color: primaryOrange,
                  fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          actions: [_dialogActions(
            onConfirm   : () { Navigator.pop(ctx); _deleteExpense(id); },
            confirmLabel: 'تاكيد',
            onCancel    : () => Navigator.pop(ctx),
            confirmColor: primaryOrange,
            cancelColor : primaryOrange,
          )],
        ),
      ),
    );
  }

  // ── Dialog widgets ────────────────────────────────────────

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(label, style: const TextStyle(
          color: kLabelGrey, fontSize: 13, fontFamily: 'Almarai')),
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

  Widget _typeDropdown(int? value, ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
        value    : value,
        decoration: _inputDeco(),
        hint: const Text('اختر النوع',
            style: TextStyle(fontFamily: 'Almarai')),
        items: _facilityTypes.map((t) => DropdownMenuItem<int>(
          value: int.parse(t['id'].toString()),
          child: Text(t['name'] ?? '',
              style: const TextStyle(fontFamily: 'Almarai')),
        )).toList(),
        onChanged: onChanged,
      );

  InputDecoration _inputDeco() => InputDecoration(
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderColor)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorderColor)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kActiveBlue)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0),
          onPressed: onConfirm,
          child: Text(confirmLabel, style: const TextStyle(
              color: Colors.white, fontFamily: 'Almarai')),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: cancelColor ?? Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0),
          onPressed: onCancel,
          child: const Text('إلغاء', style: TextStyle(
              color: Colors.white, fontFamily: 'Almarai')),
        )),
      ]);

  // ── Table ─────────────────────────────────────────────────

  // الهيدر: # | النوع | التاريخ | بواسطة | القيمة | تعديل | حذف
  // عرض ثابت للجدول يسمح بالسكرول الأفقي
  static const double _tableWidth = 580.0;

  Widget _buildHeader() {
    final s = TextStyle(color: darkBlue,
        fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 12);
    return Container(
      width: _tableWidth,
      color  : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child  : Row(children: [
        SizedBox(width: 40,  child: Text('#',       style: s, textAlign: TextAlign.center)),
        SizedBox(width: 80,  child: Text('النوع',   style: s, textAlign: TextAlign.center)),
        SizedBox(width: 130, child: Text('التاريخ', style: s, textAlign: TextAlign.center)),
        SizedBox(width: 100, child: Text('بواسطة',  style: s, textAlign: TextAlign.center)),
        SizedBox(width: 80,  child: Text('القيمة',  style: s, textAlign: TextAlign.center)),
        SizedBox(width: 50,  child: Text('تعديل',   style: s, textAlign: TextAlign.center)),
        SizedBox(width: 50,  child: Text('حذف',     style: s, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _buildDataRow(int index, Map<String, dynamic> item) {
    final main = TextStyle(color: darkBlue,   fontFamily: 'Almarai', fontSize: 12);
    const sub  = TextStyle(color: kLabelGrey, fontFamily: 'Almarai', fontSize: 12);

    return Container(
      width: _tableWidth,
      color  : index.isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child  : Row(children: [
        SizedBox(width: 40,  child: Text('${index + 1}',
            style: main, textAlign: TextAlign.center)),
        SizedBox(width: 80,  child: Text(_getTypeName(item),
            style: sub,  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 130, child: Text(
            _formatDate(item['createdDate'] ?? item['createdAt']),
            style: sub,  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 100, child: Text(
            _extractStr(item['createdBy']) ?? '---',
            style: sub,  textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 80,  child: Text(
            '${item['value'] ?? '---'}',
            style: main, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 50, child: Center(child: IconButton(
          icon      : Icon(Icons.edit_outlined, color: primaryOrange, size: 18),
          onPressed : () => _showEditDialog(item),
          padding   : EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ))),
        SizedBox(width: 50, child: Center(child: IconButton(
          icon      : const Icon(Icons.delete_outline,
              color: Colors.redAccent, size: 18),
          onPressed : () =>
              _showDeleteDialog(int.parse(item['id'].toString())),
          padding   : EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ))),
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color       : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border      : Border.all(color: kBorderColor),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(
                      color: kActiveBlue))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hScrollController,
                      child: SizedBox(
                        width: _tableWidth,
                        child: Column(children: [
                          _buildHeader(),
                          const Divider(height: 1, color: kBorderColor),
                          Expanded(
                            child: _expenses.isEmpty
                                ? RefreshIndicator(
                              color    : primaryOrange,
                              onRefresh: _fetchExpenses,
                              child    : ListView(children: const [
                                SizedBox(height: 100),
                                Center(child: Text('لا توجد بيانات',
                                    style: TextStyle(color: Colors.grey,
                                        fontFamily: 'Almarai'))),
                              ]),
                            )
                                : RefreshIndicator(
                              color    : primaryOrange,
                              onRefresh: _fetchExpenses,
                              child    : Scrollbar(
                                controller     : _scrollController,
                                thumbVisibility: true,
                                child: ListView.separated(
                                  controller      : _scrollController,
                                  padding         : EdgeInsets.zero,
                                  itemCount       : _expenses.length,
                                  separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: kBorderColor),
                                  itemBuilder: (ctx, i) =>
                                      _buildDataRow(i, _expenses[i]),
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

        // ── زر الإضافة ──
        Positioned(
          bottom: 88, left: 24,
          child: SizedBox(
            width: 60, height: 60,
            child: ElevatedButton(
              onPressed: _showAddDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
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