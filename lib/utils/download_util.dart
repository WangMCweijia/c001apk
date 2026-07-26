import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:file_picker/file_picker.dart';

import '../logic/network/request.dart';
import '../utils/storage_util.dart';
import '../utils/utils.dart';

/// From Pilipala
class DownloadUtils {
  // 获取存储权限
  static Future<bool> requestStoragePer() async {
    await Permission.storage.request();
    PermissionStatus status = await Permission.storage.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      SmartDialog.show(
        useSystem: true,
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('存储权限未授权'),
            actions: [
              TextButton(
                onPressed: () async {
                  openAppSettings();
                },
                child: const Text('去授权'),
              )
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  // 获取相册权限
  static Future<bool> requestPhotoPer() async {
    await Permission.photos.request();
    PermissionStatus status = await Permission.photos.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      SmartDialog.show(
        useSystem: true,
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('相册权限未授权'),
            actions: [
              TextButton(
                onPressed: () async {
                  openAppSettings();
                },
                child: const Text('去授权'),
              )
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  static Future<void> downloadImg(List<String> urlList) async {
    try {
      if (Platform.isAndroid &&
          (await DeviceInfoPlugin().androidInfo).version.sdkInt <= 32) {
        if (!await requestStoragePer()) {
          return;
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (!await requestPhotoPer()) {
          return;
        }
      }

      SmartDialog.showLoading(msg: '保存中');
      // 使用项目全局 Dio 实例（Request.dio），其携带 ApiInterceptor，
      // 会自动注入官方酷安客户端全套请求头：
      //   User-Agent / X-Requested-With / X-App-Id / X-App-Token /
      //   X-App-Device / X-Api-Version / X-App-Version / X-App-Code /
      //   X-Sdk-Int / X-Sdk-Locale / X-App-Channel / X-App-Mode / Cookie
      // 实测：用裸 Dio() 只带 UA+Referer 下载实况图，服务端返回剥离了
      // MP4 视频段的静态 JPEG（23KB，XMP 标识仍为 MotionPhoto）。
      // 官方 CDN 可能校验 X-Requested-With 等头决定是否返回完整 Motion Photo。
      // 用全局 Dio 实例下载，并在单次请求中放宽超时（实况图体积较大）
      final Dio dio = Request.dio;
      for (int index = 0; index < urlList.length; index++) {
        final Response response = await dio.get(urlList[index],
            options: Options(
              responseType: ResponseType.bytes,
              // 实况图含视频，体积可能数 MB，放宽超时
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Referer': 'https://www.coolapk.com/',
                'Accept':
                    'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
              },
            ));
        final List<int> bytes = response.data as List<int>;
        // 诊断：文件末尾是否包含 MP4 ftyp box（Motion Photo 标识）
        // 若包含则下载的是完整实况图，否则服务端返回的是剥离了视频的静态图
        final bool hasMp4 = _hasMp4Trailer(bytes);
        final bool hasMotionXmp = _hasMotionPhotoXmp(bytes);
        debugPrint(
            '[download] url=${urlList[index]} size=${bytes.length} hasMp4=$hasMp4 hasMotionXmp=$hasMotionXmp');
        final String picName = urlList[index].split('/').last;

        if (Utils.isDesktop) {
          String? filePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Image',
            fileName: picName,
            type: FileType.image,
          );

          if (filePath == null) {
            SmartDialog.dismiss();
            return;
          }

          File(filePath).writeAsBytesSync(response.data);
        } else {
          final SaveResult result = await SaverGallery.saveImage(
            Uint8List.fromList(response.data),
            fileName: picName,
            androidRelativePath: "Pictures/c001apk-flutter",
            skipIfExists: true,
          );

          if (result.errorMessage != null) {
            SmartDialog.dismiss();
            SmartDialog.showToast('${index + 1}: ${result.errorMessage}');
          }
        }

        if (index == urlList.length - 1) {
          SmartDialog.dismiss();
          final String sizeStr = _formatBytes(bytes.length);
          final String label;
          if (hasMp4) {
            // 完整 Motion Photo：JPEG + MP4 视频
            label = '已保存（实况图 $sizeStr）';
          } else if (hasMotionXmp) {
            // XMP 标识为实况图，但 MP4 视频段缺失：服务端剥离了视频数据
            label = '已保存（实况图静态帧 $sizeStr，视频未下载）';
          } else {
            label = '已保存（$sizeStr）';
          }
          SmartDialog.showToast(label);
        }
      }
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
    }
  }

  /// 检查字节流中是否包含 MP4 ftyp box，判断是否为 Motion Photo 实况图
  /// Motion Photo = JPEG + 末尾内嵌 MP4，MP4 起始处有 "ftyp" box
  static bool _hasMp4Trailer(List<int> bytes) {
    if (bytes.length < 12) return false;
    // 定位 JPEG EOI (0xFF 0xD9) 之后的位置：JPEG 数据结束后即为内嵌 MP4
    // JPEG 中可能含多个 0xFF 0xD9（EXIF 缩略图），取最后一个作为真实 EOI
    int searchStart = 0;
    for (int i = bytes.length - 2; i >= 0; i--) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
        searchStart = i + 2;
        break;
      }
    }
    // 在 JPEG 数据结束后搜索 MP4 ftyp box（Motion Photo 视频段起始）
    // ftyp box 的 ASCII：0x66 0x74 0x79 0x70
    // 修复：原只在末尾 1MB 搜索，JPEG 较大时 ftyp 不在末尾 1MB 内导致漏判
    for (int i = searchStart; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x66 &&
          bytes[i + 1] == 0x74 &&
          bytes[i + 2] == 0x79 &&
          bytes[i + 3] == 0x70) {
        return true;
      }
    }
    return false;
  }

  /// 检查 XMP 元数据中是否包含 Motion Photo 标识
  /// 即使服务端剥离了 MP4 视频段，XMP 中 "MotionPhoto" 字段通常仍存在
  /// 据此可判断原图本身是否为实况图（与 hasMp4 区分下载是否完整）
  static bool _hasMotionPhotoXmp(List<int> bytes) {
    // XMP 在 JPEG APP1 段中，通常位于文件头部 64KB 内
    // "MotionPhoto" 的 ASCII：M o t i o n P h o t o
    final int limit = bytes.length > 65536 ? 65536 : bytes.length;
    for (int i = 0; i < limit - 11; i++) {
      if (bytes[i] == 0x4D && // M
          bytes[i + 1] == 0x6F && // o
          bytes[i + 2] == 0x74 && // t
          bytes[i + 3] == 0x69 && // i
          bytes[i + 4] == 0x6F && // o
          bytes[i + 5] == 0x6E && // n
          bytes[i + 6] == 0x50 && // P
          bytes[i + 7] == 0x68 && // h
          bytes[i + 8] == 0x6F && // o
          bytes[i + 9] == 0x74 && // t
          bytes[i + 10] == 0x6F) { // o
        return true;
      }
    }
    return false;
  }

  /// 格式化文件大小
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)}MB';
  }
}
