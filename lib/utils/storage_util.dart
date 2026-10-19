import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/constants.dart';
import '../logic/model/fav_history/fav_history.dart';
import '../utils/device_util.dart';
import '../utils/global_data.dart';
import '../utils/token_util.dart';

class GStorage {
  static late final Box<dynamic> searchHistory;
  static late final Box<dynamic> historyFeed;
  static late final Box<dynamic> favFeed;
  static late final Box<dynamic> blackList;
  static late final Box<dynamic> settings;

  static ThemeMode getThemeMode() {
    switch (settings.get(SettingsBoxKey.selectedTheme, defaultValue: 0)) {
      case 0:
        return ThemeMode.system;

      case 1:
        return ThemeMode.light;

      case 2:
        return ThemeMode.dark;

      default:
        return ThemeMode.system;
    }
  }

  static Brightness getBrightness() {
    switch (settings.get(SettingsBoxKey.selectedTheme, defaultValue: 0)) {
      case 0:
        if (PlatformDispatcher.instance.platformBrightness ==
            Brightness.light) {
          return Brightness.dark;
        } else {
          return Brightness.light;
        }

      case 1:
        return Brightness.dark;

      case 2:
        return Brightness.light;

      default:
        return Brightness.dark;
    }
  }

  static void onDeleteFeed(String id, {bool isHistory = true}) {
    if (isHistory) {
      historyFeed.delete(id);
    } else {
      favFeed.delete(id);
    }
  }

  static bool checkFav(String id) {
    return favFeed.get(id) != null;
  }

  static bool checkHistory(String id) {
    return historyFeed.get(id) != null;
  }

  static bool checkUser(String uid) {
    List<String> userBlackList =
        blackList.get(BlackListBoxKey.userBlackList, defaultValue: <String>[]);
    return userBlackList.contains(_toString(uid));
  }

  static bool checkTopic(String topic) {
    List<String> topicBlackList =
        blackList.get(BlackListBoxKey.topicBlackList, defaultValue: <String>[]);
    return topicBlackList
            .firstWhereOrNull((keyword) => topic.contains(keyword)) !=
        null;
  }

  static String _toString(dynamic value) {
    return value is String ? value : value.toString();
  }

  static void onBlock(
    dynamic value, {
    bool isUser = true,
    bool isDelete = false,
    bool needToast = false,
  }) {
    List<String> dataList = blackList.get(
      isUser ? BlackListBoxKey.userBlackList : BlackListBoxKey.topicBlackList,
      defaultValue: <String>[],
    );
    if (!isDelete && dataList.contains(_toString(value))) {
      if (needToast) {
        SmartDialog.showToast('已存在');
      }
      return;
    }
    if (isDelete) {
      dataList = dataList.where((data) => data != _toString(value)).toList();
    } else {
      dataList.insert(0, _toString(value));
    }
    blackList.put(
      isUser ? BlackListBoxKey.userBlackList : BlackListBoxKey.topicBlackList,
      dataList,
    );
  }

  static Future<void> init() async {
    final Directory dir = await getApplicationSupportDirectory();
    final String path = dir.path;
    await Hive.initFlutter('$path/hive');
    regAdapter();
    searchHistory = await Hive.openBox('searchHistory');
    historyFeed = await Hive.openBox('historyFeed');
    favFeed = await Hive.openBox('favFeed');
    blackList = await Hive.openBox('blackList');
    settings = await Hive.openBox('settings');

    if (installTime.isEmpty) {
      setInstallTime(DateTime.now().millisecondsSinceEpoch.toString());
      await regenerateParams();
    }
    await migrateProtocolParams();

    GlobalData().isLogin = isLogin;
    GlobalData().uid = uid;
    GlobalData().username = username;
    GlobalData().token = token;
    GlobalData().SESSID =
        settings.get(SettingsBoxKey.apiSession, defaultValue: '');
  }

  /// 自动升级存量客户端的协议版本与设备串结构（不重置用户的 szlmId 和登录态）
  static Future<void> migrateProtocolParams() async {
    if (settings.get(SettingsBoxKey.protocolRevision, defaultValue: 0) >= 2) {
      return;
    }
    await settings.putAll({
      SettingsBoxKey.versionName: Constants.VERSION_NAME,
      SettingsBoxKey.versionCode: Constants.VERSION_CODE,
      SettingsBoxKey.apiVersion: Constants.API_VERSION,
    });
    fullSetUserAgent();
    await fullSetXAppDevice();
    await settings.put(SettingsBoxKey.protocolRevision, 2);
  }

