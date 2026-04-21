import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmployeeDetailsScreen extends StatefulWidget {
  final int empId;
  final String empName;

  EmployeeDetailsScreen({super.key, required this.empId, required this.empName});

  @override
  _EmployeeDetailsScreenState createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  Map<String, dynamic>? _empData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  String _formatServerDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "---";
    return dateStr.split('T')[0];
  }

  Future<void> _fetchDetails() async {
    try {
      final response = await http.get(
        Uri.parse('https://nour-al-eman.runasp.net/api/Employee/GetById?id=${widget.empId}'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _empData = jsonDecode(response.body)['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem("اسم الموظف", _empData?['name'] ?? widget.empName),
            _buildInfoItem("كود الموظف", _empData?['id']?.toString() ?? "---"),
            _buildInfoItem("المكتب التابع له", _empData?['loc']?['name'] ?? "---"),
            _buildInfoItem("موعد الالتحاق", _formatServerDate(_empData?['joinDate'])),
            _buildInfoItem("المؤهل الدراسي", _empData?['educationDegree'] ?? "---"),
            _buildInfoItem("المسمى الوظيفي", _empData?['employeeType']?['name'] ?? "---"),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, dynamic value) {
    String displayValue = (value == null || value.toString() == "null" || value.toString().isEmpty)
        ? "---"
        : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2E3542),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Almarai',
            ),
          ),
        ],
      ),
    );
  }
}
