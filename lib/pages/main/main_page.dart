import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../pages/home/return_top_controller.dart';
import '../../pages/home/home_page.dart';
import '../../pages/main/main_controller.dart';
import '../../pages/message/message_page.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  final ReturnTopController _pageScrollController =
      Get.put(ReturnTopController(), tag: 'home');
  int _selectedIndex = 0;
  final _indexSctream = StreamController<int>.broadcast();
  late final MainController _mainController = Get.put(MainController());
  final _contrller = PageController();

  // 底部导航栏显隐动画
  late final AnimationController _navBarAnimCtr;
  late final Animation<Offset> _navBarOffset;
  late final Animation<double> _navBarOpacity;
  Worker? _navBarWorker;

  @override
  void initState() {
    super.initState();
    _mainController.checkLoginInfo();
    _navBarAnimCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navBarOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _navBarAnimCtr,
      curve: Curves.easeInOut,
    ));
    _navBarOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _navBarAnimCtr,
        curve: Curves.easeInOut,
      ),
    );
    _navBarAnimCtr.forward();
    // 监听滚动方向控制底部导航栏显隐
    _navBarWorker = ever(_pageScrollController.navBarVisible, (bool visible) {
      if (visible) {
        _navBarAnimCtr.forward();
      } else {
        _navBarAnimCtr.reverse();
      }
    });
  }

  @override
  void dispose() async {
    _navBarWorker?.dispose();
    _navBarAnimCtr.dispose();
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

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomePage(),
      MessagePage(),
    ];

    const barDestinations = <NavigationDestination>[
      NavigationDestination(
        selectedIcon: Icon(Icons.home),
        icon: Icon(Icons.home_outlined),
        label: '主页',
      ),
      NavigationDestination(
        selectedIcon: Icon(Icons.person),
        icon: Icon(Icons.person_outline),
        label: '我的',
      ),
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
          return Scaffold(
            extendBody: true,
            body: Row(children: [
              if (!Utils.isPortrait(context))
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
              if (!Utils.isPortrait(context)) const VerticalDivider(width: 1),
              if (Utils.isWideLandscape(context)) const Spacer(),
              Expanded(
                flex: 8,
                child: PageView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _contrller,
                  children: pages,
                ),
              ),
              if (Utils.isWideLandscape(context)) const Spacer(),
            ]),
            bottomNavigationBar: Utils.isPortrait(context)
                ? SlideTransition(
                    position: _navBarOffset,
                    child: FadeTransition(
                      opacity: _navBarOpacity,
                      child: StreamBuilder(
                        initialData: _selectedIndex,
                        stream: _indexSctream.stream,
                        builder: (_, snapshot) => NavigationBar(
                          destinations: barDestinations,
                          selectedIndex: snapshot.data!,
                          onDestinationSelected: onDestinationSelected,
                          labelBehavior:
                              NavigationDestinationLabelBehavior.onlyShowSelected,
                          height: 64,
                        ),
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  void onDestinationSelected(int index) {
    // 切换 tab 时始终显示底部导航栏
    _pageScrollController.setNavBarVisible(true);
    if (index == 0 && _selectedIndex == 0) {
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
