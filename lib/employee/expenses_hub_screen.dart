import 'package:flutter/material.dart';
import 'facility_type_screen.dart';
import 'expenses_screen.dart';
import 'student_payment_screen.dart';
import 'employee_rating_screen.dart'; // ✅ شاشة تقييم الموظفين

const Color _kOrange      = Color(0xFFC66422);
const Color _kDarkBlue    = Color(0xFF2E3542);
const Color _kActiveBlue  = Color(0xFF1976D2);
const Color _kBorderColor = Color(0xFFE2E8F0);

class ExpensesHubScreen extends StatefulWidget {
  const ExpensesHubScreen({Key? key}) : super(key: key);

  @override
  State<ExpensesHubScreen> createState() => _ExpensesHubScreenState();
}

class _ExpensesHubScreenState extends State<ExpensesHubScreen> {
  // -1 = شاشة الكاردات   |   0,1,2,3 = الشاشات الفرعية
  int _activeSection = -1;

  final List<_SectionMeta> _sections = const [
    _SectionMeta(
      icon    : Icons.category_outlined,
      label   : 'أنواع\nالمصروفات',
      color   : _kActiveBlue,
      bgColor : Color(0xFFE3F0FB),
      title   : 'أنواع المصروفات',
    ),
    _SectionMeta(
      icon    : Icons.receipt_long_outlined,
      label   : 'المصروفات',
      color   : _kOrange,
      bgColor : Color(0xFFFAECE3),
      title   : 'المصروفات',
    ),
    _SectionMeta(
      icon    : Icons.school_outlined,
      label   : 'مدفوعات\nالطالب',
      color   : Color(0xFF2E7D32),
      bgColor : Color(0xFFE8F5E9),
      title   : 'مدفوعات الطالب',
    ),
    _SectionMeta(
      icon    : Icons.star_rate_outlined,
      label   : 'تقييم\nالموظفين',
      color   : Color(0xFF7B1FA2),
      bgColor : Color(0xFFF3E5F5),
      title   : 'تقييم الموظفين',
    ),
  ];

  void _openSection(int index) => setState(() => _activeSection = index);
  void _goBack()               => setState(() => _activeSection = -1);

  @override
  Widget build(BuildContext context) {
    // ── شاشة فرعية مفتوحة ────────────────────────────────────
    if (_activeSection >= 0) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // شريط العنوان الداخلي
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: _kDarkBlue,
                    onPressed: _goBack,
                  ),
                  Text(
                    _sections[_activeSection].title,
                    style: const TextStyle(
                        color: _kDarkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Almarai'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorderColor),
            // المحتوى
            Expanded(child: _buildSectionBody(_activeSection)),
          ],
        ),
      );
    }

    // ── شاشة الكاردات ────────────────────────────────────────
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      color: _kOrange, size: 26),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('إدارة المصروفات',
                        style: TextStyle(
                            color: _kDarkBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Almarai')),
                    SizedBox(height: 2),
                    Text('اختر القسم الذي تريد إدارته',
                        style: TextStyle(
                            color: Color(0xFF718096),
                            fontSize: 13,
                            fontFamily: 'Almarai')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // الكاردات
            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                mainAxisSpacing: 16,
                childAspectRatio: 3.2,
                children: List.generate(_sections.length, (i) => _HubCard(
                  meta  : _sections[i],
                  onTap : () => _openSection(i),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBody(int index) {
    switch (index) {
      case 0: return const FacilityTypeScreen();
      case 1: return const ExpensesScreen();
      case 2: return const StudentPaymentScreen();
      case 3: return const EmployeeRatingScreen(); // ✅ تقييم الموظفين
      default: return const SizedBox.shrink();
    }
  }
}

// ── بيانات كل قسم ────────────────────────────────────────────
class _SectionMeta {
  final IconData icon;
  final String   label;
  final Color    color;
  final Color    bgColor;
  final String   title;
  const _SectionMeta({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.title,
  });
}

// ── كارد فردي ────────────────────────────────────────────────
class _HubCard extends StatelessWidget {
  final _SectionMeta meta;
  final VoidCallback onTap;

  const _HubCard({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorderColor),
            boxShadow: [
              BoxShadow(
                color: meta.color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: meta.bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 30),
                ),
                const SizedBox(width: 16),
                Text(meta.label.replaceAll('\n', ' '),
                    style: TextStyle(
                        color: _kDarkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Almarai')),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, color: meta.color, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}