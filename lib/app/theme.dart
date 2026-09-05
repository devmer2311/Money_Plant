import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette. Charcoal + soft violet glass for dark, light grey for light;
/// neon green stays an accent in both, never a background.
abstract class MP {
  static const neon = Color(0xFF00E676); // money in / primary accent
  static const mint = Color(0xFF5BFFB0);
  static const flame = Color(0xFFFF4D6D); // money out
  static const violet = Color(0xFF7C4DFF);
  static const cyan = Color(0xFF00E5FF);
  static const amber = Color(0xFFFFB300);

  // Charcoal, not OLED black: a pure-black ground kills the glass and makes
  // every ambient gradient band. Same reason light mode is grey, not white.
  static const void_ = Color(0xFF0C0E14);
  static const ink = Color(0xFF141824);
  static const slate = Color(0xFF1B2030);

  static const paper = Color(0xFFEFF0F5);
  static const chalk = Color(0xFFFFFFFF);
  static const graphite = Color(0xFF151824);

  /// Category colours, indexed by [kCategories] position.
  static const wheel = <Color>[
    Color(0xFF00E676),
    Color(0xFF00E5FF),
    Color(0xFF7C4DFF),
    Color(0xFFFF4D6D),
    Color(0xFFFFB300),
    Color(0xFF64FFDA),
    Color(0xFFFF6EC7),
    Color(0xFF9CCC65),
    Color(0xFF90A4AE),
  ];

  static Color forCategory(String c) {
    final i = c.hashCode.abs() % wheel.length;
    return wheel[i];
  }

  static const _icons = <String, IconData>{
    'Food': Icons.restaurant_rounded,
    'Travel': Icons.directions_car_rounded,
    'Rent': Icons.home_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Bills': Icons.receipt_rounded,
    'Health': Icons.favorite_rounded,
    'Fun': Icons.music_note_rounded,
    'Salary': Icons.payments_rounded,
  };

  static IconData iconFor(String category) =>
      _icons[category] ?? Icons.category_rounded;
}

ThemeData buildTheme({required bool dark}) {
  final scheme = dark
      ? const ColorScheme.dark(
          primary: MP.neon,
          onPrimary: MP.void_,
          secondary: MP.cyan,
          surface: MP.void_,
          onSurface: Color(0xFFEFF3EE),
          error: MP.flame,
        )
      : const ColorScheme.light(
          primary: Color(0xFF00A85A),
          onPrimary: Colors.white,
          secondary: MP.violet,
          surface: MP.paper,
          onSurface: MP.graphite,
          error: MP.flame,
        );

  // Space Grotesk: geometric, slightly quirky — the "premium fintech" register.
  final text = GoogleFonts.spaceGroteskTextTheme(
    dark ? Typography.whiteMountainView : Typography.blackMountainView,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displayLarge: text.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -2,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle:
          dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onSurface.withValues(alpha: 0.07),
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? MP.slate : MP.graphite,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

/// Frosted panel used everywhere instead of Material `Card`.
/// In light mode it is genuine glassmorphism; in dark mode a lifted slate
/// block with a hairline neon-tinted border (blur on black just reads as grey).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = tint ?? Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [MP.slate, MP.ink]
                : [
                    Colors.white.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.62),
                  ],
          ),
          border: Border.all(
            color: dark
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? accent.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
