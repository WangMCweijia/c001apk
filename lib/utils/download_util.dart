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
        bool hasMp4 = _hasMp4Trailer(bytes) || _hasMp4MediaBox(bytes);
        bool hasMotionXmp = _hasMotionPhotoXmp(bytes);
        String usedUrl = originalUrl;
        // 第二步：若 XMP 标识为实况图但 MP4 段缺失，尝试 URL 变体
        // 注意：变体只有在确认含 MP4 视频段时才采用，
        // 否则保留原 URL 的下载结果（即便它是 23KB 静态图，至少保留 XMP 标识
        // 让用户知道这是实况图但视频被服务端剥离）。
        // 之前曾"变体体积大就采用"，结果变体返回了 1.34MB 的另一张静态图
        // （不含 XMP），反而丢失了原 XMP 标识，故改为只接受含 MP4 的变体。
        if (!hasMp4 && hasMotionXmp && originalUrl.endsWith('.jpg')) {
          final List<String> variants = [
            // 1. .motion.jpg 后缀（实况图专用）
            '${originalUrl.substring(0, originalUrl.length - 4)}.motion.jpg',
            // 2. 直接 .mp4 后缀（视频段独立存储）
            '${originalUrl.substring(0, originalUrl.length - 4)}.mp4',
            // 3. .live.jpg 后缀（另一种可能的实况图命名）
            '${originalUrl.substring(0, originalUrl.length - 4)}.live.jpg',
            // 4. .video.jpg 后缀
            '${originalUrl.substring(0, originalUrl.length - 4)}.video.jpg',
            // 5. 路径中插入 /motion/
            if (originalUrl.contains('/feed/'))
              originalUrl.replaceFirst('/feed/', '/feed/motion/'),
            // 6. 路径中插入 /video/
            if (originalUrl.contains('/feed/'))
              originalUrl.replaceFirst('/feed/', '/feed/video/'),
            // 7. 添加查询参数 ?type=original
            if (!originalUrl.contains('?'))
              '$originalUrl?type=original',
            // 8. 添加查询参数 ?motion=1
            if (!originalUrl.contains('?'))
              '$originalUrl?motion=1',
          ];
          for (final String tryUrl in variants) {
            try {
              final Response r = await fetch(tryUrl);
              final List<int> b = r.data as List<int>;
              // 变体检测也结合 ftyp 和 moov/mdat 两种方式
              final bool bHasMp4 = _hasMp4Trailer(b) || _hasMp4MediaBox(b);
              final bool bHasXmp = _hasMotionPhotoXmp(b);
              debugPrint(
                  '[download] variant=$tryUrl size=${b.length} hasMp4=$bHasMp4 hasXmp=$bHasXmp');
              // 只采用含 MP4 视频段的变体（不再因体积大就采用）
              if (bHasMp4) {
                bytes = b;
                response = r;
                hasMp4 = true;
                hasMotionXmp = bHasXmp;
                usedUrl = tryUrl;
                break;
              }
            } catch (e) {
              // 候选 URL 失败（404 等），继续尝试下一个
              debugPrint('[download] variant $tryUrl failed: $e');
            }
          }
        }
        // 最终基于采用的 bytes 重新计算所有标识，确保 Toast 准确
        // hasMp4：先检查 ftyp box（标准 MP4 起始），
        // 若无再检查 moov/mdat box（后备：某些 MP4 不以 ftyp 开头）
        hasMp4 = _hasMp4Trailer(bytes) || _hasMp4MediaBox(bytes);
        hasMotionXmp = _hasMotionPhotoXmp(bytes);
        final int? contentLength = int.tryParse(
            response.headers.value('content-length') ?? '');
        final String contentType =
            response.headers.value('content-type') ?? '';
        // 文件头前 16 字节 hex，便于诊断实际文件格式
        final String headHex = bytes
            .take(16)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        debugPrint(
            '[download] url=$usedUrl originalUrl=$originalUrl size=${bytes.length} contentLength=$contentLength contentType=$contentType headHex=$headHex hasMp4=$hasMp4 hasMotionXmp=$hasMotionXmp');
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
            // 普通文件：附文件头前 4 字节 hex 帮助诊断格式
            // 例：ffd8ffe0 = JPEG，00000018 66747970 = MP4，52494646 = WEBP
            final String shortHex = bytes
                .take(4)
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join('');
            label = '已保存（$sizeStr，head=$shortHex）';
          }
          SmartDialog.showToast(label);
        }
      }
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
    }
  }

  /// 搜索文件中是否有 moov/mdat box（MP4 必有这两个 box 之一）
  /// 作为 ftyp 搜索的后备：某些 MP4 可能不以 ftyp 开头，
  /// 但一定有 moov（元数据）或 mdat（媒体数据）box
  /// 为避免误判，要求 box size 合理（256 ~ 100MB）
  static bool _hasMp4MediaBox(List<int> bytes) {
    if (bytes.length < 16) return false;
    final List<List<int>> boxTypes = [
      [0x6D, 0x6F, 0x6F, 0x76], // "moov"
      [0x6D, 0x64, 0x61, 0x74], // "mdat"
    ];
    for (int i = 4; i < bytes.length - 12; i++) {
      // 检查位置 i 处是否是 moov/mdat
      bool matched = false;
      for (final sig in boxTypes) {
        if (bytes[i] == sig[0] &&
            bytes[i + 1] == sig[1] &&
            bytes[i + 2] == sig[2] &&
            bytes[i + 3] == sig[3]) {
          matched = true;
          break;
        }
      }
      if (!matched) continue;
      // 检查前 4 字节的 size 是否合理
      final int size = ((bytes[i - 4] & 0xFF) << 24) |
          ((bytes[i - 3] & 0xFF) << 16) |
          ((bytes[i - 2] & 0xFF) << 8) |
          (bytes[i - 1] & 0xFF);
      // moov/mdat size 通常在 256 字节 ~ 100MB 之间
      if (size >= 256 && size <= 100 * 1024 * 1024) {
        return true;
      }
    }
    return false;
  }

  /// 检查字节流中是否包含 MP4 ftyp box，判断是否为实况图视频数据
  /// 适用三种情况：
  ///   1. 完整 Motion Photo = JPEG + 末尾内嵌 MP4
  ///   2. 纯 MP4 视频（变体返回的 .mp4 文件）
  ///   3. JPEG + MP4 但 EOI 标记在 MP4 内部也出现（取 EOI 之后的位置可能错位）
  /// 策略：搜索整个文件的 ftyp box，并验证 brand 合理性
  /// （避免 JPEG 数据内部偶然包含 "ftyp" 字节序列导致误判）
  static bool _hasMp4Trailer(List<int> bytes) {
    if (bytes.length < 16) return false;
    // 已知 MP4 brand 列表（ftyp box 后 4 字节 major_brand）
    // 详见 https://mp4ra.org/registered-types/codes
    final Set<String> knownBrands = {
      'isom', 'iso2', 'iso3', 'iso4', 'iso5', 'iso6', 'iso7', 'iso8', 'iso9',
      'mp41', 'mp42', 'mp71', 'dash', 'avc1', 'heic', 'hevc', 'hevs',
      'qt  ', 'MSNV', 'CAQV', 'M4V ', 'M4A ', 'M4B ', 'M4P ', 'M4VP',
      '3gp5', '3gp4', '3gp6', '3g2a', '3g2c', 'MMAT', 'NDSC', 'NDXM',
      'NDAS', 'NDSM', 'NRI2', 'NRMV', 'NRTA', 'f4v ', 'f4p ', 'f4a ', 'f4b ',
    };
    // 已知 MP4 box 类型（ftyp 之后应出现这些之一）
    final Set<String> knownBoxes = {
      'moov', 'mdat', 'free', 'skip', 'udta', 'trak', 'mdia', 'minf', 'stbl',
      'mvhd', 'trak', 'tkhd', 'edts', 'mdia', 'mdhd', 'hdlr', 'minf', 'dinf',
      'stbl', 'stsd', 'stts', 'stss', 'ctts', 'stsc', 'stsz', 'stco', 'stss',
    };
    // 搜索整个文件的 ftyp box
    // ftyp box 结构：[4字节size]["ftyp"][4字节major_brand][4字节minor_version][compatible_brands...]
    for (int i = 0; i < bytes.length - 16; i++) {
      if (bytes[i] == 0x66 && // f
          bytes[i + 1] == 0x74 && // t
          bytes[i + 2] == 0x79 && // y
          bytes[i + 3] == 0x70) { // p
        // 检查 major_brand
        if (i + 7 < bytes.length) {
          final String brand = String.fromCharCodes(bytes.sublist(i + 4, i + 8));
          if (knownBrands.contains(brand)) {
            return true;
          }
        }
        // 即使 brand 不在列表中，检查 ftyp box size 是否合理
        // ftyp box size 至少 16 字节（size+type+brand+version），且不超过文件大小
        if (i >= 4) {
          // 用 & 0xFF 确保无符号（List<int> 元素可能为负）
          final int size = ((bytes[i - 4] & 0xFF) << 24) |
              ((bytes[i - 3] & 0xFF) << 16) |
              ((bytes[i - 2] & 0xFF) << 8) |
              (bytes[i - 1] & 0xFF);
          // size 合理范围：16 ~ 1MB，且 ftyp box 后应有其他 box
          if (size >= 16 && size <= 1024 * 1024 && i + size + 8 < bytes.length) {
            // 检查 ftyp box 后是否紧跟已知 MP4 box
            final String nextBox =
                String.fromCharCodes(bytes.sublist(i + size, i + size + 4));
            if (knownBoxes.contains(nextBox)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// 检查 XMP 元数据中是否包含实况图标识
  /// 各厂商 XMP 标识不同：
  ///   - Google/三星: "MotionPhoto"
  ///   - 小米 HyperOS: "MicroVideo" (GContainer:ItemLength)
  ///   - 华为/荣耀: 文件末尾标识，XMP 中可能无标识
  ///   - OPPO ColorOS: "OpCamera" + MotionPhoto
  ///   - iOS LivePhoto: "LivePhoto" / "ContentIdentifier"
  /// 扩展搜索范围到 256KB，覆盖大 EXIF/XMP 段
  static bool _hasMotionPhotoXmp(List<int> bytes) {
    final int limit = bytes.length > 262144 ? 262144 : bytes.length;
    // 多种实况图标识的 ASCII 字节序列
    final List<List<int>> signatures = [
      // "MotionPhoto" (Google/三星/OPPO)
      [0x4D, 0x6F, 0x74, 0x69, 0x6F, 0x6E, 0x50, 0x68, 0x6F, 0x74, 0x6F],
      // "MicroVideo" (小米)
      [0x4D, 0x69, 0x63, 0x72, 0x6F, 0x56, 0x69, 0x64, 0x65, 0x6F],
      // "GCamera" (Google Camera)
      [0x47, 0x43, 0x61, 0x6D, 0x65, 0x72, 0x61],
      // "LivePhoto" (iOS 风格)
      [0x4C, 0x69, 0x76, 0x65, 0x50, 0x68, 0x6F, 0x74, 0x6F],
      // "GContainer" (Google Motion Photo XMP 容器标识)
      [0x47, 0x43, 0x6F, 0x6E, 0x74, 0x61, 0x69, 0x6E, 0x65, 0x72],
    ];
    for (int i = 0; i < limit - 15; i++) {
      for (final sig in signatures) {
        bool match = true;
        for (int j = 0; j < sig.length; j++) {
          if (bytes[i + j] != sig[j]) {
            match = false;
            break;
          }
        }
        if (match) return true;
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
