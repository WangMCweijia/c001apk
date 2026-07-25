import 'dart:async';
import 'dart:io';

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

  /// 胶囊悬浮导航按钮：始终三按钮布局，最右边按钮在发布/刷新间切换
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

      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBg : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? AppTheme.darkCardBorder
                : AppTheme.lightCardBorder,
            width: 1,
          ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _capsuleIconButton(
              icon: _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
              label: '主页',
              selected: _selectedIndex == 0,
              isDark: isDark,
              onTap: () => onDestinationSelected(0),
            ),
            _capsuleDivider(isDark),
            _capsuleIconButton(
              icon: _selectedIndex == 1 ? Icons.person : Icons.person_outline,
              label: '我的',
              selected: _selectedIndex == 1,
              isDark: isDark,
              onTap: () => onDestinationSelected(1),
            ),
            if (isLogin) ...[
              _capsuleDivider(isDark),
              // 最右边按钮：展开=发布，收起=刷新（占据发布按钮位置）
              _capsuleActionButton(
                isDark: isDark,
                isExpanded: isExpanded,
                canRefresh: canRefresh,
              ),
            ],
          ],
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

  /// 胶囊最右边按钮：发布/刷新切换（图标与文字淡入淡出）
  Widget _capsuleActionButton({
    required bool isDark,
    required bool isExpanded,
    required bool canRefresh,
  }) {
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: isExpanded
          ? _onPublish
          : (canRefresh ? _onRefresh : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                    CurvedAnimation(
                        parent: animation, curve: Curves.easeInOutCubic),
                  ),
                  child: child,
                ),
              ),
              child: Icon(
                isExpanded
                    ? Icons.add_circle_rounded
                    : Icons.refresh_rounded,
                key: ValueKey(isExpanded ? 'publish' : 'refresh'),
                size: 22,
                color: activeColor,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: Text(
                isExpanded ? '发布' : '刷新',
                key: ValueKey(isExpanded ? 'publish_t' : 'refresh_t'),
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
    return InkWell(
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
