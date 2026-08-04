import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/dialog/dialog_route.dart';

import '../../pages/home/return_top_controller.dart';
import '../../pages/home/home_page.dart';
import '../../pages/main/main_controller.dart';
import '../../pages/message/message_page.dart';
import '../../pages/feed/reply/reply_page.dart';
import '../../utils/app_theme.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final ReturnTopController _pageScrollController =
      Get.put(ReturnTopController(), tag: 'home');
  int _selectedIndex = 0;
  final _indexSctream = StreamController<int>.broadcast();
  late final MainController _mainController = Get.put(MainController());
  final _contrller = PageController();

  @override
  void initState() {
    super.initState();
    _mainController.checkLoginInfo();
  }

  @override
  void dispose() async {
    await GStorage.close();
    Get.delete<ReturnTopController>(tag: 'home');
    Get.delete<MainController>();
    super.dispose();
  }

  void onBackPressed() async {
    if (_selectedIndex != 0) {
      onDestinationSelected(0);
    } else {
      SystemNavigator.pop();
    }
  }

  /// 点击刷新按钮：返回屏幕顶端并刷新主页信息流
  void _onRefresh() {
    // 立即展开胶囊导航（转换为 3 按钮），无需等待刷新完成
    _pageScrollController.setNavExpanded(true);
    // setIndex(998) 触发当前 HomePage feed tab 的 animateToTop（内含 refreshKey.show 刷新）
    _pageScrollController.setIndex(998);
  }

  /// 点击发布按钮
  void _onPublish() {
    if (!GlobalData().isLogin) return;
    Navigator.of(context).push(
      GetDialogRoute(
        pageBuilder: (buildContext, animation, secondaryAnimation) {
          return const ReplyPage();
        },
        transitionDuration: const Duration(milliseconds: 500),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.linear;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomePage(),
      MessagePage(),
    ];

    const railDestinations = <NavigationRailDestination>[
      NavigationRailDestination(
        selectedIcon: Icon(Icons.home),
        icon: Icon(Icons.home_outlined),
        label: Text('主页'),
      ),
      NavigationRailDestination(
        selectedIcon: Icon(Icons.person),
        icon: Icon(Icons.person_outline),
        label: Text('我的'),
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, obj) async {
        onBackPressed();
      },
      child: LayoutBuilder(
        builder: (context, _) {
          final isPortrait = Utils.isPortrait(context);
          return Scaffold(
            body: Row(children: [
              if (!isPortrait)
                StreamBuilder(
                    initialData: _selectedIndex,
                    stream: _indexSctream.stream,
                    builder: (_, snapshot) => Padding(
                          padding: EdgeInsets.only(
                              top: Platform.isMacOS ? 25.0 : 10.0),
                          child: NavigationRail(
                            destinations: railDestinations,
                            selectedIndex: snapshot.data!,
                            onDestinationSelected: onDestinationSelected,
                            labelType: NavigationRailLabelType.none,
                            extended: true,
                          ),
                        )),
              if (!isPortrait) const VerticalDivider(width: 1),
              if (Utils.isWideLandscape(context)) const Spacer(),
              Expanded(
                flex: 8,
                child: Stack(
                  children: [
                    PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _contrller,
                      children: pages,
                    ),
                    if (isPortrait)
                      Positioned(
                        right: 16,
                        bottom: 16 + MediaQuery.of(context).padding.bottom,
                        child: _buildCapsuleNav(context),
                      ),
                  ],
                ),
              ),
              if (Utils.isWideLandscape(context)) const Spacer(),
            ]),
          );
        },
      ),
    );
  }

  /// 胶囊悬浮导航按钮：展开=主页/我的/发布三按钮，收起=仅刷新按钮（占据发布位置）
  Widget _buildCapsuleNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      // 我的 tab 强制展开（显示发布）；主页 tab 由滚动方向控制
      final isExpanded = _selectedIndex == 1
          ? true
          : _pageScrollController.isNavExpanded.value;
      final isLogin = GlobalData().isLogin;
      // 收起态仅在主页 tab 才可刷新
      final canRefresh = _selectedIndex == 0;

      // 阴影与背景分离：阴影放在外层固定圆角容器，避免 AnimatedSize
      // 过渡期间阴影呈现方形外框
      final BoxDecoration shadowDecoration = BoxDecoration(
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
      );
      final BoxDecoration capsuleDecoration = BoxDecoration(
        // 毛玻璃背景：半透明色让 BackdropFilter 的模糊可见
        // 日间 40% 白底，夜间 40% darkCardBg
        color: isDark
            ? const Color(0xFF161B1A).withValues(alpha: 0.40)
            : Colors.white.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
          width: 1,
        ),
      );

      // 展开态：主页 | 分隔线 | 我的 | 分隔线 | 发布
      // 收起态：仅刷新按钮（占据发布位置，容器宽度收缩）
      // AnimatedCrossFade 同时处理宽度过渡与内容淡入淡出,
      // 与背景容器过渡动画(280ms)协调,避免内容瞬间切换。
      final Widget capsuleChild = AnimatedCrossFade(
        duration: const Duration(milliseconds: 280),
        crossFadeState:
            isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _capsuleIconButton(
              icon: _selectedIndex == 0
                  ? Icons.home
                  : Icons.home_outlined,
              label: '主页',
              selected: _selectedIndex == 0,
              isDark: isDark,
              onTap: () => onDestinationSelected(0),
            ),
            _capsuleDivider(isDark),
            _capsuleIconButton(
              icon: _selectedIndex == 1
                  ? Icons.person
                  : Icons.person_outline,
              label: '我的',
              selected: _selectedIndex == 1,
              isDark: isDark,
              onTap: () => onDestinationSelected(1),
            ),
            if (isLogin) ...[
              _capsuleDivider(isDark),
              _capsuleActionButton(
                isDark: isDark,
                isExpanded: true,
                canRefresh: canRefresh,
              ),
            ],
          ],
        ),
        secondChild: _capsuleActionButton(
          isDark: isDark,
          isExpanded: false,
          canRefresh: canRefresh,
        ),
      );

      return DecoratedBox(
        decoration: shadowDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          // 毛玻璃：模糊按钮背后的内容，叠加半透明 capsuleDecoration
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: capsuleDecoration,
              child: capsuleChild,
            ),
          ),
        ),
      );
    });
  }

  /// 胶囊分隔线
  Widget _capsuleDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
    );
  }

  /// 胶囊最右边按钮：发布/刷新切换（图标与文字淡入淡出，无方形背景）
  Widget _capsuleActionButton({
    required bool isDark,
    required bool isExpanded,
    required bool canRefresh,
  }) {
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    // 用 Material + InkWell 让水波纹/高亮能正常显示：
    // 原结构 Container> InkWell，Container 的背景色（capsuleDecoration）
    // 会遮挡 InkWell 的水波纹，导致点击无视觉反馈。
    // 这里 Material 设为透明背景，水波纹用主题色淡色，确保可见。
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isExpanded
            ? _onPublish
            : (canRefresh ? _onRefresh : null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: isExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.add_circle_rounded,
                        size: 22,
                        color: activeColor,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: isExpanded ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 22,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 12,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: isExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: Text(
                        '发布',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: isExpanded ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: Text(
                        '刷新',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1,
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 胶囊内导航图标按钮
  Widget _capsuleIconButton({
    required IconData icon,
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final inactiveColor = isDark
        ? AppTheme.darkOutline
        : AppTheme.lightOnSurface.withValues(alpha: 0.55);
    // 与 _capsuleActionButton 一致：用 Material + InkWell 让水波纹可见，
    // 避免父级 Container 背景色遮挡视觉反馈
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: selected ? activeColor : inactiveColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onDestinationSelected(int index) {
    if (index == 0 && _selectedIndex == 0) {
      // 已在主页 tab 再次点击 → 回到顶部刷新
      _pageScrollController.setIndex(998);
    }
    _contrller.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
    _selectedIndex = index;
    _indexSctream.add(index);
  }
}
