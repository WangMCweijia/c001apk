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

  @override
  State<ImageViewPage> createState() => _ImageViewPageState();
}

class _ImageViewPageState extends State<ImageViewPage>
    with SingleTickerProviderStateMixin {
  late int _initialPage;
  final _currentPageStream = StreamController<int>();
  late List<String> _imgList;
  String? _heroTag;
  late final _pageController = PageController(initialPage: _initialPage);

  // 滑动退出动画
  late final AnimationController _exitController;
  int _exitDirection = 0; // 0 = 无, -1 = 向上, 1 = 向下
  bool _heroDisabled = false; // 滑动退出时禁用 Hero

  @override
  void dispose() {
    _currentPageStream.close();
    _pageController.dispose();
    _exitController.dispose();
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
    // 进入时隐藏状态栏（全屏沉浸）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  /// 点击退出（Hero 动画返回缩略图）
  void _onExit() {
    Get.back();
  }

  /// 上滑/下滑退出（抛物线动画）
  void _onSwipeExit(int direction) {
    if (_exitController.isAnimating) return;
    // 禁用 Hero，避免与滑动退出动画冲突
    setState(() {
      _heroDisabled = true;
      _exitDirection = direction;
    });
    _exitController.forward().then((_) {
      Get.back();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        body: AnimatedBuilder(
          animation: _exitController,
          builder: (context, child) {
            if (_exitDirection == 0 || !_exitController.isAnimating) {
              return child!;
            }
            // 抛物线效果：加速位移 + 淡出
            final t = _exitController.value;
            // easeIn 曲线模拟抛物线加速
            final curved = Curves.easeInCubic.transform(t);
            final dy = _exitDirection * curved * screenHeight * 1.3;
            final opacity = 1.0 - t;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
            );
          },
          child: Stack(
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
                    // 只有当前页设置 Hero tag，且滑动退出时禁用
                    final activeTag = (!_heroDisabled && index == _initialPage)
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