  /// 支持直接填入 ShuzlmID 或粘贴官方酷安连点 5 次「复制 OAID」的完整多行/单行文本
  static String extractSzlmId(String raw) {
    final text = raw.replaceAll('﻿', '').trim();
    if (text.isEmpty) return '';
    final match = RegExp(
      r'ShuzlmID\s*[:：]\s*([A-Za-z0-9_+/.=-]{8,})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    if (text.contains('\n') || text.contains('\r') || text.contains(':')) {
      return '';
    }
    if (text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') {
      return '';
    }
    return text.replaceAll(';', '');
  }

  static void regAdapter() {
    Hive.registerAdapter(FavHistoryItemAdapter());
  }

  static Future<void> close() async {
    searchHistory.compact();
    searchHistory.close();
    historyFeed.compact();
    historyFeed.close();
    favFeed.compact();
    favFeed.close();
    blackList.compact();
    blackList.close();
    settings.compact();
    settings.close();
  }

  static void fullSetUserAgent() {
    setUserAgent(
        'Dalvik/2.1.0 (Linux; U; Android $androidVersion; $model $buildNumber) (#Build; $brand; $model; $buildNumber; $androidVersion) +CoolMarket/$versionName-$versionCode-${Constants.MODE}');
  }

  static Future<void> fullSetXAppDevice() async {
    final cleanSzlmId = extractSzlmId(szlmId);
    final firstField = cleanSzlmId.isNotEmpty
        ? cleanSzlmId
        : 'ca_${DeviceUtil.randHexString(32)}';
    final cleanManufacturer = manufacturer.replaceAll(';', '');
    final cleanBrand = brand.replaceAll(';', '');
    final cleanModel = model.replaceAll(';', '');
    final cleanBuild = buildNumber.replaceAll(';', '');
    setXAppDevice(await TokenUtils.encodeDevice(
        '$firstField; ; ; ; $cleanManufacturer; $cleanBrand; $cleanModel; $cleanBuild; ${Constants.DEFAULT_DEVICE_TAIL}'));
  }

  static Future<void> regenerateParams() async {
    setVersionName(Constants.VERSION_NAME);
    setApiVersion(Constants.API_VERSION);
    setVersionCode(Constants.VERSION_CODE);
    // 默认识别本机真实参数（Android 平台），获取失败回退随机值
    setManufacturer(await DeviceUtil.realManufacturer());
    setBrand(await DeviceUtil.realBrand());
    setModel(await DeviceUtil.realModel());
    setBuildNumber(await DeviceUtil.realBuildNumber());
    setSdkInt(await DeviceUtil.realSdkInt());
    setAndroidVersion(await DeviceUtil.realAndroidVersion());
    fullSetUserAgent();
    await fullSetXAppDevice();
  }

  /// 生成随机参数（保留旧行为，供"生成随机参数"按钮使用）
  static Future<void> regenerateRandomParams() async {
    setVersionName(Constants.VERSION_NAME);
    setApiVersion(Constants.API_VERSION);
    setVersionCode(Constants.VERSION_CODE);
    setManufacturer(DeviceUtil.randomManufacturer());
    setBrand(DeviceUtil.randomBrand());
    setModel(DeviceUtil.randomDeviceModel());
    setBuildNumber(DeviceUtil.randHexString(32));
    setSdkInt(DeviceUtil.randomSdkInt());
    setAndroidVersion(DeviceUtil.randomAndroidVersionRelease());
    fullSetUserAgent();
    await fullSetXAppDevice();
  }

  static bool get useMaterial {
    return settings.get(SettingsBoxKey.useMaterial, defaultValue: true);
  }

  static void setUseMaterial(bool value) {
    settings.put(SettingsBoxKey.useMaterial, value);
  }

  static int get staticColor {
    return settings.get(SettingsBoxKey.staticColor, defaultValue: 0);
  }

