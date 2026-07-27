import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:file_picker/file_picker.dart';

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
      final Dio dio = Dio();
      for (int index = 0; index < urlList.length; index++) {
        final Response response = await dio.get(urlList[index],
            options: Options(responseType: ResponseType.bytes));
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
          SmartDialog.showToast('已保存');
        }
      }
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
    }
  }
}
