import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:file_picker/file_picker.dart';

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
      Dio dio = Dio();
      // 带上官方酷安 UA + Referer，避免服务端对非官方客户端返回剥离了
      // 视频数据的静态 JPEG（实况图 Motion Photo = JPEG + 末尾内嵌 MP4）。
      // Referer 模拟从酷安 web 页面发起的请求，部分 CDN 会校验。
      dio.options.headers['User-Agent'] = GStorage.userAgent;
      dio.options.headers['Referer'] = 'https://www.coolapk.com/';
      dio.options.headers['Accept'] =
          'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8';
      for (int index = 0; index < urlList.length; index++) {
        final Response response = await dio.get(urlList[index],
            options: Options(responseType: ResponseType.bytes));
        final List<int> bytes = response.data as List<int>;
        // 诊断：文件末尾是否包含 MP4 ftyp box（Motion Photo 标识）
        // 若包含则下载的是完整实况图，否则服务端返回的是剥离了视频的静态图
        final bool hasMp4 = _hasMp4Trailer(bytes);
        debugPrint(
            '[download] url=${urlList[index]} size=${bytes.length} hasMp4=$hasMp4');
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
          SmartDialog.showToast(
              hasMp4 ? '已保存（实况图 $sizeStr）' : '已保存（$sizeStr）');
        }
      }
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
    }
  }

  /// 检查字节流末尾是否包含 MP4 ftyp box，判断是否为 Motion Photo 实况图
  /// Motion Photo = JPEG + 末尾内嵌 MP4，MP4 起始处有 "ftyp" box
  static bool _hasMp4Trailer(List<int> bytes) {
    if (bytes.length < 12) return false;
    // 在末尾 1MB 范围内搜索 "ftyp" 标识（MP4 文件头特征）
    final int searchStart =
        bytes.length > 1024 * 1024 ? bytes.length - 1024 * 1024 : 0;
    // ftyp box 的 ASCII：0x66 0x74 0x79 0x70
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

  /// 格式化文件大小
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)}MB';
  }
}
