import 'package:flutter/material.dart';
import 'dart:ui';

const Color _orange = Color(0xFFC66422);
const Color _darkBlue = Color(0xFF2E3542);
const Color _greyText = Color(0xFF707070);

class AccountSelectionDialog extends StatefulWidget {
  final List<dynamic> accounts;
  final Function(dynamic) onSelect;

  const AccountSelectionDialog({
    super.key,
    required this.accounts,
    required this.onSelect,
  });

  @override
  State<AccountSelectionDialog> createState() => _AccountSelectionDialogState();
}

class _AccountSelectionDialogState extends State<AccountSelectionDialog>
    with TickerProviderStateMixin {
  late AnimationController _sheetController;
  late AnimationController _itemsController;
  late Animation<double> _sheetAnimation;
  late Animation<double> _fadeAnimation;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();

    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _itemsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeIn,
    );

    _sheetController.forward().then((_) => _itemsController.forward());
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _itemsController.reverse();
    await _sheetController.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: _sheetController,
        builder: (context, child) {
          return Stack(
            children: [

              GestureDetector(
                onTap: _dismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8 * _fadeAnimation.value,
                    sigmaY: 8 * _fadeAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(_sheetAnimation),
                  child: _buildSheet(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8722E), Color(0xFFC66422)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _orange.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.manage_accounts_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "اختر الحساب",
                      style: TextStyle(
                        fontFamily: 'Almarai',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: _darkBlue,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "الحسابات المرتبطة بهذا الرقم",
                      style: TextStyle(
                        fontFamily: 'Almarai',
                        fontSize: 12,
                        color: _greyText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: Colors.grey.shade100, thickness: 1, indent: 24, endIndent: 24),
          const SizedBox(height: 8),

          // قائمة الأكونتات
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              itemCount: widget.accounts.length,
              itemBuilder: (context, index) => _buildAccountItem(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(int index) {
    final account = widget.accounts[index];
    final String displayName = account['fullName'] ??
        account['name'] ??
        account['userName'] ??
        account['username'] ??
        "مستخدم نظام";
    final String typeName = _getUserTypeName(account['userType']);
    final IconData typeIcon = _getUserTypeIcon(account['userType']);

    final itemAnimation = CurvedAnimation(
      parent: _itemsController,
      curve: Interval(
        (index * 0.18).clamp(0.0, 0.7),
        ((index * 0.18) + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 25 * (1 - itemAnimation.value)),
          child: Opacity(
            opacity: itemAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressedIndex = index),
        onTapUp: (_) async {
          setState(() => _pressedIndex = null);
          final selected = account;
          await _dismiss();
          widget.onSelect(selected);
        },
        onTapCancel: () => setState(() => _pressedIndex = null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _pressedIndex == index
                ? _orange.withOpacity(0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressedIndex == index
                  ? _orange.withOpacity(0.5)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: _pressedIndex == index
                ? [
              BoxShadow(
                color: _orange.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              // أيقونة النوع
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _pressedIndex == index
                      ? _orange.withOpacity(0.15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _pressedIndex == index
                        ? _orange.withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Icon(typeIcon,
                    color: _pressedIndex == index ? _orange : _darkBlue,
                    size: 22),
              ),
              const SizedBox(width: 12),

              // الاسم والنوع
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'Almarai',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _darkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        typeName,
                        style: const TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 11,
                          color: _orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // زرار الدخول
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _pressedIndex == index ? _orange : _darkBlue,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: (_pressedIndex == index ? _orange : _darkBlue)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getUserTypeName(dynamic type) {
    int t = int.tryParse(type?.toString() ?? "0") ?? 0;
    switch (t) {
      case 0: return "طالب";
      case 1:
      case 4: return "معلم / معلمة";
      case 2: return "إدارة";
      case 3: return "محاسب";
      default: return "مستخدم";
    }
  }

  IconData _getUserTypeIcon(dynamic type) {
    int t = int.tryParse(type?.toString() ?? "0") ?? 0;
    switch (t) {
      case 0: return Icons.school_rounded;
      case 1:
      case 4: return Icons.cast_for_education_rounded;
      case 2: return Icons.admin_panel_settings_rounded;
      case 3: return Icons.calculate_rounded;
      default: return Icons.person_rounded;
    }
  }
}