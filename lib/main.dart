import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import 'components/custom_toast.dart';
import 'constants/constants.dart';
import 'logic/network/request.dart';
import 'router/app_pages.dart';
import 'utils/app_theme.dart';
import 'utils/storage_util.dart';
import 'utils/utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (Utils.isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      minimumSize: const Size(400, 700),
      center: true,
      skipTaskbar: false,
      title: 'c001apk',
      titleBarStyle:
          Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await GStorage.init();
  HttpOverrides.global = CustomHttpOverrides();

  if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
      statusBarBrightness: GStorage.getBrightness(),
      systemNavigationBarIconBrightness: GStorage.getBrightness(),
    ));
  }

  Request();
  runApp(const C001APKAPP());
}

class C001APKAPP extends StatelessWidget {
  const C001APKAPP({super.key});

  @override
  Widget build(BuildContext context) {
    double fontScale =
        GStorage.settings.get(SettingsBoxKey.fontScale, defaultValue: 1.0);
    return GetMaterialApp(
      title: 'c001apk',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: GStorage.getThemeMode(),
      getPages: AppPages.getPages,
      initialRoute: '/',
      builder: (BuildContext context, Widget? child) {
        return FlutterSmartDialog(
          toastBuilder: (String msg) => CustomToast(msg: msg),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(fontScale)),
            child: child!,
          ),
        );
      },
    );
  }
}

class CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = GStorage.userAgent;
  }
}
