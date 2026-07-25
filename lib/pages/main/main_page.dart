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

  /// 胶囊悬浮导航按钮：展开时显示主页/我的/发布三按钮，收起时显示刷新按钮
  Widget _buildCapsuleNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      // 我的 tab 强制展开；主页 tab 由滚动方向控制
      final isExpanded = _selectedIndex == 1
          ? true
          : _pageScrollController.isNavExpanded.value;
      final isLogin = GlobalData().isLogin;
      // 收起态仅在主页 tab 才可刷新
      final canRefresh = _selectedIndex == 0;

      // 用 AnimatedCrossFade 让尺寸与透明度同步过渡，避免跳动
      return AnimatedCrossFade(
        duration: const Duration(milliseconds: 280),
        firstCurve: Curves.easeInOutCubic,
        secondCurve: Curves.easeInOutCubic,
        sizeCurve: Curves.easeInOutCubic,
        alignment: Alignment.center,
        crossFadeState: isExpanded
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: _buildExpandedCapsule(isDark, isLogin),
        secondChild: _buildCollapsedCapsule(isDark, canRefresh),
      );
    });
  }

  /// 展开态：胶囊包含主页/我的/发布三按钮
  Widget _buildExpandedCapsule(bool isDark, bool isLogin) {
    return Container(
      key: const ValueKey('expanded'),
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
          Container(
            width: 1,
            height: 24,
            color: isDark
                ? AppTheme.darkCardBorder
                : AppTheme.lightCardBorder,
          ),
          _capsuleIconButton(
            icon: _selectedIndex == 1 ? Icons.person : Icons.person_outline,
            label: '我的',
            selected: _selectedIndex == 1,
            isDark: isDark,
            onTap: () => onDestinationSelected(1),
          ),
          if (isLogin) ...[
            Container(
              width: 1,
              height: 24,
              color: isDark
                  ? AppTheme.darkCardBorder
                  : AppTheme.lightCardBorder,
            ),
            _capsulePublishButton(isDark),
          ],
        ],
      ),
    );
  }

  /// 收起态：单个刷新按钮
  Widget _buildCollapsedCapsule(bool isDark, bool canRefresh) {
    return Container(
      key: const ValueKey('collapsed'),
      height: 56,
      width: 56,
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
      child: IconButton(
        onPressed: canRefresh ? _onRefresh : null,
        icon: Icon(
          Icons.refresh_rounded,
          color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
        ),
        tooltip: '刷新',
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

  /// 胶囊内发布按钮（强调色）
  Widget _capsulePublishButton(bool isDark) {
    final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: _onPublish,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_rounded,
              size: 22,
              color: activeColor,
            ),
            const SizedBox(height: 2),
            Text(
              '发布',
              style: TextStyle(
                fontSize: 10,
                height: 1,
                color: activeColor,
                fontWeight: FontWeight.w600,
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
