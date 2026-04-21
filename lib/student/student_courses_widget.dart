import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StudentCoursesWidget extends StatefulWidget {
  final List<dynamic> coursesList;
  final bool isLoading;

  const StudentCoursesWidget(
      {super.key, required this.coursesList, required this.isLoading});

  @override
  State<StudentCoursesWidget> createState() => _StudentCoursesWidgetState();
}

class _StudentCoursesWidgetState extends State<StudentCoursesWidget> {
  static const String _baseUrl = "https://nour-al-eman.runasp.net";

  @override
  void initState() {
    super.initState();
  }

  String _getExtension(String? url) {
    if (url == null || url.isEmpty) return 'pdf';
    final ext = p.extension(url).replaceFirst('.', '').toLowerCase();
    return ext.isNotEmpty ? ext : 'pdf';
  }

  IconData _iconForExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file_outlined;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _downloadFile(dynamic course) async {
    final String? elementId = course['id']?.toString();
    if (elementId == null || elementId == '0') {
      _showSnackBar("بيانات الملف غير مكتملة");
      return;
    }
    debugPrint(" [DOWNLOAD START] جاري معالجة المهمة رقم: $elementId");
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('user_token');

      final String downloadUrl = "$_baseUrl/api/StudentCources/DownloadLatest?id=$elementId";

      final String courseName = (course['name'] ?? 'file')
          .toString()
          .replaceAll(RegExp(r'[^\u0600-\u06FF\w\s]+'), '_')
          .replaceAll(' ', '_');
      final String fileName = "${courseName}_$elementId.png";
      String? savedPath;
      if (Platform.isAndroid) {
        savedPath = "/storage/emulated/0/Download";
        final dir = Directory(savedPath);
        if (!await dir.exists()) {
          final extDir = await getExternalStorageDirectory();
          savedPath = extDir?.path;
        }
      } else {
        savedPath = (await getApplicationDocumentsDirectory()).path;
      }

      if (savedPath == null) {
        _showSnackBar("تعذر تحديد مسار الحفظ");
        return;
      }
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: savedPath,
        fileName: fileName,
        headers: {
          if (token != null && token != 'no_token') "Authorization": "Bearer $token",
          "Accept": "*/*",
        },
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );
      if (taskId != null) {
        _showSnackBar("بدأ تحميل: ${course['name']}", isError: false);
      }
    } catch (e) {
      debugPrint(" Error: $e");
      _showSnackBar("حدث خطأ أثناء محاولة التحميل");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Almarai')),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildDownloadButton(dynamic course) {
    return InkWell(
      onTap: () => _downloadFile(course),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForExt(_getExtension(course['url']?.toString())),
              color: const Color(0xFFC66422),
              size: 22,
            ),
            const SizedBox(width: 4),
            const Text(
              "تحميل",
              style: TextStyle(
                color: Color(0xFFC66422),
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF07427C)));
    }

    if (widget.coursesList.isEmpty) {
      return const Center(
          child: Text("لا توجد ملفات متاحة حالياً",
              style: TextStyle(fontFamily: 'Almarai')));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.coursesList.length,
      itemBuilder: (context, index) {
        final course = widget.coursesList[index];
        final String ext = _getExtension(course['url']?.toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFC66422).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconForExt(ext),
                    color: const Color(0xFFC66422), size: 26),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow("الإسم", course['name'] ?? "غير متوفر"),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                        "التفاصيل", course['description'] ?? "لا يوجد وصف"),

                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildDownloadButton(course),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text("$label: ",
            style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                fontFamily: 'Almarai')),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF2E3542),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Almarai')),
      ],
    );
  }
}