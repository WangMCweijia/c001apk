import 'package:get/get.dart';

class ReturnTopController extends GetxController {
  RxInt index = 999.obs;
  // 底部导航栏可见性：true=显示, false=隐藏
  RxBool navBarVisible = true.obs;

  void setIndex(int index) {
    this.index.value = index;
  }

  void setNavBarVisible(bool visible) {
    if (navBarVisible.value != visible) {
      navBarVisible.value = visible;
    }
  }
}
