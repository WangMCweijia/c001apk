import 'package:flutter/material.dart';

Widget messageThirdCard(
  BuildContext context,
  int backgroundColor,
  IconData icon,
  String title,
  int? badge,
  Function() onTap,
) {
  return Material(
    clipBehavior: Clip.hardEdge,
    borderRadius: const BorderRadius.all(Radius.circular(14)),
    color: Theme.of(context).colorScheme.onInverseSurface,
    elevation: 1,
    shadowColor: Colors.black.withValues(alpha: 0.06),
    child: InkWell(
      onTap: onTap,
      child: Padding(
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
                    )),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: Theme.of(context).colorScheme.outline,
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
