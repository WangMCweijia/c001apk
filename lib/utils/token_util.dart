import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';

import '../constants/constants.dart';
import 'token_v3_data.dart';

class TokenUtils {
  static bool isPreGetLoginParam = false;
  static bool isGetLoginParam = false;
  static bool isOnLogin = false;
  static bool isGetCaptcha = false;

  static final _authBlob = base64Decode(tokenV3Data.trim());

  /// 酷安 X-App-Token v3 签名（每次请求动态派生，包含当前 versionCode）
  static String getTokenV3(String deviceCode, {int appCode = 2604201}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    for (var offset = 0; offset <= 15; offset++) {
      final time = now + offset;
      final index = ((time + appCode) % 100) * 4 + 0x80;
      final segment = utf8.decode(
          base64Decode(ascii.decode(_authBlob.sublist(index, index + 0x80))));
      final plain =
          '${Constants.APP_ID}&$segment&${_getMD5(deviceCode)}&$time&$appCode';
      final password = _getMD5(base64Encode(utf8.encode(plain)));
      final source = getBase64('${time.toRadixString(16)}/${_getMD5(plain)}')
          .substring(0, 22);
      final salt = source.substring(0, 21) +
          alphabet[(alphabet.indexOf(source[21]) - 5) % 64];
      if (!RegExp(r'^[./A-Za-z0-9]{22}$').hasMatch(salt)) continue;
      final hash =
          BCrypt.hashpw(password, '\$2a\$04\$$salt').replaceRange(0, 3, '\$2y');
      return 'v3${getBase64(hash)}';
    }
    return getTokenV2(deviceCode);
  }

  static String createRandomNumber() {
    return Random().nextDouble().toString().replaceAll('.', 'undefined');
  }

  static Future<String> encodeDevice(String deviceInfo) async {
    var bytes = utf8.encode(deviceInfo);
    var base64Str = base64Encode(bytes);
    var reversedStr = base64Str.split('').reversed.join();
    var cleanedStr = reversedStr.replaceAll(
        RegExp(r'(\r\n|\r|\n|=)'), Constants.EMPTY_STRING);
    return cleanedStr;
  }

  static String getTokenV2(String deviceCode) {
    var timeStamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    var base64TimeStamp = getBase64(timeStamp);
    var md5TimeStamp = _getMD5(timeStamp);
    var md5DeviceCode = _getMD5(deviceCode);
    var token =
        '${Constants.APP_LABEL}?$md5TimeStamp\$$md5DeviceCode&${Constants.APP_ID}';
    var base64Token = getBase64(token);
    var md5Base64Token = _getMD5(base64Token);
    var md5Token = _getMD5(token);
    var bcryptSalt =
        '${"\$2a\$10\$$base64TimeStamp/$md5Token".substring(0, 31)}u';
    var bcryptResult = BCrypt.hashpw(md5Base64Token, bcryptSalt);
    return 'v2${base64Encode(utf8.encode(bcryptResult.replaceRange(0, 3, "\$2y"))).replaceAll("=", "")}';
  }

  static String getBase64(String input) {
    return base64Encode(utf8.encode(input)).replaceAll('=', '');
  }

  static String _getMD5(String input) {
    var bytes = utf8.encode(input);
    var digest = md5.convert(bytes);
    return digest.toString().replaceAll('-', '');
  }
}
