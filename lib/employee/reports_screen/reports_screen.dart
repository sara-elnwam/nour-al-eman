import 'package:flutter/material.dart';
import 'student_reports_screen.dart';
import 'TeacherReportsScreen.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  final List<Map<String, dynamic>> reportTypes = [
    {'title': 'تقارير الطالب', 'icon': Icons.school_rounded, 'color': const Color(0xFF1976D2)},
    {'title': 'تقارير المعلم', 'icon': Icons.psychology_rounded, 'color': const Color(0xFFC66422)},
    {'title': 'تقارير الموظف', 'icon': Icons.badge_rounded, 'color': const Color(0xFF2E3542)},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animations = List.generate(reportTypes.length, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Interval(index * 0.2, 1.0, curve: Curves.easeOutBack)),
      );
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            const Text(" ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E3542), fontFamily: 'Almarai')),
            const SizedBox(height: 8),
            const Text("", style: TextStyle(color: Colors.grey, fontFamily: 'Almarai', fontSize: 15)),
            const SizedBox(height: 40),
            Expanded(
              child: ListView.separated(
                itemCount: reportTypes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _animations[index],
                    child: ScaleTransition(
                      scale: _animations[index],
                      child: _buildReportCard(reportTypes[index]['title'], reportTypes[index]['icon'], reportTypes[index]['color']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == 'تقارير الطالب') {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => StudentReportsScreen()));
        } else if (title == 'تقارير المعلم') {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => TeacherReportsScreen()));
        } else {
          Navigator.of(context).push(_createFadeRoute(title));
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(left: -20, top: -20, child: CircleAvatar(radius: 50, backgroundColor: color.withOpacity(0.03))),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
                    child: Icon(icon, color: color, size: 35),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Color(0xFF2E3542), fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
                        const SizedBox(height: 4),
                        const Text("عرض وإدارة البيانات السنوية", style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Almarai')),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Route _createFadeRoute(String title) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontFamily: 'Almarai', fontSize: 16)), centerTitle: true),
        body: Container(color: Colors.white),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
    );
  }
}