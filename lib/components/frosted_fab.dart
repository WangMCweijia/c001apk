import 'dart:ui';

import 'package:c001apk_flutter/utils/app_theme.dart';
import 'package:flutter/material.dart';

/// 毛玻璃悬浮按钮
///
/// 通过 BackdropFilter 实现背景模糊，叠加半透明背景色让模糊效果可见。
/// - 日间：半透明白底 + 柔光阴影
/// - 夜间：半透明深底 + 荧光绿细边框 + 软辉光
///
/// 用法与 FloatingActionButton 类似，但视觉为毛玻璃质感。
class FrostedFAB extends StatelessWidget {
  const FrostedFAB({
    super.key,
    this.onPressed,
    required this.child,
    this.tooltip,
    this.size = 56.0,
    this.bgAlpha = 0.40,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final double size;
  /// 背景色透明度（0.0~1.0）。日间为白底 alpha，夜间为 darkCardBg alpha。
  /// 默认 0.40（40%）。值越低越透明，毛玻璃感越强。
  final double bgAlpha;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // 半透明背景色：让 BackdropFilter 的模糊可见
    final Color bgColor = isDark
        ? const Color(0xFF161B1A).withValues(alpha: bgAlpha)
        : Colors.white.withValues(alpha: bgAlpha);
    // 细边框强化玻璃质感
    final Color borderColor = isDark
        ? const Color(0x665EFF9F)
        : Colors.white.withValues(alpha: 0.7);
    // 外层辉光阴影
    final List<BoxShadow> shadows = isDark
        ? [
            BoxShadow(
              color: AppTheme.darkGlow(0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ];

    final Widget content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: shadows,
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: content);
    }
    return content;
  }
}
