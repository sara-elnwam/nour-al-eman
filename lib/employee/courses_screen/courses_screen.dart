import 'package:flutter/material.dart';
import 'student_courses_screen.dart';
import 'teacher_courses_screen.dart';
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kActiveBlue = Color(0xFF1976D2);
    const Color darkBlue = Color(0xFF2E3542);
    const Color kBorderColor = Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "الدورات التدريبية",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
                color: darkBlue
            ),
          ),
          const SizedBox(height: 20),

          _buildCourseRowCard(
            context,
            title: "دورات الطلاب",
            icon: Icons.school_outlined,
            primaryColor: kActiveBlue,
            textColor: darkBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentCoursesScreen()),
              );
            },
          ),

        _buildCourseRowCard(
          context,
          title: "دورات المعلمين",
          icon: Icons.assignment_ind_outlined,
          primaryColor: Colors.green,
          textColor: darkBlue,
          onTap: () {

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TeacherCoursesScreen()),
            );
          },


          ),
        ],
      ),
    );
  }

  //  WaitingListScreen
  Widget _buildCourseRowCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color primaryColor,
        required Color textColor,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Almarai',
                    color: textColor,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}