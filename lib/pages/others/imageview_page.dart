import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../utils/download_util.dart';
import '../../utils/utils.dart';

class ImageViewPage extends StatefulWidget {
  const ImageViewPage({super.key});

  // Hero 飞行时的抛物线方向（供缩略图侧 flightShuttleBuilder 读取）：
  // 0 = 无（点击退出，直线飞回），-1 = 向上抛物线，1 = 向下抛物线
  static int heroParallaxDirection = 0;

  @override
  State<ImageViewPage> createState() => _ImageViewPageState();
}

class _ImageViewPageState extends State<ImageViewPage> {
  late int _initialPage;
  final _currentPageStream = StreamController<int>();
  late List<String> _imgList;
  String? _heroTag;
  late final _pageController = PageController(initialPage: _initialPage);

  @override
  void dispose() {
    _currentPageStream.close();
    _pageController.dispose();
    // 退出时恢复状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    int initialPage = Get.arguments['initialPage'] ?? 0;
    _initialPage = initialPage < 0 ? 0 : initialPage;
    _imgList = List.from(Get.arguments['imgList']);
    _heroTag = Get.arguments['heroTag'];
    // 全屏沉浸：使用 immersiveSticky 真正隐藏状态栏与导航栏。
    // 该模式对应 Android BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE：
    //   - 默认隐藏系统 bars（状态栏与导航栏）
    //   - 边缘滑动时 bars 仅短暂出现（自动隐藏），手势仍会传递给应用
    //   - 因此 PopScope 的左右滑返回手势可一次触发退出，无需两次
    // 相比之下，manual + overlays:[] 对应 BEHAVIOR_DEFAULT，会吞掉首次
    // 边缘手势用于恢复 bars，导致需要两次滑动才能返回。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // 重置抛物线方向，点击退出走直线 Hero
    ImageViewPage.heroParallaxDirection = 0;
  }

  /// 点击退出（Hero 动画直线返回缩略图）
  void _onExit() {
    ImageViewPage.heroParallaxDirection = 0;
    Get.back();
  }

  /// 上滑/下滑退出（Hero 动画 + 抛物线飞行轨迹）
  void _onSwipeExit(int direction) {
    ImageViewPage.heroParallaxDirection = direction;
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: PopScope(
        // 允许一次边缘返回手势直接退出，不拦截
        canPop: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          body: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: _onExit,
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300) {
                    // 上滑 → 向上退出
                    _onSwipeExit(-1);
                  } else if (velocity > 300) {
                    // 下滑 → 向下退出
                    _onSwipeExit(1);
                  }
                },
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        clipBehavior: Clip.hardEdge,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('保存',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                DownloadUtils.downloadImg(
                                    [_imgList[_initialPage]]);
                                Get.back();
                              },
                            ),
                            if (_imgList.length != 1)
                              ListTile(
                                title: const Text('保存全部',
                                    style: TextStyle(fontSize: 14)),
                                onTap: () {
                                  DownloadUtils.downloadImg(_imgList);
                                  Get.back();
                                },
                              ),
                            ListTile(
                              title: const Text('分享',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                Utils.onShareImg(_imgList[_initialPage]);
                                Get.back();
                              },
                            ),
                            ListTile(
                              title: const Text('复制',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                Utils.copyText(_imgList[_initialPage]);
                                Get.back();
                              },
                            ),
                            if (Utils.isDesktop)
                              ListTile(
                                title: const Text('在浏览器打开',
                                    style: TextStyle(fontSize: 14)),
                                onTap: () {
                                  Utils.launchURL(_imgList[_initialPage]);
                                  Get.back();
                                },
                              ),
                          ],
                        ),
                      );
                    });
                },
                child: PhotoViewGallery.builder(
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  scrollPhysics: const BouncingScrollPhysics(),
                  builder: (BuildContext context, int index) {
                    // 只有当前页设置 Hero tag，确保退出时返回对应缩略图
                    final activeTag = index == _initialPage
                        ? (_heroTag ?? _imgList[index])
                        : null;
                    return PhotoViewGalleryPageOptions(
                      imageProvider:
                          CachedNetworkImageProvider(_imgList[index]),
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes: activeTag != null
                          ? PhotoViewHeroAttributes(tag: activeTag)
                          : null,
                    );
                  },
                  itemCount: _imgList.length,
                  loadingBuilder: (context, event) => Center(
                    child: SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        value: event == null
                            ? 0
                            : event.cumulativeBytesLoaded /
                                event.expectedTotalBytes!,
                      ),
                    ),
                  ),
                  pageController: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _initialPage = index;
                      // 更新 heroTag 为当前浏览的图片，退出时返回对应缩略图
                      _heroTag = _imgList[index];
                    });
                    _currentPageStream.add(index);
                  },
                ),
              ),
              if (Utils.isDesktop && _imgList.length != 1)
                Positioned(
                  left: 0,
                  child: IconButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        _pageController.page!.round() - 1,
                        duration: const Duration(milliseconds: 255),
                        curve: Curves.ease,
                      );
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              if (Utils.isDesktop && _imgList.length != 1)
                Positioned(
                  right: 0,
                  child: IconButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        _pageController.page!.round() + 1,
                        duration: const Duration(milliseconds: 255),
                        curve: Curves.ease,
                      );
                    },
                    icon: Icon(
                      Icons.arrow_forward,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              // 页码：底部悬浮显示，弱化效果
              Positioned(
                bottom: 24,
                child: IgnorePointer(
                  child: StreamBuilder(
                    initialData: _initialPage,
                    stream: _currentPageStream.stream,
                    builder: (_, snapshot) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${snapshot.data! + 1} / ${_imgList.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
