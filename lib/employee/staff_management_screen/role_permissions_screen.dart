import 'package:flutter/material.dart';

class RolePermissionsScreen extends StatefulWidget {
  final String roleName;

  const RolePermissionsScreen({Key? key, required this.roleName}) : super(key: key);

  @override
  _RolePermissionsScreenState createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends State<RolePermissionsScreen> {
  final List<String> sections = [
    "البصمة",
    "الطلاب",
    "المعلمون",
    "الموظفون",
    "المستويات والمجموعات",
    "الفروع",
    "الدورات",
    "قائمة الانتظار",
    "استخراج شهادات تقدير",
    "إدارة الموظفين"
  ];
  final List<String> actions = [
    "حذف طالب",
    "تعديل طالب",
    "حذف معلم",
    "تعديل معلم",
    "حذف موظف",
    "تعديل موظف",
    "حذف مستوى",
    "تعديل مستوى",
    "إضافة مستوى",
    "حذف فرع",
    "تعديل فرع",
    "إضافة فرع",
    "حذف دورة",
    "تعديل دورة",
    "إضافة دورة",
    "حذف صلاحية",
    "تعديل صلاحية",
    "إضافة صلاحية"
  ];
  Map<String, bool> sectionPermissions = {};
  Map<String, bool> actionPermissions = {};

  @override
  void initState() {
    super.initState();
    for (var sec in sections) {
      sectionPermissions[sec] = false;
    }
    for (var act in actions) {
      actionPermissions[act] = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              "صلاحيات ${widget.roleName}",
              style: const TextStyle(fontFamily: 'Almarai', fontSize: 18, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            bottom: const TabBar(
              indicatorColor: Color(0xFFC66422),
              labelColor: Color(0xFFC66422),
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "صلاحيات الوصول"),
                Tab(text: "صلاحيات الإجراءات"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildPermissionsList(sectionPermissions),
              _buildPermissionsList(actionPermissions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionsList(Map<String, bool> data) {
    final keys = data.keys.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, index) {
        String key = keys[index];
        return CheckboxListTile(
          title: Text(
            key,
            style: const TextStyle(fontFamily: 'Almarai', fontSize: 15),
          ),
          value: data[key],
          activeColor: const Color(0xFFC66422),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (bool? value) {
            setState(() {
              data[key] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.trailing,
        );
      },
    );
  }
}