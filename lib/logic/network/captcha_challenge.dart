import 'dart:convert';

class CaptchaChallenge {
  const CaptchaChallenge(this.captchaId, this.field);
  final String captchaId;
  final String field;
  static const defaultId = '414e5c9b866a03db03f860a1a9101672';

  static CaptchaChallenge? fromBody(dynamic body) {
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is! Map || body['messageStatus'] != 'err_request_captcha_v2') {
      return null;
    }
    dynamic extra = body['messageExtra'] ?? body['extra'];
    if (extra is String) {
      try {
        extra = jsonDecode(extra);
      } on FormatException {
        extra = null;
      }
    }
    if (extra is! Map) extra = body;
    final id = extra['captchaId'];
    final field = extra['captchaField'];
    return CaptchaChallenge(
      id is String && RegExp(r'^[a-zA-Z0-9]{16,64}$').hasMatch(id)
          ? id
          : defaultId,
      field is String &&
              (field.trim().isEmpty ||
                  RegExp(r'^_[a-zA-Z0-9_]{1,63}$').hasMatch(field))
          ? field.trim()
          : '_v2_post_token',
    );
  }

  String? proof(dynamic validate) {
    if (validate is! String ||
        validate.isEmpty ||
        validate.length > 8192 ||
        RegExp(r'[\s\x00-\x1f]').hasMatch(validate)) {
      return null;
    }
    return 'NEC:${captchaId.substring(0, 8)}:$validate';
  }

  bool acceptsProof(String proof) =>
      proof.startsWith('NEC:${captchaId.substring(0, 8)}:') &&
      proof.length > 13 &&
      proof.length <= 8205 &&
      !RegExp(r'[\s\x00-\x1f]').hasMatch(proof);
}
