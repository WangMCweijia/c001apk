import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pages/home/app/app_list_page.dart';
import '../../pages/home/feed/home_feed_page.dart';
import '../../pages/home/return_top_controller.dart';
import '../../pages/home/topic/home_topic_page.dart';
import '../../utils/app_theme.dart';
import '../../utils/utils.dart';

// ignore: constant_identifier_names
enum TabType { APP, FOLLOW, FEED, HOT, TOPIC, PRODUCT, COOLPIC, NONE }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  final ReturnTopController _pageScrollController =
      Get.find<ReturnTopController>(tag: 'home');
  // late final _config = Provider.of<AppConfigProvider>(context, listen: false);
  // late bool _showFab = true; //_config.isLogin;

  static const _tabNames = {
    TabType.APP: 'APP',
    TabType.FOLLOW: '关注',
    TabType.FEED: '头条',
    TabType.HOT: '热榜',
    TabType.TOPIC: '话题',
    TabType.PRODUCT: '产品',
    TabType.COOLPIC: '酷图',
    TabType.NONE: '',
  };
  final _tabList = TabType.values
      .map((type) => Tab(text: _tabNames[type] ?? type.name))
      .toList();

  final _pages = [
    if (Platform.isAndroid) const AppListPage(),
    const HomeFeedPage(tabType: TabType.FOLLOW),
    const HomeFeedPage(tabType: TabType.FEED),
    const HomeFeedPage(tabType: TabType.HOT),
    const HomeTopicPage(tabType: TabType.TOPIC),
    const HomeTopicPage(tabType: TabType.PRODUCT),
    const HomeFeedPage(tabType: TabType.COOLPIC),
  ];

  void scrollToTop(int index) {
    // 非 Android 平台移除了 APP 项，tab index 需 +1 映射到 TabType.values 索引
    _pageScrollController.setIndex(Platform.isAndroid ? index : index + 1);
  }

  @override
  void initState() {
    super.initState();

    _tabList.removeLast();
    if (!Platform.isAndroid) {
      _tabList.removeAt(0);
    }

    _tabController = TabController(
      vsync: this,
      initialIndex: Platform.isAndroid ? 2 : 1,
      length: _tabList.length,
    );

    _pageScrollController.index.listen((index) {
      if (index == 998) {
        scrollToTop(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // AppBar 背景渐变
    final appBarGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppTheme.darkBg, AppTheme.darkBgGradientEnd]
          : [AppTheme.lightBgGradientStart, AppTheme.lightBgGradientEnd],
    );
    // Tab 选中色（浅色 AppBar 上用深绿，深色 AppBar 上用荧光绿）
    final labelColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    final unselectedColor = isDark
        ? AppTheme.darkOutline
        : AppTheme.lightOnSurface.withValues(alpha: 0.55);
    final indicatorColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: appBarGradient),
        ),
        titleTextStyle: TextStyle(
          color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        title: TabBar(
          controller: _tabController,
          tabs: _tabList,
          isScrollable: true,
          tabAlignment: Utils.isWideLandscape(context)
              ? TabAlignment.center
              : TabAlignment.startOffset,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          indicatorSize: TabBarIndicatorSize.label,
          dividerHeight: 0,
          labelColor: labelColor,
          unselectedLabelColor: unselectedColor,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: indicatorColor),
            insets: const EdgeInsets.symmetric(horizontal: 8),
          ),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          onTap: (index) {
            if (!_tabController.indexIsChanging) {
              scrollToTop(index);
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed('/search'),
            icon: Icon(
              Icons.search,
              color: isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary,
            ),
            tooltip: '搜索',
          )
        ],
      ),
      body: TabBarView(controller: _tabController, children: _pages),
    );
  }
}
