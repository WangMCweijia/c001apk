import 'dart:math';

import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:get/get_navigation/src/dialog/dialog_route.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/cards/app_info_card.dart';
import '../../components/sticky_sliver_to_box_adapter.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/app/app_content.dart';
import '../../pages/app/app_controller.dart';
import '../../pages/home/return_top_controller.dart';
import '../../utils/device_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/menu_labels.dart';
import '../../utils/app_theme.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';
import '../feed/reply/reply_page.dart';

// ignore: constant_identifier_names
enum AppMenuItem { Copy, Share, Follow, Block }

enum AppType { reply, dateline, hot }

class AppPage extends StatefulWidget {
  const AppPage({super.key});

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> with TickerProviderStateMixin {
  final String _packageName = Get.parameters['packageName'].orEmpty;
  String? _url;

  late ReturnTopController _returnTopController;

  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController =
      TabController(vsync: this, length: 3);
  final _tabs =
      ['最近回复', '最新发布', '热度排序'].map((title) => Tab(text: title)).toList();

  late final String _random = DeviceUtil.randHexString(8);

  @override
  void initState() {
    super.initState();
    _returnTopController =
        Get.put(ReturnTopController(), tag: _packageName + _random);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(() {});
    _scrollController.dispose();
    Get.delete<ReturnTopController>(tag: _packageName + _random);
    super.dispose();
  }

  Widget _buildAppInfo(AppController controller) {
    switch (controller.appState.value) {
      case Empty():
        return GestureDetector(
          onTap: controller.regetData,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: const Text('EMPTY'),
          ),
        );
      case Error():
        return GestureDetector(
          onTap: controller.regetData,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10.0),
            child: Text((controller.appState.value as Error).errMsg),
          ),
        );
      case Success():
        return AppInfoCard(
          data: (controller.appState.value as Success).response!,
          onDownloadApk: controller.entityType == 'apk'
              ? (id, versionName, versionCode) async {
                  if (!_url.isNullOrEmpty) {
                    Utils.onDownloadFile(
                      _url!,
                      '${controller.appName}-$versionName-$versionCode.apk',
                    );
                  } else {
                    _url = await Utils.onGetDownloadUrl(
                      controller.appName!,
                      _packageName,
                      id,
                      versionName,
                      versionCode,
                    );
                  }
                }
              : null,
        );
    }
    return const CircularProgressIndicator();
  }

  /// 点击胶囊刷新按钮：回到顶部并刷新当前 tab
  /// 点击瞬间立即展开为发布按钮，无需等待刷新完成
  void _onAppRefresh() {
    _returnTopController.setNavExpanded(true);
    _returnTopController.setIndex(_tabController.index);
  }

  /// 点击胶囊发布按钮
  void _onAppPublish(AppController controller) {
    Navigator.of(context).push(
      GetDialogRoute(
        pageBuilder: (buildContext, animation, secondaryAnimation) {
          return ReplyPage(
            title: controller.appName,
            targetType: 'apk',
            targetId:
                '${1000000000 + int.parse(controller.id ?? '4599')}',
          );
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

  /// 胶囊悬浮按钮：展开=发布，收起=刷新
  Widget _buildAppCapsule(BuildContext context, AppController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final isExpanded = _returnTopController.isNavExpanded.value;
      final activeColor = isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1.0).animate(
              CurvedAnimation(
                  parent: animation, curve: Curves.easeInOutCubic),
            ),
            child: child,
          ),
        ),
        child: isExpanded
            ? FloatingActionButton(
                key: const ValueKey('publish'),
                heroTag: null,
                onPressed: () => _onAppPublish(controller),
                tooltip: 'Create Feed',
                backgroundColor: isDark ? AppTheme.darkCardBg : Colors.white,
                foregroundColor: activeColor,
                child: const Icon(Icons.add),
              )
            : FloatingActionButton(
                key: const ValueKey('refresh'),
                heroTag: null,
                onPressed: _onAppRefresh,
                tooltip: 'Refresh',
                backgroundColor: isDark ? AppTheme.darkCardBg : Colors.white,
                foregroundColor: activeColor,
                child: const Icon(Icons.refresh_rounded),
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      tag: _packageName + _random,
      init: AppController(packageName: _packageName),
      initState: (state) {
        _scrollController.addListener(() {
          state.controller?.scrollRatio.value =
              min(1.0, _scrollController.offset.round() / 75.0);
        });
      },
      builder: (controller) => Scaffold(
        floatingActionButton: Obx(
          () => controller.appState.value is Success &&
                  GlobalData().isLogin &&
                  !controller.isBlocked &&
                  controller.commentStatus == 1
              ? _buildAppCapsule(context, controller)
              : const SizedBox(),
        ),
        appBar: PreferredSize(
          preferredSize: const Size(double.infinity, 56),
          child: Obx(
            () => AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor:
                  AppTheme.appBarForeground(Theme.of(context).brightness),
              titleTextStyle: TextStyle(
                color:
                    AppTheme.appBarForeground(Theme.of(context).brightness),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient:
                      AppTheme.appBarGradient(Theme.of(context).brightness),
                ),
              ),
              title: !controller.appName.isNullOrEmpty &&
                      controller.scrollRatio.value == 1
                  ? Text(controller.appName!)
                  : null,
              actions: controller.appState.value is Success
                  ? [
                      if (!controller.isBlocked &&
                          controller.commentStatus == 1)
                        IconButton(
                          onPressed: () => Get.toNamed('/search', parameters: {
                            'title': controller.appName!,
                            'pageType': 'apk',
                            'pageParam': controller.id!,
                          }),
                          icon: const Icon(Icons.search),
                          tooltip: 'Search',
                        ),
                      PopupMenuButton(
                        onSelected: (AppMenuItem item) {
                          switch (item) {
                            case AppMenuItem.Copy:
                              Utils.copyText(Utils.getShareUri(
                                      controller.id!, ShareType.apk)
                                  .toString());
                              break;
                            case AppMenuItem.Share:
                              SharePlus.instance.share(ShareParams(
                                  uri: Utils.getShareUri(
                                      controller.id!, ShareType.apk)));
                              break;
                            case AppMenuItem.Follow:
                              if (GlobalData().isLogin) {
                                controller.onGetFollow(
                                  controller.isFollow,
                                  controller.isFollow
                                      ? '/v6/apk/unFollow'
                                      : '/v6/apk/follow',
                                  id: controller.id,
                                );
                              }
                              break;
                            case AppMenuItem.Block:
                              GStorage.onBlock(
                                controller.appName,
                                isUser: false,
                                isDelete: controller.isBlocked,
                              );
                              controller.isBlocked = !controller.isBlocked;
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            AppMenuItem.values
                                .map((item) => PopupMenuItem<AppMenuItem>(
                                      value: item,
                                      child: Text(
                                        item == AppMenuItem.Block
                                            ? (controller.isBlocked
                                                ? '取消屏蔽'
                                                : '屏蔽')
                                            : item == AppMenuItem.Follow
                                                ? (controller.isFollow
                                                    ? '取消关注'
                                                    : '关注')
                                                : MenuLabels.of(item),
                                      ),
                                    ))
                                .toList(),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        body: Obx(
          () => controller.appState.value is Success
              ? ExtendedNestedScrollView(
                  controller: _scrollController,
                  onlyOneScrollInBody: true,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverToBoxAdapter(
                        child: _buildAppInfo(controller),
                      ),
                      if (!controller.isBlocked &&
                          controller.commentStatus == 1)
                        SliverOverlapAbsorber(
                          handle: ExtendedNestedScrollView
                              .sliverOverlapAbsorberHandleFor(context),
                          sliver: StickySliverToBoxAdapter(
                            child: Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: TabBar(
                                controller: _tabController,
                                labelColor: AppTheme.appBarForeground(
                                    Theme.of(context).brightness),
                                unselectedLabelColor:
                                    AppTheme.appBarForeground(
                                            Theme.of(context).brightness)
                                        .withValues(alpha: 0.6),
                                indicatorColor: AppTheme.appBarForeground(
                                    Theme.of(context).brightness),
                                tabs: _tabs,
                                onTap: (index) {
                                  if (!_tabController.indexIsChanging) {
                                    _returnTopController.setIndex(index);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      if (controller.isBlocked || controller.commentStatus != 1)
                        const SliverToBoxAdapter(
                          child: Divider(height: 1),
                        ),
                    ];
                  },
                  body: !controller.isBlocked && controller.commentStatus == 1
                      ? LayoutBuilder(builder: (context, _) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: ExtendedNestedScrollView
                                          .sliverOverlapAbsorberHandleFor(
                                              context)
                                      .layoutExtent ??
                                  0,
                            ),
                            child: TabBarView(
                              controller: _tabController,
                              children: AppType.values
                                  .map((item) => AppContent(
                                        random: _random,
                                        packageName: _packageName,
                                        appType: item,
                                        id: controller.id!,
                                      ))
                                  .toList(),
                            ),
                          );
                        })
                      : Center(
                          child: Text(controller.isBlocked
                              ? '${controller.appName} is Blocked'
                              : controller.commentStatusText!),
                        ),
                )
              : Center(child: _buildAppInfo(controller)),
        ),
      ),
    );
  }
}
