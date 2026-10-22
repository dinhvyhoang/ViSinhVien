import 'package:flutter/material.dart';
import 'widgets.dart';

abstract final class AppColors {
  static const background = Color(0xFFFAF8FF);
  static const primary = Color(0xFF006C49);
  static const mint = Color(0xFF10B981);
  static const ink = Color(0xFF131B2E);
  static const muted = Color(0xFF63746C);
  static const red = Color(0xFFBA1A1A);
  static const amber = Color(0xFFE69500);
  static const lavender = Color(0xFFEAEDFF);
}

ThemeData financeTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.mint,
    surface: Colors.white,
    error: AppColors.red,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -.7,
        color: AppColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.ink, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F3FF),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.mint, width: 1.5),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: const Color(0xFF003F30),
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFDCE7DF)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.mint,
      foregroundColor: AppColors.primary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.mint,
      linearTrackColor: AppColors.lavender,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFEFF0F5),
      thickness: 1,
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  const SurfaceCard({super.key, required this.child, this.padding, this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;
  final List<Widget>? actions;
  const BrandAppBar({super.key, required this.subtitle, this.actions});
  @override
  Size get preferredSize => const Size.fromHeight(72);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 72,
    titleSpacing: 20,
    title: Row(
      children: [
        Container(
          width: 36,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.school_outlined,
            color: AppColors.primary,
            size: 25,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ví Sinh Viên',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [...?actions, const SizedBox(width: 12)],
  );
}

IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('trọ') || n.contains('nhà')) return Icons.home_outlined;
  if (n.contains('ăn') || n.contains('uống')) return Icons.restaurant_outlined;
  if (n.contains('đi lại') || n.contains('xe')) {
    return Icons.directions_bus_outlined;
  }
  if (n.contains('học')) return Icons.menu_book_outlined;
  if (n.contains('giải trí')) return Icons.sports_esports_outlined;
  if (n.contains('gia đình')) return Icons.payments_outlined;
  if (n.contains('làm')) return Icons.work_outline;
  return Icons.receipt_long_outlined;
}

Color categoryColor(String name) {
  return switch (categoryIcon(name)) {
    Icons.home_outlined => AppColors.red,
    Icons.restaurant_outlined => AppColors.primary,
    Icons.directions_bus_outlined => const Color(0xFF2983FF),
    Icons.menu_book_outlined => const Color(0xFF5B56A0),
    _ => AppColors.primary,
  };
}

class CategoryAvatar extends StatelessWidget {
  final String name;
  final double size;
  const CategoryAvatar({super.key, required this.name, this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: categoryColor(name).withValues(alpha: .11),
      borderRadius: BorderRadius.circular(size * .35),
    ),
    child: Icon(
      categoryIcon(name),
      size: size * .48,
      color: categoryColor(name),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.receipt_long_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.lavender,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class TransactionCard extends StatelessWidget {
  final String category, note, type;
  final num amount;
  final DateTime date;
  final VoidCallback onTap;
  const TransactionCard({
    super.key,
    required this.category,
    required this.note,
    required this.type,
    required this.amount,
    required this.date,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CategoryAvatar(name: category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${note.isEmpty ? typeLabel(type) : note} · ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${type == 'income' ? '+' : '-'}${money(amount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: type == 'income'
                              ? AppColors.primary
                              : AppColors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type == 'income' ? 'Thu nhập' : 'Chi tiêu',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
