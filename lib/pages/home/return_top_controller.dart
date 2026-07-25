import 'package:get/get.dart';

class ReturnTopController extends GetxController {
  RxInt index = 999.obs;
  // 胶囊导航展开状态：true=三按钮(主页/我的/发布), false=仅刷新按钮
  RxBool isNavExpanded = true.obs;
  // 编程式回顶动画进行中标志：用于抑制滚动监听器在回顶期间把胶囊折叠回去
  RxBool isAnimatingToTop = false.obs;

  void setIndex(int index) {
    this.index.value = index;
  }

  void setNavExpanded(bool expanded) {
    if (isNavExpanded.value != expanded) {
      isNavExpanded.value = expanded;
    }
  }
}
