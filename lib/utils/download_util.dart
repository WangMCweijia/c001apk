import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path_provider/path_provider.dart';
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
      // 会自动注入官方酷安客户端全套请求头。
      // 实测：请求头并非关键，XMP 标识为 MotionPhoto 但 MP4 视频段被剥离。
      // 尝试方案：先用原 URL 下载，若 XMP 显示为实况图但 MP4 段缺失，
      // 则依次尝试常见实况图 URL 变体，寻找能返回完整数据的源
      final Dio dio = Request.dio;
      Future<Response> fetch(String url) => dio.get(url,
          options: Options(
            responseType: ResponseType.bytes,
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Referer': 'https://www.coolapk.com/',
              // 明确接受视频类型，可能影响服务端决策
              'Accept':
                  'image/avif,image/webp,image/apng,image/svg+xml,image/*,video/mp4,video/*,*/*;q=0.8',
            },
          ));
      for (int index = 0; index < urlList.length; index++) {
        final String originalUrl = urlList[index];
        // 第一步：用原 URL 下载
        Response response = await fetch(originalUrl);
        List<int> bytes = response.data as List<int>;
        bool hasMp4 = _hasMp4Trailer(bytes);
        bool hasMotionXmp = _hasMotionPhotoXmp(bytes);
        String usedUrl = originalUrl;
        // 第二步：若 XMP 标识为实况图但 MP4 段缺失，尝试 URL 变体
        if (!hasMp4 && hasMotionXmp && originalUrl.endsWith('.jpg')) {
          final List<String> variants = [
            // 1. .motion.jpg 后缀（实况图专用）
            '${originalUrl.substring(0, originalUrl.length - 4)}.motion.jpg',
            // 2. 直接 .mp4 后缀（视频段独立存储）
            '${originalUrl.substring(0, originalUrl.length - 4)}.mp4',
            // 3. 路径中插入 /motion/
            if (originalUrl.contains('/feed/'))
              originalUrl.replaceFirst('/feed/', '/feed/motion/'),
            // 4. 添加查询参数 ?type=original
            if (!originalUrl.contains('?'))
              '$originalUrl?type=original',
          ];
          for (final String tryUrl in variants) {
            try {
              final Response r = await fetch(tryUrl);
              final List<int> b = r.data as List<int>;
              final bool bHasMp4 = _hasMp4Trailer(b);
              final bool bHasXmp = _hasMotionPhotoXmp(b);
              debugPrint(
                  '[download] variant=$tryUrl size=${b.length} hasMp4=$bHasMp4 hasXmp=$bHasXmp');
              // 找到含 MP4 视频段的变体立即采用
              if (bHasMp4) {
                bytes = b;
                response = r;
                hasMp4 = true;
                hasMotionXmp = bHasXmp;
                usedUrl = tryUrl;
                break;
              }
              // 否则取体积最大的变体（可能仍是静态图，但更大说明更接近原图）
              // 体积明显大于原 URL（如 >100KB）的变体值得采用
              if (b.length > bytes.length && b.length > 100 * 1024) {
                bytes = b;
                response = r;
                hasMotionXmp = bHasXmp;
                usedUrl = tryUrl;
              }
            } catch (e) {
              // 候选 URL 失败（404 等），继续尝试下一个
              debugPrint('[download] variant $tryUrl failed: $e');
            }
          }
        }
        // 最终基于采用的 bytes 重新计算所有标识，确保 Toast 准确
        hasMp4 = _hasMp4Trailer(bytes);
        hasMotionXmp = _hasMotionPhotoXmp(bytes);
        final int? contentLength = int.tryParse(
            response.headers.value('content-length') ?? '');
        debugPrint(
            '[download] url=$usedUrl originalUrl=$originalUrl size=${bytes.length} contentLength=$contentLength hasMp4=$hasMp4 hasMotionXmp=$hasMotionXmp');
        final String picName = originalUrl.split('/').last;
        // 判断变体返回的是否为纯 MP4 视频文件（用于提示与保存路径）
        // MP4 文件起始处有 ftyp box（前 64 字节内）
        // 但有些 MP4 在 ftyp 前可能有其他 box（如 free/skip），扩展搜索到 4KB
        final bool isPureMp4 = bytes.length >= 16 && () {
              // JPEG 起始标识 0xFF 0xD8，若是 JPEG 则不是纯 MP4
              if (bytes[0] == 0xFF && bytes[1] == 0xD8) return false;
              final int limit =
                  bytes.length > 4096 ? 4096 : bytes.length;
              for (int i = 0; i < limit - 8; i++) {
                if (bytes[i] == 0x66 &&
                    bytes[i + 1] == 0x74 &&
                    bytes[i + 2] == 0x79 &&
                    bytes[i + 3] == 0x70) {
                  return true;
                }
              }
              return false;
            }();

        if (Utils.isDesktop) {
          // 纯 MP4 时让文件扩展名匹配类型
          final String saveName = isPureMp4 && picName.endsWith('.jpg')
              ? '${picName.substring(0, picName.length - 4)}.mp4'
              : picName;
          String? filePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save',
            fileName: saveName,
            type: isPureMp4 ? FileType.video : FileType.image,
          );

          if (filePath == null) {
            SmartDialog.dismiss();
            return;
          }

          File(filePath).writeAsBytesSync(response.data);
        } else {
          // 移动端：纯 MP4 走视频保存（saveFile 需要文件路径），JPEG 走图片保存
          if (isPureMp4) {
            // SaverGallery.saveFile 需要 filePath，先把 bytes 写入临时文件
            final String mp4Name = picName.endsWith('.jpg')
                ? '${picName.substring(0, picName.length - 4)}.mp4'
                : picName;
            final Directory tmpDir = await getTemporaryDirectory();
            final String tmpPath = '${tmpDir.path}/$mp4Name';
            await File(tmpPath).writeAsBytes(bytes);
            final SaveResult result = await SaverGallery.saveFile(
              filePath: tmpPath,
              fileName: mp4Name,
              androidRelativePath: "Movies/c001apk-flutter",
              skipIfExists: true,
            );
            // 保存完成后清理临时文件
            try {
              await File(tmpPath).delete();
            } catch (_) {}
            if (result.errorMessage != null) {
              SmartDialog.dismiss();
              SmartDialog.showToast('${index + 1}: ${result.errorMessage}');
            }
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
        }

        if (index == urlList.length - 1) {
          SmartDialog.dismiss();
          final String sizeStr = _formatBytes(bytes.length);
          final String label;
          if (isPureMp4) {
            // 变体返回纯 MP4 视频文件（变体 .mp4 命中，URL 单独指向视频）
            label = '已保存（实况图视频 $sizeStr）';
          } else if (hasMp4) {
            // 完整 Motion Photo：JPEG + MP4 视频
            label = '已保存（实况图 $sizeStr）';
          } else if (hasMotionXmp) {
            // XMP 标识为实况图，但 MP4 视频段缺失
            if (usedUrl != originalUrl) {
              label = '已保存（实况图静态帧 $sizeStr，已尝试变体仍无视频）';
            } else {
              label = '已保存（实况图静态帧 $sizeStr，视频未下载）';
            }
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

  /// 检查字节流中是否包含 MP4 ftyp box，判断是否为实况图视频数据
  /// 适用三种情况：
  ///   1. 完整 Motion Photo = JPEG + 末尾内嵌 MP4
  ///   2. 纯 MP4 视频（变体返回的 .mp4 文件）
  ///   3. JPEG + MP4 但 EOI 标记在 MP4 内部也出现（取 EOI 之后的位置可能错位）
  /// 策略：同时从头部（纯 MP4 情况）和 JPEG EOI 之后（Motion Photo 情况）搜索
  static bool _hasMp4Trailer(List<int> bytes) {
    if (bytes.length < 12) return false;
    // ftyp box 的 ASCII：0x66 0x74 0x79 0x70
    bool matchAt(int i) =>
        i >= 0 &&
        i + 3 < bytes.length &&
        bytes[i] == 0x66 &&
        bytes[i + 1] == 0x74 &&
        bytes[i + 2] == 0x79 &&
        bytes[i + 3] == 0x70;
    // 情况 2：纯 MP4，ftyp 通常在文件开头前 64 字节内
    // 扩展到 4KB 以兼容 ftyp 前有 free/skip box 的 MP4 文件
    final int headLimit = bytes.length > 4096 ? 4096 : bytes.length;
    for (int i = 0; i < headLimit - 8; i++) {
      if (matchAt(i)) return true;
    }
    // 情况 1/3：完整 Motion Photo，JPEG EOI 之后是 MP4
    // 找最后一个 JPEG EOI (0xFF 0xD9)，从其后搜索整个 MP4 段
    int searchStart = 0;
    for (int i = bytes.length - 2; i >= 0; i--) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
        searchStart = i + 2;
        break;
      }
    }
    for (int i = searchStart; i < bytes.length - 8; i++) {
      if (matchAt(i)) return true;
    }
    return false;
  }

  /// 检查 XMP 元数据中是否包含 Motion Photo 标识
  /// 即使服务端剥离了 MP4 视频段，XMP 中 "MotionPhoto" 字段通常仍存在
  /// 据此可判断原图本身是否为实况图（与 hasMp4 区分下载是否完整）
  /// 注：变体返回纯 MP4 时此函数返回 false（MP4 不含 XMP）
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
