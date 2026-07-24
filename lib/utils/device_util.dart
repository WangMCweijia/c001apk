import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';

import '../constants/constants.dart';

class DeviceUtil {
  static bool isPreGetLoginParam = false;
  static bool isGetLoginParam = false;
  static bool isTryLogin = false;
  static bool isGetCaptcha = false;
  static bool isGetSmsLoginParam = false;
  static bool isGetSmsToken = false;

  static int? atme;
  static int? atcommentme;
  static int? feedlike;
  static int? contacts_follow;
  static int? message;
  static int notification = 0;

  static String SESSID = Constants.EMPTY_STRING;

  static String randHexString(int length, [bool toUpperCase = true]) {
    const chars = '0123456789abcdef';
    final hexString = StringBuffer();
    for (int i = 0; i < length; i++) {
      hexString.write(chars[Random().nextInt(chars.length)]);
    }

    return toUpperCase
        ? hexString.toString().toUpperCase()
        : hexString.toString();
  }

  static String randomMacAddress() {
    final macBytes = List<int>.generate(6, (_) => Random().nextInt(256));
    macBytes[0] = (macBytes[0] & 0xFE) | 0x02;
    return macBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  static String randomManufacturer() {
    const manufacturers = [
      'Samsung',
      'Google',
      'Huawei',
      'Xiaomi',
      'OnePlus',
      'Sony',
      'LG',
      'Motorola',
      'HTC',
      'Nokia',
      'Lenovo',
      'Asus',
      'ZTE',
      'Alcatel',
      'OPPO',
      'Vivo',
      'Realme'
    ];
    return manufacturers[Random().nextInt(manufacturers.length)];
  }

  static String randomBrand() {
    const brands = [
      'Samsung',
      'Google',
      'Huawei',
      'Xiaomi',
      'Redmi',
      'OnePlus',
      'Sony',
      'LG',
      'Motorola',
      'HTC',
      'Nokia',
      'Lenovo',
      'Asus',
      'ZTE',
      'Alcatel',
      'OPPO',
      'Vivo',
      'Realme'
    ];
    return brands[Random().nextInt(brands.length)];
  }

  static String randomDeviceModel() {
    return randHexString(6);
  }

  static String randomSdkInt() {
    return (Random().nextInt(14) + 21).toString();
  }

  static String randomAndroidVersionRelease() {
    const androidVersionReleases = [
      '5.0.1',
      '6.0',
      '7.0',
      '7.1.1',
      '8.0.0',
      '8.1.0',
      '9',
      '10',
      '11',
      '12',
      '13',
      '14',
      '15'
    ];
    return androidVersionReleases[
        Random().nextInt(androidVersionReleases.length)];
  }

  // ==================== 本机真实参数获取 ====================
  // 用于"参数"页默认识别本机参数。仅在 Android 平台可获取；
  // 桌面/模拟器等环境获取失败时回退到随机值。

  /// 获取本机制作商（manufacturer）
  static Future<String> realManufacturer() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final v = info.data['manufacturer'];
        if (v is String && v.isNotEmpty) {
          return _capitalize(v);
        }
      }
    } catch (_) {}
    return randomManufacturer();
  }

  /// 获取本机品牌（brand）
  static Future<String> realBrand() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final v = info.data['brand'];
        if (v is String && v.isNotEmpty) {
          return _capitalize(v);
        }
      }
    } catch (_) {}
    return randomBrand();
  }

  /// 获取本机机型（model）
  static Future<String> realModel() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final v = info.data['model'];
        if (v is String && v.isNotEmpty) {
          return v;
        }
      }
    } catch (_) {}
    return randomDeviceModel();
  }

  /// 获取本机构建号（buildNumber / id）
  static Future<String> realBuildNumber() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final v = info.data['id'];
        if (v is String && v.isNotEmpty) {
          return v;
        }
      }
    } catch (_) {}
    return randHexString(32);
  }

  /// 获取本机 SDK 版本号
  static Future<String> realSdkInt() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final v = info.data['version']['sdkInt'];
        if (v != null) {
          return v.toString();
        }
      }
    } catch (_) {}
    return randomSdkInt();
  }

  /// 获取本机 Android 版本号（release，如 "13" / "14"）
  static Future<String> realAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        final v = info.data['version']['release'];
        if (v is String && v.isNotEmpty) {
          return v;
        }
      }
    } catch (_) {}
    return randomAndroidVersionRelease();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
