import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/settings/edittext_item.dart';
import '../../utils/app_theme.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

class ParamsPage extends StatefulWidget {
  const ParamsPage({super.key});

  @override
  State<ParamsPage> createState() => _ParamsPageState();
}

class _ParamsPageState extends State<ParamsPage> {
  late final _paramsController = Get.put(ParamsController());

  final manufacturerKey = GlobalKey<EdittextItemState>();
  final brandKey = GlobalKey<EdittextItemState>();
  final modelKey = GlobalKey<EdittextItemState>();
  final buildKey = GlobalKey<EdittextItemState>();
  final sdkKey = GlobalKey<EdittextItemState>();
  final androidKey = GlobalKey<EdittextItemState>();

  @override
  void dispose() {
    Get.delete<ParamsController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.gradientAppBar(
        context: context,
        title: const Text('参数'),
        leading: const BackButton(),
      ),
      body: _buildList(),
    );
  }

  Widget _buildList() {
    final brightness = Theme.of(context).brightness;
    final cardDeco = AppTheme.cardDecoration(brightness);
    final items = <Widget>[
      EdittextItem(
        title: '版本号',
        boxKey: SettingsBoxKey.versionName,
        needUpdateUserAgent: true,
        onChanged: _paramsController.onChanged,
      ),
      const EdittextItem(
        title: 'Api版本',
        boxKey: SettingsBoxKey.apiVersion,
      ),
      EdittextItem(
        title: '版本代码',
        boxKey: SettingsBoxKey.versionCode,
        needUpdateUserAgent: true,
        onChanged: _paramsController.onChanged,
      ),
      EdittextItem(
        key: manufacturerKey,
        title: '制作商',
        boxKey: SettingsBoxKey.manufacturer,
        needUpdateXAppDevice: true,
        onChanged: () => _paramsController.onChanged(true),
      ),
      EdittextItem(
        key: brandKey,
        title: '品牌',
        boxKey: SettingsBoxKey.brand,
        needUpdateUserAgent: true,
        needUpdateXAppDevice: true,
        onChanged: () => _paramsController.onChanged(true),
      ),
      EdittextItem(
        key: modelKey,
        title: '机型',
        boxKey: SettingsBoxKey.model,
        needUpdateUserAgent: true,
        needUpdateXAppDevice: true,
        onChanged: () => _paramsController.onChanged(true),
      ),
      EdittextItem(
        key: buildKey,
        title: '构建号',
        boxKey: SettingsBoxKey.buildNumber,
        needUpdateUserAgent: true,
        needUpdateXAppDevice: true,
        onChanged: () => _paramsController.onChanged(true),
      ),
      EdittextItem(
        key: sdkKey,
        title: 'SDK版本',
        boxKey: SettingsBoxKey.sdkInt,
      ),
      EdittextItem(
        key: androidKey,
        title: '安卓版本',
        boxKey: SettingsBoxKey.androidVersion,
        needUpdateUserAgent: true,
        onChanged: _paramsController.onChanged,
      ),
      Obx(
        () => ListTile(
          title: const Text('用户代理'),
          subtitle: Text(_paramsController.userAgent.value),
          onTap: () => Utils.copyText(_paramsController.userAgent.value),
        ),
      ),
      Obx(
        () => ListTile(
          title: const Text('X-App设备'),
          subtitle: Text(_paramsController.xAppDevice.value),
          onTap: () => Utils.copyText(_paramsController.xAppDevice.value),
        ),
      ),
      ListTile(
        title: const Text('生成随机参数'),
        onTap: () async {
          await GStorage.regenerateRandomParams();
          manufacturerKey.currentState?.updateValue();
          brandKey.currentState?.updateValue();
          modelKey.currentState?.updateValue();
          buildKey.currentState?.updateValue();
          sdkKey.currentState?.updateValue();
          androidKey.currentState?.updateValue();
          _paramsController.onChanged(true);
        },
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) =>
          Container(decoration: cardDeco, child: items[index]),
    );
  }
}

class ParamsController extends GetxController {
  RxString userAgent = ''.obs;
  RxString xAppDevice = ''.obs;

  void onChanged([bool updateXAppDevice = false]) {
    userAgent.value = GStorage.userAgent;
    if (updateXAppDevice) {
      xAppDevice.value = GStorage.xAppDevice;
    }
  }

  @override
  void onInit() {
    super.onInit();
    onChanged(true);
  }
}