  static void setStaticColor(int value) {
    settings.put(SettingsBoxKey.staticColor, value);
  }

  static int get selectedTheme {
    return settings.get(SettingsBoxKey.selectedTheme, defaultValue: 0);
  }

  static void setSelectedTheme(int value) {
    settings.put(SettingsBoxKey.selectedTheme, value);
  }

  static String get szlmId {
    return settings.get(SettingsBoxKey.szlmId, defaultValue: '');
  }

  static void setSzlmId(String value) {
    settings.put(SettingsBoxKey.szlmId, extractSzlmId(value));
  }

  static double get fontScale {
    return settings.get(SettingsBoxKey.fontScale, defaultValue: 1.0);
  }

  static void setFontScale(double value) {
    settings.put(SettingsBoxKey.fontScale, value);
  }

  static int get followType {
    return settings.get(SettingsBoxKey.followType, defaultValue: 0);
  }

  static void setFollowType(int value) {
    settings.put(SettingsBoxKey.followType, value);
  }

  static int get imageQuality {
    return settings.get(SettingsBoxKey.imageQuality, defaultValue: 0);
  }

  static void setImageQuality(int value) {
    settings.put(SettingsBoxKey.imageQuality, value);
  }

  static bool get imageDim {
    return settings.get(SettingsBoxKey.imageDim, defaultValue: true);
  }

  static void setImageDim(bool value) {
    settings.put(SettingsBoxKey.imageDim, value);
  }

  static bool get openInBrowser {
    return settings.get(SettingsBoxKey.openInBrowser, defaultValue: false);
  }

  static void setOpenInBrowser(bool value) {
    settings.put(SettingsBoxKey.openInBrowser, value);
  }

  static bool get showSquare {
    return settings.get(SettingsBoxKey.showSquare, defaultValue: true);
  }

  static void setShowSquare(bool value) {
    settings.put(SettingsBoxKey.showSquare, value);
  }

  static bool get recordHistory {
    return settings.get(SettingsBoxKey.recordHistory, defaultValue: true);
  }

  static void setRecordHistory(bool value) {
    settings.put(SettingsBoxKey.recordHistory, value);
  }

  static bool get showEmoji {
    return settings.get(SettingsBoxKey.showEmoji, defaultValue: true);
  }

  static void setShowEmoji(bool value) {
    settings.put(SettingsBoxKey.showEmoji, value);
  }

  static bool get checkUpdate {
    return settings.get(SettingsBoxKey.checkUpdate, defaultValue: true);
  }

  static void setCheckUpdate(bool value) {
    settings.put(SettingsBoxKey.checkUpdate, value);
  }

  static String get installTime {
    return settings.get(SettingsBoxKey.installTime, defaultValue: '');
  }

  static void setInstallTime(String value) {
    settings.put(SettingsBoxKey.installTime, value);
  }

  static String get versionName {
    return settings.get(SettingsBoxKey.versionName, defaultValue: '');
  }

  static void setVersionName(String value) {
    settings.put(SettingsBoxKey.versionName, value);
  }

  static String get apiVersion {
    return settings.get(SettingsBoxKey.apiVersion, defaultValue: '');
  }

  static void setApiVersion(String value) {
    settings.put(SettingsBoxKey.apiVersion, value);
  }

  static String get versionCode {
    return settings.get(SettingsBoxKey.versionCode, defaultValue: '');
  }

  static void setVersionCode(String value) {
    settings.put(SettingsBoxKey.versionCode, value);
  }

  static String get manufacturer {
    return settings.get(SettingsBoxKey.manufacturer, defaultValue: '');
  }

  static void setManufacturer(String value) {
    settings.put(SettingsBoxKey.manufacturer, value);
  }

  static String get brand {
    return settings.get(SettingsBoxKey.brand, defaultValue: '');
  }

  static void setBrand(String value) {
    settings.put(SettingsBoxKey.brand, value);
  }

  static String get model {
    return settings.get(SettingsBoxKey.model, defaultValue: '');
  }

  static void setModel(String value) {
    settings.put(SettingsBoxKey.model, value);
  }

  static String get buildNumber {
    return settings.get(SettingsBoxKey.buildNumber, defaultValue: '');
  }

  static void setBuildNumber(String value) {
    settings.put(SettingsBoxKey.buildNumber, value);
  }

