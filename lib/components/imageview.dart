import 'dart:math';

import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../components/nine_grid_view.dart';
import '../constants/constants.dart';
import '../pages/others/imageview_page.dart';
import '../utils/imageview_route.dart';
import '../utils/utils.dart';

Widget image(
  double maxWidth,
  List<String> picArr, {
  bool isFeedArticle = false,
  String? articleImg,
}) {
  double imageWidth = (maxWidth - 2 * 5) / 3;
  double imageHeight = imageWidth;
  if (isFeedArticle || picArr.length == 1) {
    List<double> imageLp =
        Utils.getImageLp(isFeedArticle ? articleImg! : picArr[0]);
    double ratioWH = imageLp[0] / imageLp[1];
    double ratioHW = imageLp[1] / imageLp[0];
    double maxRatio = 22 / 9;
    imageWidth = isFeedArticle
        ? maxWidth
        : ratioWH > 1.5
            ? maxWidth
            : (ratioWH >= 1 || (imageLp[1] > imageLp[0] && ratioHW < 1.5))
                ? 2 * imageWidth
                : imageWidth;
    imageHeight = imageWidth * min(ratioHW, maxRatio);
  }
  return NineGridView(
    bigImageWidth: imageWidth,
    bigImageHeight: imageHeight,
    space: 5,
    height: isFeedArticle || picArr.length == 1 ? imageHeight : null,
    width: isFeedArticle || picArr.length == 1 ? imageWidth : maxWidth,
    itemCount: isFeedArticle ? 1 : picArr.length,
    itemBuilder: (context, index) {
      final String imgUrl = isFeedArticle
          ? (articleImg ?? picArr.first)
          : picArr[index];
      return GestureDetector(
        onTap: () {
          openImageView(
            context,
            imgList: picArr,
            initialPage: isFeedArticle
                ? picArr.indexOf(articleImg!)
                : picArr.indexOf(picArr[index]),
            heroTag: imgUrl,
          );
        },
        child: Hero(
          tag: imgUrl,
          // 自定义 Hero 飞行：滑动退出时按方向做抛物线偏移，点击退出走直线
          flightShuttleBuilder:
              (context, animation, direction, fromContext, toContext) {
            final isPop = direction == HeroFlightDirection.pop;
            final Hero heroWidget =
                (isPop ? fromContext.widget : toContext.widget) as Hero;
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = animation.value;
                // 抛物线：4t(1-t)，在 t=0.5 时最大为 1，两端为 0
                final parabola = 4 * t * (1 - t);
                final dy = isPop
                    ? ImageViewPage.heroParallaxDirection * parabola * 120
                    : 0.0;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              child: heroWidget.child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.5),
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  networkImage(
                    '$imgUrl${Constants.SUFFIX_THUMBNAIL}',
                    width: imageWidth,
                    height: imageHeight,
                    fit: isFeedArticle || picArr.length == 1
                        ? BoxFit.fill
                        : BoxFit.cover,
                  ),
                  if (imgUrl.endsWith(Constants.SUFFIX_GIF))
                    _badge(context, 'GIF'),
                  if (!imgUrl.endsWith(Constants.SUFFIX_GIF) &&
                      _isLongImage(imgUrl))
                    _badge(context, '长图'),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

bool _isLongImage(String url) {
  List<double> imageLp = Utils.getImageLp(url);
  return imageLp[1] / imageLp[0] >= 22 / 9;
}

Widget _badge(BuildContext context, String title) {
  return Container(
    margin: const EdgeInsets.all(5),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4)),
    child: Text(
      title,
      style: TextStyle(
        height: 1,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      strutStyle: const StrutStyle(
        height: 1,
        leading: 0,
        fontSize: 12,
      ),
    ),
  );
}
