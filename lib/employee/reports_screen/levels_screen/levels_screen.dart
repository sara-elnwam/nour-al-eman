import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'level_one_screen.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  List<dynamic> _levels = [];
  bool _isLoading = true;

  static const Color kActiveBlue = Color(0xFF1976D2);
  static const Color darkBlue = Color(0xFF2E3542);
  static const Color orangeButton = Color(0xFFC66422);
  static const Color kPrimaryBlue = Color(0xFF07427C);

  @override
  void initState() {
    super.initState();
    _fetchLevels();
  }

  Future<void> _fetchLevels() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Level/Getall'),
      );
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _levels = decodedData['data'] is List ? decodedData['data'] : [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addLevelApi(String name) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك أدخل اسم المستوى"), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://nour-al-eman.runasp.net/api/Level/Save'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name.trim(), "active": true}),
      );
      debugPrint("Add Level Response (${response.statusCode}): ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم إضافة المستوى بنجاح ✅"), backgroundColor: Colors.green),
          );
          _fetchLevels();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل الإضافة: ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Add Level Error: $e");
    }
  }

  void _showAddLevelDialog() {
    TextEditingController nameCont = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("إضافة مستوى جديد",
              style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          content: TextField(
            controller: nameCont,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "اسم المستوى",
              hintStyle: const TextStyle(fontFamily: 'Almarai'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _addLevelApi(nameCont.text);
              },
              style: ElevatedButton.styleFrom(backgroundColor: orangeButton),
              child: const Text("إضافة", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_levels_main_unique",
        onPressed: _showAddLevelDialog,
        backgroundColor: orangeButton,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "إدارة المستويات",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Almarai',
                  color: darkBlue),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: orangeButton))
                  : _levels.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("لا توجد مستويات مضافة بعد",
                        style: TextStyle(fontFamily: 'Almarai')),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchLevels,
                      icon: const Icon(Icons.refresh),
                      label: const Text("تحديث", style: TextStyle(fontFamily: 'Almarai')),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _fetchLevels,
                child: ListView.builder(
                  itemCount: _levels.length,
                  itemBuilder: (context, index) {
                    return _buildLevelCard(
                      context,
                      _levels[index]["name"] ?? "مستوى غير مسمى",
                      kActiveBlue,
                      darkBlue,
                      _levels[index]["id"],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, String title, Color primary, Color textCol, int id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LevelOneScreen(levelId: id, levelName: title),
            ),
          ).then((_) => _fetchLevels());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.layers_outlined, color: primary, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Almarai',
                          color: textCol))),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}