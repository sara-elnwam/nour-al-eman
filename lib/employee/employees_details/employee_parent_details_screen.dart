import 'package:flutter/material.dart';
import 'employee_details_screen.dart';
import 'edit_employee_screen.dart';
import 'specific_employee_attendance_screen.dart';

class EmployeeParentDetailsScreen extends StatefulWidget {
  final int empId;
  final String empName;

  EmployeeParentDetailsScreen({required this.empId, required this.empName});

  @override
  _EmployeeParentDetailsScreenState createState() => _EmployeeParentDetailsScreenState();
}

class _EmployeeParentDetailsScreenState extends State<EmployeeParentDetailsScreen> {
  Key _detailsKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Color(0xFF2E3542)),
            title: Text(
              widget.empName,
              style: const TextStyle(
                color: Color(0xFF2E3542),
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
                fontSize: 16,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Color(0xFF1976D2), size: 28),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditEmployeeScreen(empId: widget.empId),
                    ),
                  );
                  if (result == true) {
                    setState(() {
                      _detailsKey = UniqueKey();
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: const TabBar(
              labelColor: Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF1976D2),
              labelStyle: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "البيانات الشخصية"),
                Tab(text: "الحضور والإنصراف"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              EmployeeDetailsScreen(
                key: _detailsKey,
                empId: widget.empId,
                empName: widget.empName,
              ),
              SpecificEmployeeAttendanceScreen(
                employeeId: widget.empId.toString(),
                employeeName: widget.empName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}