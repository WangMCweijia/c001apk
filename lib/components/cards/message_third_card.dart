import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

Widget messageThirdCard(
  BuildContext context,
  int backgroundColor,
  IconData icon,
  String title,
  int? badge,
  Function() onTap,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardRadius = isDark ? 12.0 : 16.0;
  return Material(
    clipBehavior: Clip.hardEdge,
    borderRadius: BorderRadius.circular(cardRadius),
    color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
    child: InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(
            color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: AppTheme.darkGlow(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppTheme.lightSecondary.withValues(alpha: 0.1),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color(backgroundColor),
                    shape: BoxShape.circle,
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: Color(backgroundColor)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    flex: 1,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkOnSurface
                            : AppTheme.lightOnSurface,
                      ),
                    )),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: isDark ? AppTheme.darkOutline : AppTheme.lightOutline,
                ),
              ],
            ),
            if (badge != null && badge > 0) Badge.count(count: badge)
          ],
        ),
      ),
    ),
  );
}
