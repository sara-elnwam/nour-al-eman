import 'package:flutter/material.dart';
import 'student_waiting_list_screen.dart';
import 'teacher_waiting_list_screen.dart'; // استدعاء شاشة المعلمين الجديدة
import 'employee_waiting_list_screen.dart';
class WaitingListScreen extends StatelessWidget {
  const WaitingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kActiveBlue = Color(0xFF1976D2);
    const Color darkBlue = Color(0xFF2E3542);

    final List<Map<String, dynamic>> items = [
      {'title': 'طلبات تسجيل الطلاب', 'icon': Icons.school_outlined},
      {'title': 'طلبات تسجيل المعلمين', 'icon': Icons.person_search_outlined},
      {'title': 'طلبات تسجيل الموظفين', 'icon': Icons.badge_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "طلبات التسجيل",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: darkBlue),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _buildWaitingCard(context, items[index]['title'], items[index]['icon'], kActiveBlue, darkBlue);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard(BuildContext context, String title, IconData icon, Color primary, Color textCol) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
    if (title == 'طلبات تسجيل الطلاب') {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentWaitingListScreen()));
    } else if (title == 'طلبات تسجيل المعلمين') {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeacherWaitingListScreen()));
    } else if (title == 'طلبات تسجيل الموظفين') { // الجزء المضاف
    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeWaitingListScreen()));
    }
    },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: primary, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: textCol))),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}