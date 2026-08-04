import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../constants/constants.dart';
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

  // 已缓存大图的索引集合：用于切换缩略图→大图显示
  final Set<int> _largeReady = {};

  // 各页面的缩放状态：用于判断放大后垂直滑动是否退出
  final Map<int, PhotoViewScaleState> _scaleStates = {};

  // 边缘侧滑返回识别：manual + overlays:[] 下系统返回手势会被吞掉，
  // 这里用 Listener 自行监听边缘水平滑动，主动调用 Get.back() 完成一次返回。
  // - _edgeSwipeStartX != null 表示当前指针从屏幕左右边缘开始
  // - _edgeSwipeTriggered 防止一次滑动触发多次返回
  double? _edgeSwipeStartX;
  bool _edgeSwipeTriggered = false;
  static const double _edgeWidth = 24; // 边缘判定宽度（dp）
  static const double _swipeThreshold = 60; // 触发返回的最小位移（dp）

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
    // 全屏沉浸：使用 manual + overlays:[] 真正隐藏状态栏与导航栏。
    // 该模式下系统手势不会唤出 bars（符合"状态栏隐藏"要求），
    // 但 Android 系统边缘返回手势在沉浸模式下会被吞掉，需要两次才能返回。
    // 解决方案：用 Listener 自行监听边缘水平滑动，主动调用 Get.back()
    // 完成一次侧滑返回（见 build 中的 Listener 包裹）。
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [],
    );
    // 重置抛物线方向，点击退出走直线 Hero
    ImageViewPage.heroParallaxDirection = 0;
    // 延迟一帧后预缓存大图，确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheLarge(_initialPage);
    });
  }

  /// 预缓存大图：加载完成后通过 setState 切换到高清大图显示
  void _precacheLarge(int index) {
    if (index < 0 || index >= _imgList.length || _largeReady.contains(index)) {
      return;
    }
    final url = _imgList[index];
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    stream.addListener(ImageStreamListener(
      (info, sync) {
        if (mounted && !_largeReady.contains(index)) {
          setState(() => _largeReady.add(index));
        }
      },
    ));
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
      child: Listener(
        // translucent 让 Listener 收到指针事件但不阻止 child 接收（PhotoView 缩放/翻页正常）。
        // Listener 只观察指针事件，不会消费手势，因此不影响现有 GestureDetector 行为。
        behavior: HitTestBehavior.translucent,
        onPointerDown: (details) {
          final width = MediaQuery.of(context).size.width;
          final dx = details.position.dx;
          // 仅记录从左右边缘开始的触摸
          if (dx < _edgeWidth || dx > width - _edgeWidth) {
            _edgeSwipeStartX = dx;
            _edgeSwipeTriggered = false;
          } else {
            _edgeSwipeStartX = null;
          }
        },
        onPointerMove: (details) {
          if (_edgeSwipeStartX == null || _edgeSwipeTriggered) return;
          final width = MediaQuery.of(context).size.width;
          final startX = _edgeSwipeStartX!;
          final dx = details.position.dx - startX;
          final isLeftEdge = startX < _edgeWidth;
          final isRightEdge = startX > width - _edgeWidth;
          // 左边缘：向右滑动超过阈值；右边缘：向左滑动超过阈值
          if ((isLeftEdge && dx > _swipeThreshold) ||
              (isRightEdge && dx < -_swipeThreshold)) {
            _edgeSwipeTriggered = true;
            // 侧滑返回走直线 Hero（与点击退出一致）
            _onExit();
          }
        },
        onPointerUp: (_) {
          _edgeSwipeStartX = null;
          _edgeSwipeTriggered = false;
        },
        onPointerCancel: (_) {
          _edgeSwipeStartX = null;
          _edgeSwipeTriggered = false;
        },
        child: PopScope(
          // 允许一次边缘返回手势直接退出，不拦截
          canPop: true,
          child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          body: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                  controller: _pageController,
                  itemCount: _imgList.length,
                  // 放大后禁止翻页，让 PhotoView 处理水平滑动（拖动图片左右查看）
                  physics: _scaleStates[_initialPage] ==
                          PhotoViewScaleState.zoomedIn
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _initialPage = index;
                      _heroTag =
                          '${_imgList[index]}${Constants.SUFFIX_THUMBNAIL}';
                    });
                    _currentPageStream.add(index);
                    _precacheLarge(index);
                  },
                  itemBuilder: (context, index) {
                    final thumbUrl =
                        '${_imgList[index]}${Constants.SUFFIX_THUMBNAIL}';
                    final activeTag = index == _initialPage
                        ? (_heroTag ?? thumbUrl)
                        : null;
                    final useLarge = _largeReady.contains(index);
                    final imageUrl = useLarge ? _imgList[index] : thumbUrl;
                    return PhotoView(
                      imageProvider: CachedNetworkImageProvider(imageUrl),
                      backgroundDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      heroAttributes: activeTag != null
                          ? PhotoViewHeroAttributes(tag: activeTag)
                          : null,
                      scaleStateChangedCallback: (state) {
                        setState(() => _scaleStates[index] = state);
                      },
                      loadingBuilder: (context, event) {
                        final progress = event == null
                            ? null
                            : event.cumulativeBytesLoaded /
                                (event.expectedTotalBytes ?? 1);
                        return CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Center(
                            child: SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(
                                  value: progress ?? 0),
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(
                                  value: progress ?? 0),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              // 手势层：放大时仅保留长按，点击/滑动退出交由 PhotoView 独占
              final isZoomed = _scaleStates[_initialPage] ==
                  PhotoViewScaleState.zoomedIn;
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: isZoomed ? null : _onExit,
                onVerticalDragEnd: isZoomed
                    ? null
                    : (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity < -300) {
                          _onSwipeExit(-1);
                        } else if (velocity > 300) {
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
      ),
    );
  }
}
