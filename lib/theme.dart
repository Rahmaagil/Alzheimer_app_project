import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF42A5F5);
  static const Color secondaryColor = Color(0xFF90CAF9);
  static const Color accentColor = Color(0xFFBBDEFB);
  static const Color backgroundColor = Color(0xFFF5FAFF);
  static const Color backgroundLight = Color(0xFFE3F2FD);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF81C784);
  static const Color warningColor = Color(0xFFFFB74D);
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF90CAF9), Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFE3F2FD), Color(0xFFF5FAFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F6FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class AppDecorations {
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 15,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get gradientBackground => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
    ),
  );

  static BoxDecoration circularGradient(Color color1, Color color2) {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [color1, color2]),
      boxShadow: [
        BoxShadow(
          color: color1.withValues(alpha: 0.3),
          blurRadius: 12,
        ),
      ],
    );
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  static Curve get defaultCurve => Curves.easeInOut;
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryColor,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppTheme.primaryColor,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppTheme.primaryColor,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.black87,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.black54,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Colors.black45,
  );
}

class AppDecorationWidgets {
  static Widget get gradientBackground => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
colors: [Color(0xFFE3F2FD), Color(0xFFF5FAFF)],
      ),
    ),
  );

  static Widget animatedCircle({
    double width = 100,
    double height = 100,
    double top = 0,
    double right = -20,
    bool isPrimary = true,
    Duration duration = const Duration(seconds: 6),
  }) {
    return Positioned(
      top: top,
      right: right,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 1.0 + (0.05 * (1 - value).abs()),
            child: Opacity(
              opacity: 0.6 + (0.4 * value),
              child: child,
            ),
          );
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isPrimary
                  ? [
                      const Color(0xFF90CAF9).withValues(alpha: 0.25),
                      const Color(0xFF64B5F6).withValues(alpha: 0.15),
                    ]
                  : [
                      const Color(0xFFBBDEFB).withValues(alpha: 0.15),
                      const Color(0xFF90CAF9).withValues(alpha: 0.1),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget floatingCircle({
    double size = 80,
    double bottom = 100,
    double left = -30,
    Color? color,
  }) {
    return Positioned(
      bottom: bottom,
      left: left,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.2),
        duration: const Duration(seconds: 4),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (color ?? const Color(0xFF90CAF9)).withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }

  static Widget pulseCircle({
    double size = 60,
    double top = 150,
    double left = 20,
    Color? color,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.1),
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: 0.7,
              child: child,
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (color ?? const Color(0xFF90CAF9)).withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }

  static Widget decorativeCircle({
    double width = 100,
    double height = 100,
    double top = 0,
    double right = -20,
    bool isPrimary = true,
  }) {
    return Positioned(
      top: top,
      right: right,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isPrimary
                ? [
                    const Color(0xFF6EC6FF).withValues(alpha: 0.2),
                    const Color(0xFF9B7DFF).withValues(alpha: 0.15),
                  ]
                : [
                    const Color(0xFF7BEDC0).withValues(alpha: 0.15),
                    const Color(0xFF9B7DFF).withValues(alpha: 0.1),
                  ],
          ),
        ),
      ),
    );
  }

  static Widget decorativeCircleBottomLeft({
    double width = 80,
    double height = 80,
    double bottom = 100,
    double left = -30,
  }) {
    return Positioned(
      bottom: bottom,
      left: left,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF90CAF9).withValues(alpha: 0.15),
        ),
      ),
    );
  }

  static Widget glassCard({required Widget child, EdgeInsets? padding, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget animatedCard({required Widget child, EdgeInsets? margin, Duration delay = Duration.zero}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  static Widget slideInWidget({required Widget child, Duration duration = const Duration(milliseconds: 600), Curve curve = Curves.easeOutCubic}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  static Widget fadeInWidget({required Widget child, Duration duration = const Duration(milliseconds: 400)}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }

  static Widget scaleInWidget({required Widget child, Duration duration = const Duration(milliseconds: 500), Curve curve = Curves.easeOutBack}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

static Widget animatedBackground({Widget? child}) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE3F2FD), Color(0xFFF5FAFF)],
            ),
          ),
        ),
        animatedCircle(width: 180, height: 180, top: -60, right: -40, isPrimary: true, duration: const Duration(seconds: 8)),
        floatingCircle(size: 90, bottom: 80, left: -20, color: const Color(0xFF64B5F6)),
        floatingCircle(size: 140, bottom: 120, left: -50, color: const Color(0xFF90CAF9)),
        pulseCircle(size: 50, top: 120, left: 30, color: const Color(0xFF90CAF9)),
        if (child != null) child,
      ],
    );
  }

  static Widget buildDecoCircles() {
    return Stack(
      children: [
        animatedCircle(width: 180, height: 180, top: -60, right: -40, isPrimary: true, duration: const Duration(seconds: 8)),
        floatingCircle(size: 90, bottom: 80, left: -20, color: const Color(0xFF64B5F6)),
        floatingCircle(size: 140, bottom: 120, left: -50, color: const Color(0xFF90CAF9)),
        pulseCircle(size: 50, top: 120, left: 30, color: const Color(0xFF90CAF9)),
      ],
    );
  }

  static Widget gradientButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    IconData? icon,
    double height = 54,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.grey,
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isLoading
                ? null
                : const LinearGradient(colors: [Color(0xFF90CAF9), Color(0xFF64B5F6)]),
            color: isLoading ? Colors.grey : null,
            borderRadius: const BorderRadius.all(Radius.circular(30)),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static Widget appLogo({double size = 90}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF90CAF9), Color(0xFF64B5F6)]),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Icon(Icons.psychology, color: Colors.white, size: 42),
    );
  }
}
