import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../pages/others/imageview_page.dart';

/// 打开图片全屏浏览，使用 Hero 动画从缩略图位置放大至全屏，
/// 返回时缩小回缩略图位置。转场为 fade（无左滑），由 Hero 接管缩放。
///
/// 调用方需将缩略图用 Hero(tag: imgUrl) 包裹，且传入的 heroTag 与之对应。
void openImageView(
  BuildContext context, {
  required List<String> imgList,
  int initialPage = 0,
  String? heroTag,
}) {
  final NavigatorState navigator = Navigator.of(context);
  navigator.push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      // fade 转场，避免默认的左滑 push 动画干扰 Hero
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ImageViewPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 淡入淡出，Hero 动画自动处理缩放
        return FadeTransition(opacity: animation, child: child);
      },
      settings: RouteSettings(
        name: '/imageview',
        arguments: {
          'imgList': imgList,
          'initialPage': initialPage,
          if (heroTag != null) 'heroTag': heroTag,
        },
      ),
    ),
  );
}

/// 兼容旧调用：保留 Get.toNamed 风格但走 Hero 路由。
void openImageViewWithGet({
  required List<String> imgList,
  int initialPage = 0,
  String? heroTag,
}) {
  final BuildContext? ctx = Get.context;
  if (ctx == null) {
    Get.toNamed('/imageview', arguments: {
      'imgList': imgList,
      'initialPage': initialPage,
    });
    return;
  }
  openImageView(ctx,
      imgList: imgList, initialPage: initialPage, heroTag: heroTag);
}
