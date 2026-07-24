import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 应用主题系统：
/// - 方案 C 薄荷玻璃（LIQUID MINT）= 日间模式
/// - 方案 A 极客电路绿（CIRCUIT GREEN）= 夜间模式
class AppTheme {
  AppTheme._();

  // ==================== 方案 C: 薄荷玻璃（日间） ====================
  static const Color lightBg = Color(0xFFF7FAF5);
  static const Color lightBgGradientStart = Color(0xFFE8F5EE);
  static const Color lightBgGradientEnd = Color(0xFFFFF8E7);
  static const Color lightPrimary = Color(0xFF1E6B5C);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFFF4A09C);
  static const Color lightSurface = Color(0xFFFFFBF3);
  static const Color lightCardBg = Color(0xCCFFFFFF); // 80% 白
  static const Color lightCardBorder = Color(0x80FFFFFF);
  static const Color lightOnSurface = Color(0xFF1A2A26);
  static const Color lightOutline = Color(0xFF7A9A8E);
  static const Color lightOutlineVariant = Color(0xFFD4E4DC);
  static const Color lightPillBg = Color(0xFF1E6B5C);

  // ==================== 方案 A: 极客电路绿（夜间） ====================
  static const Color darkBg = Color(0xFF0B0F0E);
  static const Color darkBgGradientStart = Color(0xFF0B0F0E);
  static const Color darkBgGradientEnd = Color(0xFF141A18);
  static const Color darkPrimary = Color(0xFF5EFF9F);
  static const Color darkOnPrimary = Color(0xFF0B0F0E);
  static const Color darkSecondary = Color(0xFF5EFF9F);
  static const Color darkSurface = Color(0xFF0F1413);
  static const Color darkCardBg = Color(0xFF161B1A);
  static const Color darkCardBorder = Color(0x405EFF9F); // 25% 荧光绿
  static const Color darkOnSurface = Color(0xFFE0E8E4);
  static const Color darkOutline = Color(0xFF5A6A64);
  static const Color darkOutlineVariant = Color(0xFF2A3530);

  /// 荧光绿辉光颜色（带 alpha 用于阴影/光晕）
  static Color darkGlow([double alpha = 0.18]) =>
      const Color(0xFF5EFF9F).withValues(alpha: alpha);

  /// 日间渐变背景
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBgGradientStart, lightBgGradientEnd],
  );

  /// 夜间渐变背景
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgGradientStart, darkBgGradientEnd],
  );

  // ==================== 日间 ThemeData ====================
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: lightPrimary,
          onPrimary: lightOnPrimary,
          secondary: lightSecondary,
          onSecondary: Color(0xFF1A2A26),
          error: Color(0xFFBA1A1A),
          onError: Color(0xFFFFFFFF),
          surface: lightSurface,
          onSurface: lightOnSurface,
          surfaceContainerHighest: Color(0xFFEDEEEA),
          surfaceContainer: Color(0xFFF2F5F0),
          surfaceTint: lightPrimary,
          outline: lightOutline,
          outlineVariant: lightOutlineVariant,
          onInverseSurface: Color(0xFFF1F0EA),
        ),
        scaffoldBackgroundColor: lightBg,
        cardTheme: CardThemeData(
          color: lightCardBg,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x33F4A09C),
          elevation: 0,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: lightOnSurface,
          elevation: 0,
          centerTitle: false,
          // 日间浅色 AppBar 背景 → 状态栏图标用深色
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xCCFFFFFF),
          surfaceTintColor: Colors.transparent,
          indicatorColor: lightPrimary,
          indicatorShape: const StadiumBorder(),
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: lightPrimary,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFFE8F5EE),
          contentTextStyle: const TextStyle(color: lightPrimary),
          actionTextColor: lightPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFFE8F5EE),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: lightPrimary,
          refreshBackgroundColor: const Color(0xFFD4E4DC),
        ),
        dividerTheme: DividerThemeData(
          color: lightOutlineVariant.withValues(alpha: 0.5),
          thickness: 1,
          space: 1,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ZoomPageTransitionsBuilder(
              allowEnterRouteSnapshotting: false,
            ),
          },
        ),
      );

  // ==================== 夜间 ThemeData ====================
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: darkPrimary,
          onPrimary: darkOnPrimary,
          secondary: darkSecondary,
          onSecondary: darkOnPrimary,
          error: Color(0xFFFF5252),
          onError: Color(0xFF0B0F0E),
          surface: darkSurface,
          onSurface: darkOnSurface,
          surfaceContainerHighest: Color(0xFF1A201E),
          surfaceContainer: Color(0xFF111614),
          surfaceTint: darkPrimary,
          outline: darkOutline,
          outlineVariant: darkOutlineVariant,
          onInverseSurface: Color(0xFF1A201E),
        ),
        scaffoldBackgroundColor: darkBg,
        cardTheme: CardThemeData(
          color: darkCardBg,
          surfaceTintColor: Colors.transparent,
          shadowColor: darkGlow(0.1),
          elevation: 0,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: darkPrimary,
          elevation: 0,
          centerTitle: false,
          // 夜间深色 AppBar 背景 → 状态栏图标用浅色
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xF00F1413),
          surfaceTintColor: Colors.transparent,
          indicatorColor: darkPrimary,
          indicatorShape: const StadiumBorder(),
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: darkPrimary,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkCardBg,
          contentTextStyle: const TextStyle(color: darkPrimary),
          actionTextColor: darkPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: darkCardBorder, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: darkCardBg,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkCardBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: darkCardBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkPrimary, width: 1.2),
          ),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: darkPrimary,
          refreshBackgroundColor: darkOutlineVariant,
        ),
        dividerTheme: DividerThemeData(
          color: darkCardBorder,
          thickness: 1,
          space: 1,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ZoomPageTransitionsBuilder(
              allowEnterRouteSnapshotting: false,
            ),
          },
        ),
      );

  /// 背景渐变 Container（用于 Scaffold 背景装饰）
  static BoxDecoration backgroundDecoration(Brightness brightness) {
    return BoxDecoration(
      gradient: brightness == Brightness.dark
          ? darkBackgroundGradient
          : lightBackgroundGradient,
    );
  }
}