  static String get sdkInt {
    return settings.get(SettingsBoxKey.sdkInt, defaultValue: '');
  }

  static void setSdkInt(String value) {
    settings.put(SettingsBoxKey.sdkInt, value);
  }

  static String get androidVersion {
    return settings.get(SettingsBoxKey.androidVersion, defaultValue: '');
  }

  static void setAndroidVersion(String value) {
    settings.put(SettingsBoxKey.androidVersion, value);
  }

  static String get userAgent {
    return settings.get(SettingsBoxKey.userAgent, defaultValue: '');
  }

  static void setUserAgent(String value) {
    settings.put(SettingsBoxKey.userAgent, value);
  }

  static String get xAppDevice {
    return settings.get(SettingsBoxKey.xAppDevice, defaultValue: '');
  }

  static void setXAppDevice(String value) {
    settings.put(SettingsBoxKey.xAppDevice, value);
  }

  static bool get isLogin {
    return settings.get(SettingsBoxKey.isLogin, defaultValue: false);
  }

  static void setIsLogin(bool value) {
    settings.put(SettingsBoxKey.isLogin, value);
    GlobalData().isLogin = value;
  }

  static String get uid {
    return settings.get(SettingsBoxKey.uid, defaultValue: '');
  }

  static void setUid(String value) {
    settings.put(SettingsBoxKey.uid, value);
    GlobalData().uid = value;
  }

  static String get username {
    return settings.get(SettingsBoxKey.username, defaultValue: '');
  }

  static void setUsername(String value) {
    settings.put(SettingsBoxKey.username, value);
    GlobalData().username = value;
  }

  static String get token {
    return settings.get(SettingsBoxKey.token, defaultValue: '');
  }

  static void setToken(String value) {
    settings.put(SettingsBoxKey.token, value);
    GlobalData().token = value;
  }

  static String get userAvatar {
    return settings.get(SettingsBoxKey.userAvatar, defaultValue: '');
  }

  static void setUserAvatar(String value) {
    settings.put(SettingsBoxKey.userAvatar, value);
  }

  static int get exp {
    return settings.get(SettingsBoxKey.exp, defaultValue: 0);
  }

  static void setExp(int value) {
    settings.put(SettingsBoxKey.exp, value);
  }

  static int get nextExp {
    return settings.get(SettingsBoxKey.nextExp, defaultValue: 1);
  }

  static void setNextExp(int value) {
    settings.put(SettingsBoxKey.nextExp, value);
  }

  static int get level {
    return settings.get(SettingsBoxKey.level, defaultValue: 0);
  }

  static void setLevel(int value) {
    settings.put(SettingsBoxKey.level, value);
  }
}

class BlackListBoxKey {
  static const String userBlackList = 'userBlackList',
      topicBlackList = 'topicBlackList';
}

class SettingsBoxKey {
  static const String useMaterial = 'useMaterial',
      staticColor = 'staticColor',
      selectedTheme = 'selectedTheme',
      szlmId = 'szlmId',
      fontScale = 'fontScale',
      followType = 'followType',
      imageQuality = 'imageQuality',
      imageDim = 'imageDim',
      openInBrowser = 'openInBrowser',
      showSquare = 'showSquare',
      recordHistory = 'recordHistory',
      showEmoji = 'showEmoji',
      checkUpdate = 'checkUpdate',
      checkCount = 'checkCount',
      installTime = 'installTime',
      protocolRevision = 'protocolRevision',
      apiSession = 'apiSession',
      apiCaptchaValidate = 'apiCaptchaValidate',
      versionName = 'versionNamev',
      apiVersion = 'apiVersion',
      versionCode = 'versionCode',
      manufacturer = 'manufacturer',
      brand = 'brand',
      model = 'model',
      buildNumber = 'buildNumber',
      sdkInt = 'sdkInt',
      androidVersion = 'androidVersion',
      userAgent = 'userAgent',
      xAppDevice = 'xAppDevice',
      isLogin = 'isLogin',
      uid = 'uid',
      username = 'username',
      token = 'token',
      userAvatar = 'userAvatar',
      exp = 'exp',
      nextExp = 'nextExp',
      level = 'level';
}
