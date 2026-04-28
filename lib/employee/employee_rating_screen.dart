import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const Color _erBlue   = Color(0xFF1976D2);
const Color _erGrey   = Color(0xFF718096);
const Color _erBorder = Color(0xFFE2E8F0);
final Color _erOrange = const Color(0xFFC66422);
final Color _erDark   = const Color(0xFF2E3542);

const String _apiBase = 'https://nourelman.runasp.net';
const List<Map<String, dynamic>> _rateTypes = [
  {'id': 1, 'name': 'حافز'},
  {'id': 2, 'name': 'خصم'},
];

class EmployeeRatingScreen extends StatefulWidget {
  const EmployeeRatingScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeRatingScreen> createState() => _EmployeeRatingScreenState();
}

class _EmployeeRatingScreenState extends State<EmployeeRatingScreen> {
  List<Map<String, dynamic>> _ratings   = [];
  List<Map<String, dynamic>> _employees = [];
  bool   _isLoading       = true;
  String _currentUserName = '---';
  String _filterEmpName = '';
  int?   _filterTypeId;
  String _sortField     = 'none';
  bool   _sortAsc       = true;

  final ScrollController _scrollCtrl  = ScrollController();
  final ScrollController _hScrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  static const double _tableWidth = 556.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _hScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
  Future<void> _init() async {
    await _fetchCurrentUser();
    await Future.wait([_fetchRatings(), _fetchEmployees()]);
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

  Future<void> _fetchRatings() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = await http.get(
          Uri.parse('$_apiBase/api/EmployeeRates/Getall'));
      debugPrint('📥 EmployeeRates: ${res.statusCode}');
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body)['data'] ?? [];
        if (mounted) setState(() =>
        _ratings = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (e) { debugPrint(' fetchRatings: $e'); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchEmployees() async {
    try {
      final res = await http.get(
          Uri.parse('$_apiBase/api/Employee/GetWithType?type=2'));
      debugPrint('📥 Employees status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List raw;
        if (decoded is List) {
          raw = decoded;
        } else {
          raw = decoded['data'] ?? [];
        }
        if (mounted) setState(() =>
        _employees = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (e) { debugPrint('❌ fetchEmployees: $e'); }
  }

  Future<void> _addRating(int empId, int typeId, double value, double rate) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final body = {
        'empId'      : empId,
        'rate'       : rate.toInt(),
        'createBy'   : _currentUserName,
        'createDate' : now,
        'bonus'      : typeId == 1 ? value.toInt() : 0,
        'deduction'  : typeId == 2 ? value.toInt() : 0,
      };
      debugPrint('📤 Add body: ${jsonEncode(body)}');
      final res = await http.post(
        Uri.parse('$_apiBase/api/EmployeeRates/Save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      debugPrint('📥 Save: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchRatings();
        if (mounted) _showSnack('تمت الإضافة بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل الإضافة: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint(' addRating: $e'); }
  }

  Future<void> _updateRating(Map<String, dynamic> item,
      int empId, int typeId, double value, double rate) async {
    try {
      final body = {
        'id'         : int.parse(item['id'].toString()),
        'empId'      : empId,
        'rate'       : rate.toInt(),
        'createBy'   : _currentUserName,
        'createDate' : item['createDate'],
        'bonus'      : typeId == 1 ? value.toInt() : 0,
        'deduction'  : typeId == 2 ? value.toInt() : 0,
      };
      debugPrint('📤 Update body: ${jsonEncode(body)}');
      final res = await http.put(
        Uri.parse('$_apiBase/api/EmployeeRates/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      debugPrint(' Update: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        await _fetchRatings();
        if (mounted) _showSnack('تم التعديل بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل التعديل: ${res.statusCode}', Colors.red);
      }
    } catch (e) { debugPrint(' updateRating: $e'); }
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _getEmpName(Map<String, dynamic> item) {
    final emp = item['emp'];
    if (emp != null && emp is Map) {
      final name = emp['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    final empId = item['empId'];
    if (empId != null) {
      for (final e in _employees) {
        if (e['id'].toString() == empId.toString()) {
          return (e['name'] ?? '---').toString().trim();
        }
      }
    }
    return '---';
  }

  int _getTypeId(Map<String, dynamic> item) {
    final bonus     = int.tryParse(item['bonus']?.toString() ?? '0') ?? 0;
    final deduction = int.tryParse(item['deduction']?.toString() ?? '0') ?? 0;
    if (bonus > 0) return 1;
    if (deduction > 0) return 2;
    return 1;
  }

  String _getTypeName(Map<String, dynamic> item) =>
      _getTypeId(item) == 1 ? 'حافز' : 'خصم';

  double _getValue(Map<String, dynamic> item) {
    final bonus = int.tryParse(item['bonus']?.toString() ?? '0') ?? 0;
    if (bonus > 0) return bonus.toDouble();
    return (int.tryParse(item['deduction']?.toString() ?? '0') ?? 0).toDouble();
  }

  String _formatDate(String? s) {
    if (s == null) return '---';
    try {
      final dt = DateTime.parse(s);
      const mo = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
        'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      return '${dt.day} ${mo[dt.month - 1]} ${dt.year}';
    } catch (_) { return s.length >= 10 ? s.substring(0, 10) : s; }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: color,
    ));
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list = List.from(_ratings);
    final q = _filterEmpName.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) =>
          _getEmpName(r).toLowerCase().contains(q)).toList();
    }
    if (_filterTypeId != null) {
      list = list.where((r) => _getTypeId(r) == _filterTypeId).toList();
    }
    if (_sortField != 'none' && _sortField != 'noSort') {
      list.sort((a, b) {
        int cmp;
        switch (_sortField) {
          case 'bonus':
          case 'deduction':
            cmp = (_getValue(a)).compareTo(_getValue(b));
            break;
          case 'rate':
          default:
            final ra = int.tryParse(a['rate']?.toString() ?? '0') ?? 0;
            final rb = int.tryParse(b['rate']?.toString() ?? '0') ?? 0;
            cmp = ra.compareTo(rb);
        }
        return _sortAsc ? cmp : -cmp;
      });
    }

    return list;
  }

  void _showAddDialog() {
    final valueCtrl = TextEditingController();
    final rateCtrl  = TextEditingController();
    int? selectedEmpId;
    int? selectedTypeId;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor : Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('إضافة تقييم موظف',
                style: TextStyle(color: _erDark,
                    fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('الموظف *'),
                  _empDropdown(selectedEmpId,
                          (v) => setDlg(() => selectedEmpId = v)),
                  const SizedBox(height: 12),
                  _fieldLabel('النوع *'),
                  _typeDropdown(selectedTypeId,
                          (v) => setDlg(() => selectedTypeId = v)),
                  const SizedBox(height: 12),
                  _fieldLabel('القيمة *'),
                  _inputField(valueCtrl, isNumber: true),
                  const SizedBox(height: 12),
                  _fieldLabel('التقييم'),
                  _inputField(rateCtrl, isNumber: true),
                ],
              ),
            ),
            actions: [_dialogActions(
              onConfirm: () {
                final val  = double.tryParse(valueCtrl.text.trim()) ?? 0;
                final rate = double.tryParse(rateCtrl.text.trim()) ?? 0;
                if (selectedEmpId != null && selectedTypeId != null) {
                  Navigator.pop(ctx);
                  _addRating(selectedEmpId!, selectedTypeId!, val, rate);
                } else {
                  _showSnack('يرجى اختيار الموظف والنوع', Colors.orange);
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
    final val      = _getValue(item);
    final typeId   = _getTypeId(item);
    final empRaw   = item['empId'];
    int? selEmpId  = empRaw != null ? int.tryParse(empRaw.toString()) : null;
    int? selTypeId = typeId;

    final valueCtrl = TextEditingController(text: val.toInt().toString());
    final rateCtrl  = TextEditingController(
        text: item['rate']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            backgroundColor : Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('تعديل تقييم',
                style: TextStyle(color: _erDark,
                    fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('الموظف *'),
                  _empDropdown(selEmpId,
                          (v) => setDlg(() => selEmpId = v)),
                  const SizedBox(height: 12),
                  _fieldLabel('النوع *'),
                  _typeDropdown(selTypeId,
                          (v) => setDlg(() => selTypeId = v)),
                  const SizedBox(height: 12),
                  _fieldLabel('القيمة *'),
                  _inputField(valueCtrl, isNumber: true),
                  const SizedBox(height: 12),
                  _fieldLabel('التقييم'),
                  _inputField(rateCtrl, isNumber: true),
                ],
              ),
            ),
            actions: [_dialogActions(
              onConfirm: () {
                final v = double.tryParse(valueCtrl.text.trim()) ?? 0;
                final r = double.tryParse(rateCtrl.text.trim()) ?? 0;
                if (selEmpId != null && selTypeId != null) {
                  Navigator.pop(ctx);
                  _updateRating(item, selEmpId!, selTypeId!, v, r);
                } else {
                  _showSnack('يرجى اختيار الموظف والنوع', Colors.orange);
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
    child: Text(label, style: const TextStyle(
        color: _erGrey, fontSize: 13, fontFamily: 'Almarai')),
  );

  Widget _inputField(TextEditingController ctrl, {bool isNumber = false}) =>
      TextField(
        controller  : ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style       : const TextStyle(fontFamily: 'Almarai'),
        decoration  : _inputDeco(),
      );

  Widget _empDropdown(int? value, ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
        value     : value,
        decoration: _inputDeco(),
        isExpanded: true,
        hint: const Text('ابحث عن الموظف',
            style: TextStyle(fontFamily: 'Almarai', fontSize: 13)),
        items: _employees.map((e) => DropdownMenuItem<int>(
          value: int.parse(e['id'].toString()),
          child: Text(
            (e['name'] ?? '').toString().trim(),
            style: const TextStyle(fontFamily: 'Almarai', fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
        onChanged: onChanged,
      );

  Widget _typeDropdown(int? value, ValueChanged<int?> onChanged) =>
      DropdownButtonFormField<int>(
        value     : value,
        decoration: _inputDeco(),
        hint: const Text('اختر النوع',
            style: TextStyle(fontFamily: 'Almarai')),
        items: _rateTypes.map((t) => DropdownMenuItem<int>(
          value: t['id'] as int,
          child: Text(t['name'] as String,
              style: const TextStyle(fontFamily: 'Almarai')),
        )).toList(),
        onChanged: onChanged,
      );

  InputDecoration _inputDeco() => InputDecoration(
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _erBorder)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _erBorder)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _erBlue)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Widget _dialogActions({
    required VoidCallback onConfirm,
    required String confirmLabel,
    required VoidCallback onCancel,
    Color? confirmColor,
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
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0),
          onPressed: onCancel,
          child: const Text('إلغاء', style: TextStyle(
              color: Colors.white, fontFamily: 'Almarai')),
        )),
      ]);
  Widget _filterBox({required Widget child}) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _erBorder),
    ),
    child: child,
  );

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _filterBox(
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: _erGrey, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontFamily: 'Almarai', fontSize: 13),
                          decoration: const InputDecoration(
                            hintText : 'ابحث باسم الموظف',
                            hintStyle: TextStyle(
                                fontFamily: 'Almarai', color: _erGrey, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                          onChanged: (v) => setState(() => _filterEmpName = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _filterBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _filterTypeId,
                      isExpanded: true,
                      hint: Text('اختار النوع', style: TextStyle(
                          fontFamily: 'Almarai', fontSize: 13, color: _erDark)),
                      style: TextStyle(fontFamily: 'Almarai', fontSize: 13,
                          color: _erDark),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('الكل',
                                style: TextStyle(fontFamily: 'Almarai'))),
                        ..._rateTypes.map((t) => DropdownMenuItem<int?>(
                          value: t['id'] as int,
                          child: Text(t['name'] as String,
                              style: const TextStyle(fontFamily: 'Almarai')),
                        )),
                      ],
                      onChanged: (v) => setState(() => _filterTypeId = v),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _filterBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortField,
                      isExpanded: true,
                      style: TextStyle(fontFamily: 'Almarai', fontSize: 13,
                          color: _erDark),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      items: const [
                        DropdownMenuItem(value: 'none',
                            child: Text('اختار ترتيب', style: TextStyle(fontFamily: 'Almarai'))),
                        DropdownMenuItem(value: 'noSort',
                            child: Text('بدون ترتيب', style: TextStyle(fontFamily: 'Almarai'))),
                        DropdownMenuItem(value: 'rate',
                            child: Text('تقييم', style: TextStyle(fontFamily: 'Almarai'))),
                        DropdownMenuItem(value: 'bonus',
                            child: Text('قيمة', style: TextStyle(fontFamily: 'Almarai'))),
                      ],
                      onChanged: (v) => setState(() {
                        if (v == 'none' || v == 'noSort') {
                          _sortField = v!;
                        } else if (v == _sortField) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sortField = v!;
                          _sortAsc   = true;
                        }
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: _filterBox(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<bool>(
                      value: _sortAsc,
                      isExpanded: true,
                      style: TextStyle(fontFamily: 'Almarai', fontSize: 13,
                          color: _erDark),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      items: const [
                        DropdownMenuItem(value: true,
                            child: Text('تصاعدي',
                                style: TextStyle(fontFamily: 'Almarai'))),
                        DropdownMenuItem(value: false,
                            child: Text('تنازلي',
                                style: TextStyle(fontFamily: 'Almarai'))),
                      ],
                      onChanged: (v) => setState(() {
                        _sortAsc = v ?? true;
                        if (_sortField == 'none' || _sortField == 'noSort') {
                          _sortField = 'rate';
                        }
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildHeader() {
    final s = TextStyle(color: _erDark,
        fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 12);
    return Container(
      color : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child : Row(children: [
        SizedBox(width: 30,  child: Text('#',       style: s, textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text('الموظف',  style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('النوع',   style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('القيمة',  style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('التقييم', style: s, textAlign: TextAlign.center)),
        SizedBox(width: 48,  child: Text('تعديل',   style: s, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _buildDataRow(int index, Map<String, dynamic> item) {
    final main = TextStyle(color: _erDark,  fontFamily: 'Almarai', fontSize: 12);
    const sub  = TextStyle(color: _erGrey,  fontFamily: 'Almarai', fontSize: 12);

    final typeId   = _getTypeId(item);
    final typeName = _getTypeName(item);
    final typeColor = typeId == 1
        ? const Color(0xFF2E7D32)
        : Colors.redAccent;

    return Container(
      color : index.isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child : Row(children: [
        SizedBox(width: 30, child: Text('${index + 1}',
            style: main, textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text(_getEmpName(item),
            style: sub,  textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(typeName,
                style: TextStyle(color: typeColor,
                    fontFamily: 'Almarai', fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        )),
        Expanded(flex: 2, child: Text(
            _getValue(item).toInt().toString(),
            style: main, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text(
            item['rate']?.toString() ?? '0',
            style: main, textAlign: TextAlign.center)),
        SizedBox(width: 48, child: Center(child: IconButton(
          icon: Icon(Icons.edit_outlined, color: _erOrange, size: 18),
          onPressed: () => _showEditDialog(item),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Column(
            children: [
              _buildFilterBar(),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _erBorder),
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: _erBlue))
                        : RefreshIndicator(
                      color: _erOrange,
                      onRefresh: _fetchRatings,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Column(
                          children: [
                            _buildHeader(),
                            const Divider(height: 1, color: _erBorder),
                            Expanded(
                              child: rows.isEmpty
                                  ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  Center(child: Text('لا توجد بيانات',
                                      style: TextStyle(color: Colors.grey,
                                          fontFamily: 'Almarai'))),
                                ],
                              )
                                  : Scrollbar(
                                controller: _scrollCtrl,
                                child: ListView.separated(
                                  controller: _scrollCtrl,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: _erBorder),
                                  itemBuilder: (ctx, i) => _buildDataRow(i, rows[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 88, left: 24,
            child: SizedBox(
              width: 60, height: 60,
              child: ElevatedButton(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _erOrange,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 34),
              ),
            ),
          ),
        ],
      ),
    );
  }
}