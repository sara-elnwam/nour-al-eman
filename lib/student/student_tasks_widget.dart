import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'task_model.dart';

class StudentTasksWidget extends StatelessWidget {
  final List<Datum> tasksList;
  final bool isLoading;

  const StudentTasksWidget({super.key, required this.tasksList, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF07427C)));
    }

    final unansweredTasks = tasksList.where((item) {
      return item.studentExams == null || item.studentExams!.isEmpty;
    }).toList();
    final answeredTasks = tasksList.where((item) {
      return item.studentExams != null && item.studentExams!.isNotEmpty;
    }).toList();
    if (tasksList.isEmpty) {
      return _buildEmptyState("لا توجد أعمال حالياً");
    }
    if (unansweredTasks.isEmpty) {
      return _buildAllAnsweredState(answeredTasks);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: unansweredTasks.length,
      itemBuilder: (context, index) {
        final item = unansweredTasks[index];
        return _buildTaskCard(item);
      },
    );
  }
  Widget _buildTaskCard(Datum item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? "بدون عنوان",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2E3542),
                    fontFamily: 'Almarai',
                  ),
                ),
                const SizedBox(height: 4),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: const TextStyle(color: Color(0xFF718096), fontSize: 13, fontFamily: 'Almarai'),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              if (item.url != null) {
                final fullUrl = "https://nour-al-eman.runasp.net${item.url}";
                if (await canLaunchUrl(Uri.parse(fullUrl))) {
                  await launchUrl(Uri.parse(fullUrl));
                }
              }
            },
            icon: const Icon(Icons.download_for_offline, color: Colors.orange, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildAllAnsweredState(List<Datum> answeredTasks) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF07427C), Color(0xFF0D5FAD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  "لقد أجبت على سؤال هذا الأسبوع بنجاح! ",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Almarai',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "انتظر حتى يتم رفع سؤال آخر",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'Almarai',
                  ),
                ),
              ],
            ),
          ),
          if (answeredTasks.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "نتائج أسئلتك السابقة:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF2E3542),
                  fontFamily: 'Almarai',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...answeredTasks.map((item) {
              final studentExam = item.studentExams![0];
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? "بدون عنوان",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2E3542),
                        fontFamily: 'Almarai',
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _badge("الدرجة: ${studentExam.grade ?? 'لم ترصد'}", Colors.green),
                        _badge("ملاحظة: ${studentExam.note ?? 'لا يوجد'}", Colors.blueGrey),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF718096)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF718096),
              fontSize: 15,
              fontFamily: 'Almarai',
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Almarai'),
      ),
    );
  }
}
  