import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import '../../../components/common_body.dart';
import '../../../pages/home/feed/home_feed_controller.dart';
import '../../../pages/home/home_page.dart' show TabType;
import '../../../pages/home/return_top_controller.dart';
import '../../../utils/storage_util.dart';
import '../../../utils/utils.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({
    super.key,
    required this.tabType,
  });

  final TabType tabType;

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final followType = GStorage.followType;

  late final _homeFeedController = Get.put(
    HomeFeedController(
      tabType: widget.tabType,
      installTime: GStorage.installTime,
      url: switch (widget.tabType) {
        TabType.FOLLOW => Utils.getFollowUrl(followType),
        TabType.HOT => '/page?url=V9_HOME_TAB_RANKING',
        TabType.COOLPIC => '/page?url=V11_FIND_COOLPIC',
        _ => null,
      },
      title: switch (widget.tabType) {
        TabType.FOLLOW => Utils.getFollowTitle(followType),
        TabType.HOT => '热榜',
        TabType.COOLPIC => '酷图',
        _ => null,
      },
      followType: widget.tabType == TabType.FOLLOW ? GStorage.followType : null,
    ),
    tag: widget.tabType.name,
  );

  @override
  void dispose() {
    _homeFeedController.scrollController?.removeListener(() {});
    _homeFeedController.scrollController?.dispose();
    Get.delete<HomeFeedController>(
      tag: widget.tabType.name,
    );
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _homeFeedController.refreshKey = GlobalKey<RefreshIndicatorState>();
    _homeFeedController.scrollController = ScrollController();
    _homeFeedController.returnTopController =
        Get.find<ReturnTopController>(tag: 'home');

    _homeFeedController.returnTopController?.index.listen((index) {
      if (index == TabType.values.indexOf(widget.tabType)) {
        _homeFeedController.animateToTop();
      }
    });

    // 监听滚动方向控制胶囊导航展开/收起
    _homeFeedController.scrollController?.addListener(() {
      // 编程式回顶动画期间不处理，避免反向滚动把刚展开的胶囊折叠回去
      if (_homeFeedController.returnTopController?.isAnimatingToTop.value ==
          true) {
        return;
      }
      final ScrollDirection? direction =
          _homeFeedController.scrollController?.position.userScrollDirection;
      if (direction == ScrollDirection.forward) {
        // 向下滑动（内容下移，浏览上方内容）→ 展开三按钮
        _homeFeedController.returnTopController?.setNavExpanded(true);
      } else if (direction == ScrollDirection.reverse) {
        // 向上滑动（内容上移，浏览下方内容）→ 收起为刷新按钮
        _homeFeedController.returnTopController?.setNavExpanded(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: commonBody(_homeFeedController),
    );
  }
}
