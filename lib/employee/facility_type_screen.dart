import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const Color kActiveBlue = Color(0xFF1976D2);
const Color kLabelGrey = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);
final Color primaryOrange = const Color(0xFFC66422);
final Color darkBlue = const Color(0xFF2E3542);

const String _apiBase = 'https://nourelman.runasp.net';

const int _fNum    = 1;
const int _fName   = 3;
const int _fBy     = 3;
const int _fEdit   = 2;
const int _fDelete = 1;
const double _kScrollbarW = 8.0;

class FacilityTypeScreen extends StatefulWidget {
  const FacilityTypeScreen({Key? key}) : super(key: key);

  @override
  State<FacilityTypeScreen> createState() => _FacilityTypeScreenState();
}

class _FacilityTypeScreenState extends State<FacilityTypeScreen> {
  List<Map<String, dynamic>> _facilityTypes = [];
  bool _isLoading = true;
  String _currentUserName = '---';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _fetchCurrentUser();
    await _fetchFacilityTypes();
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) return;
      final response = await http.get(
        Uri.parse('$_apiBase/api/Employee/GetById?id=$userId'),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final name = decoded['data']?['name'];
        if (name != null && mounted) setState(() => _currentUserName = name);
      }
    } catch (e) {
      debugPrint('fetchCurrentUser: $e');
    }
  }

  Future<void> _fetchFacilityTypes() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_apiBase/api/FacilityTypes/Getall'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List data = decoded['data'] ?? [];
        setState(() => _facilityTypes = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('fetchFacilityTypes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFacilityType(String name) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await http.post(
        Uri.parse('$_apiBase/api/FacilityTypes/Save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'createdBy': _currentUserName,
          'createdDate': now,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchFacilityTypes();
        if (mounted) _showSnack('تمت الإضافة بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل الإضافة: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      debugPrint('❌ add: $e');
    }
  }

  Future<void> _updateFacilityType(Map<String, dynamic> item, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('$_apiBase/api/FacilityTypes/Update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': int.parse(item['id'].toString()),
          'name': newName,
          'createdBy': _extractCreatedBy(item['createdBy']),
          'createdDate': item['createdAt'] ?? item['createdDate'] ?? item['date'],
        }),
      );
      if (response.statusCode == 200) {
        await _fetchFacilityTypes();
        if (mounted) _showSnack('تم التعديل بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل التعديل: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      debugPrint('update: $e');
    }
  }

  Future<void> _deleteFacilityType(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/api/FacilityTypes/Delete?id=$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        await _fetchFacilityTypes();
        if (mounted) _showSnack('تم الحذف بنجاح', Colors.green);
      } else {
        if (mounted) _showSnack('فشل الحذف: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      debugPrint('delete: $e');
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: color,
      ),
    );
  }

  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'إضافة نوع مصروفات',
            style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
          content: _buildDialogField(ctrl, 'نوع المصروفات*'),
          actions: [
            _dialogActions(
              onConfirm: () {
                if (ctrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _addFacilityType(ctrl.text.trim());
                }
              },
              confirmLabel: 'إضافة',
              onCancel: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final ctrl = TextEditingController(text: item['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'تعديل نوع مصروفات',
            style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
          content: _buildDialogField(ctrl, 'نوع المصروفات*'),
          actions: [
            _dialogActions(
              onConfirm: () {
                if (ctrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _updateFacilityType(item, ctrl.text.trim());
                }
              },
              confirmLabel: 'تعديل',
              onCancel: () => Navigator.pop(ctx),
            ),
          ],
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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'تأكيد الحذف!',
            textAlign: TextAlign.center,
            style: TextStyle(color: primaryOrange, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
          actions: [
            _dialogActions(
              onConfirm: () {
                Navigator.pop(ctx);
                _deleteFacilityType(id);
              },
              confirmLabel: 'تاكيد',
              onCancel: () => Navigator.pop(ctx),
              confirmColor: primaryOrange,
              cancelColor: primaryOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            style: const TextStyle(color: kLabelGrey, fontSize: 13, fontFamily: 'Almarai'),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          textAlign: TextAlign.start,
          style: const TextStyle(fontFamily: 'Almarai'),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kActiveBlue),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _dialogActions({
    required VoidCallback onConfirm,
    required String confirmLabel,
    required VoidCallback onCancel,
    Color? confirmColor,
    Color? cancelColor,
  }) {
    return Row(children: [
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: onConfirm,
          child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontFamily: 'Almarai')),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cancelColor ?? Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: onCancel,
          child: const Text('إلغاء', style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
        ),
      ),
    ]);
  }


  String _extractCreatedBy(dynamic v) {
    if (v == null) return '---';
    if (v is String) return v.isNotEmpty ? v : '---';
    if (v is Map) return v['name']?.toString() ?? '---';
    return '---';
  }
  Widget _buildRowWidget({
    required String num,
    required String name,
    required String by,
    required Widget editBtn,
    required Widget deleteBtn,
    bool isHeader = false,
  }) {
    final baseStyle = TextStyle(
      color: darkBlue,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'Almarai',
      fontSize: 13,
    );
    final subStyle = isHeader
        ? baseStyle
        : const TextStyle(color: kLabelGrey, fontFamily: 'Almarai', fontSize: 13);

    return Row(children: [
      Expanded(flex: _fNum,    child: Text(num,  style: baseStyle, textAlign: TextAlign.center)),
      Expanded(flex: _fName,   child: Text(name, style: baseStyle, overflow: TextOverflow.ellipsis)),
      Expanded(flex: _fBy,     child: Text(by,   style: subStyle,  overflow: TextOverflow.ellipsis)),
      Expanded(flex: _fEdit,   child: Center(child: editBtn)),
      Expanded(flex: _fDelete, child: Center(child: deleteBtn)),
    ]);
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.only(right: 16, left: 16 + _kScrollbarW, top: 12, bottom: 12),
      child: _buildRowWidget(
        num: '#',
        name: 'الاسم',
        by: 'بواسطة',
        editBtn: Text(
          'تعديل',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 13),
        ),
        deleteBtn: Text(
          'حذف',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 13),
        ),
        isHeader: true,
      ),
    );
  }

  Widget _buildDataRow(int index, Map<String, dynamic> item) {
    return Container(
      color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: _buildRowWidget(
        num:  '${index + 1}',
        name: item['name'] ?? '---',
        by:   _extractCreatedBy(item['createdBy']),
        editBtn: IconButton(
          icon: Icon(Icons.edit_outlined, color: primaryOrange, size: 18),
          onPressed: () => _showEditDialog(item),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        deleteBtn: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
          onPressed: () => _showDeleteDialog(int.parse(item['id'].toString())),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: kActiveBlue))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Column(children: [
                      _buildHeader(),
                      const Divider(height: 1, color: kBorderColor),
                      Expanded(
                        child: _facilityTypes.isEmpty
                            ? RefreshIndicator(
                          color: primaryOrange,
                          onRefresh: _fetchFacilityTypes,
                          child: ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text(
                                  'لا توجد بيانات',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                            : RefreshIndicator(
                          color: primaryOrange,
                          onRefresh: _fetchFacilityTypes,
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: _facilityTypes.length,
                              separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: kBorderColor),
                              itemBuilder: (ctx, i) =>
                                  _buildDataRow(i, _facilityTypes[i]),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 88,
          left: 24,
          child: SizedBox(
            width: 60,
            height: 60,
            child: ElevatedButton(
              onPressed: _showAddDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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