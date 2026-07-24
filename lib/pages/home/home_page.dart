import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../pages/home/app/app_list_page.dart';
import '../../pages/home/feed/home_feed_page.dart';
import '../../pages/home/return_top_controller.dart';
import '../../pages/home/topic/home_topic_page.dart';
import '../../utils/utils.dart';

// ignore: constant_identifier_names
enum TabType { FOLLOW, APP, FEED, HOT, TOPIC, PRODUCT, COOLPIC, NONE }

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
    TabType.FOLLOW: '关注',
    TabType.APP: 'APP',
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
    const HomeFeedPage(tabType: TabType.FOLLOW),
    if (Platform.isAndroid) const AppListPage(),
    const HomeFeedPage(tabType: TabType.FEED),
    const HomeFeedPage(tabType: TabType.HOT),
    const HomeTopicPage(tabType: TabType.TOPIC),
    const HomeTopicPage(tabType: TabType.PRODUCT),
    const HomeFeedPage(tabType: TabType.COOLPIC),
  ];

  void scrollToTop(int index) {
    _pageScrollController.setIndex(Platform.isAndroid
        ? index
        : index == 0
            ? 0
            : index + 1);
  }

  @override
  void initState() {
    super.initState();

    _tabList.removeLast();
    if (!Platform.isAndroid) {
      _tabList.removeAt(1);
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        title: TabBar(
          controller: _tabController,
          tabs: _tabList,
          isScrollable: true,
          tabAlignment: Utils.isWideLandscape(context)
              ? TabAlignment.center
              : TabAlignment.startOffset,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          indicatorSize: TabBarIndicatorSize.label,
          dividerHeight: 0,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.6),
          indicatorColor: colorScheme.onPrimary,
          onTap: (index) {
            if (!_tabController.indexIsChanging) {
              scrollToTop(index);
            }
          },
        ),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed('/search'),
            icon: Icon(Icons.search, color: colorScheme.onPrimary),
            tooltip: '搜索',
          )
        ],
      ),
      body: TabBarView(controller: _tabController, children: _pages),
    );
  }
}
