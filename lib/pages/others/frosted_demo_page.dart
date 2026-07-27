import 'dart:ui';

import 'package:c001apk_flutter/components/frosted_fab.dart';
import 'package:c001apk_flutter/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 毛玻璃透明度对比页（临时 demo）
/// 在带彩色装饰的渐变背景上展示 4 种透明度的 FrostedFAB + 胶囊按钮，
/// 用于让用户对比选出一个满意的透明度后，正式应用到所有页面。
class FrostedDemoPage extends StatelessWidget {
  const FrostedDemoPage({super.key});

  static const List<_AlphaOption> options = [
    _AlphaOption(label: '当前 55%', alpha: 0.55),
    _AlphaOption(label: '选项 A 40%', alpha: 0.40),
    _AlphaOption(label: '选项 B 30%', alpha: 0.30),
    _AlphaOption(label: '选项 C 20%', alpha: 0.20),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('毛玻璃透明度对比'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: activeColor,
        ),
        body: Stack(
          children: [
            // 背景：渐变 + 彩色装饰，让毛玻璃效果可见
            Positioned.fill(
              child: Container(
                decoration: AppTheme.backgroundDecoration(
                    Theme.of(context).brightness),
                child: Stack(
                  children: [
                    _colorCircle(
                      context,
                      color: AppTheme.lightSecondary.withValues(alpha: 0.7),
                      top: 80,
                      right: -40,
                      size: 180,
                    ),
                    _colorCircle(
                      context,
                      color: AppTheme.lightPrimary.withValues(alpha: 0.5),
                      top: 280,
                      left: -50,
                      size: 220,
                    ),
                    _colorCircle(
                      context,
                      color: Colors.amber.withValues(alpha: 0.4),
                      top: 520,
                      right: -30,
                      size: 160,
                    ),
                    _colorCircle(
                      context,
                      color: Colors.purpleAccent.withValues(alpha: 0.35),
                      top: 720,
                      left: -40,
                      size: 200,
                    ),
                    _colorCircle(
                      context,
                      color: Colors.teal.withValues(alpha: 0.4),
                      top: 980,
                      right: -20,
                      size: 180,
                    ),
                  ],
                ),
              ),
            ),
            // 4 种透明度对比，纵向排列
            SafeArea(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                itemCount: options.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 28),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xE6161B1A)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkCardBorder
                              : AppTheme.lightCardBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '对比 4 种透明度，每行展示一个单按钮 + 一个胶囊按钮。'
                        '背景有彩色装饰，毛玻璃会模糊这些彩色。'
                        '选定满意的透明度后告诉我，我会移除对比页正式应用。',
                        style: TextStyle(
                          fontSize: 13,
                          color: activeColor,
                        ),
                      ),
                    );
                  }
                  final opt = options[index - 1];
                  return _AlphaSection(
                    label: opt.label,
                    alpha: opt.alpha,
                    activeColor: activeColor,
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorCircle(
    BuildContext context, {
    required Color color,
    required double top,
    double? left,
    double? right,
    required double size,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AlphaOption {
  const _AlphaOption({required this.label, required this.alpha});
  final String label;
  final double alpha;
}

class _AlphaSection extends StatelessWidget {
  const _AlphaSection({
    required this.label,
    required this.alpha,
    required this.activeColor,
    required this.isDark,
  });

  final String label;
  final double alpha;
  final Color activeColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xE6161B1A)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: activeColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 单按钮 + 胶囊按钮组合
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 单按钮
            FrostedFAB(
              bgAlpha: alpha,
              onPressed: () {},
              child: Icon(Icons.refresh_rounded, color: activeColor),
            ),
            // 胶囊按钮（仿 main_page 样式）
            _FrostedCapsule(
              alpha: alpha,
              activeColor: activeColor,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }
}

/// 仿主页胶囊导航按钮，用于对比透明度
class _FrostedCapsule extends StatelessWidget {
  const _FrostedCapsule({
    required this.alpha,
    required this.activeColor,
    required this.isDark,
  });

  final double alpha;
  final Color activeColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDark
        ? const Color(0xFF161B1A).withValues(alpha: alpha)
        : Colors.white.withValues(alpha: alpha);
    final Color borderColor = isDark
        ? const Color(0x665EFF9F)
        : Colors.white.withValues(alpha: 0.7);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.darkGlow(0.18)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _capsuleIcon(Icons.home, '主页', activeColor),
                Container(
                  width: 1,
                  height: 24,
                  color: borderColor,
                ),
                _capsuleIcon(Icons.person, '我的', activeColor),
                Container(
                  width: 1,
                  height: 24,
                  color: borderColor,
                ),
                _capsuleAction(activeColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _capsuleIcon(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              height: 1,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _capsuleAction(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_rounded, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            '发布',
            style: TextStyle(
              fontSize: 10,
              height: 1,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
