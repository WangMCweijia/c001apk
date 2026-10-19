import 'dart:async';
import 'package:dio/dio.dart';

import '../../logic/network/captcha_challenge.dart';
import '../../logic/network/interceptor.dart';
import '../../pages/webview/captcha_page.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;
  factory Request() => _instance;

  bool _verifying = false;

  Request._internal() {
    dio = Dio()
      ..options.connectTimeout = const Duration(milliseconds: 5000)
      ..options.receiveTimeout = const Duration(milliseconds: 5000)
      ..interceptors.add(ApiInterceptor());
  }

  Future<Response<dynamic>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    extra,
  }) async {
    final response = await dio.get(
      url,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return _verifyAndRetry(
      response,
      options?.extra?['skipCaptcha'] == true,
      (proof, challenge) => dio.get(
        url,
        queryParameters: challenge.field.isEmpty
            ? queryParameters
            : {...?queryParameters, challenge.field: proof},
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<dynamic>> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    extra,
  }) async {
    final retryData = data is FormData ? data.clone() : data;
    final response = await dio.post(
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
    return _verifyAndRetry(
      response,
      options?.extra?['skipCaptcha'] == true,
      (proof, challenge) {
        Object? verifiedData = retryData;
        if (challenge.field.isNotEmpty) {
          if (retryData is FormData) {
            retryData.fields.removeWhere((e) => e.key == challenge.field);
            retryData.fields.add(MapEntry(challenge.field, proof));
          } else if (retryData is Map<String, dynamic>) {
            verifiedData = {...retryData, challenge.field: proof};
          }
        }
        return dio.post(
          url,
          data: verifiedData,
          queryParameters: challenge.field.isEmpty ||
                  verifiedData is FormData ||
                  verifiedData is Map
              ? queryParameters
              : {...?queryParameters, challenge.field: proof},
          options: options,
          cancelToken: cancelToken,
        );
      },
    );
  }

  Future<Response<dynamic>> _verifyAndRetry(
    Response<dynamic> response,
    bool skip,
    Future<Response<dynamic>> Function(String, CaptchaChallenge) retry,
  ) async {
    final uri = response.requestOptions.uri;
    if (skip ||
        _verifying ||
        uri.scheme != 'https' ||
        !ApiInterceptor.isApiHost(uri.host)) {
      return response;
    }
    final challenge = CaptchaChallenge.fromBody(response.data);
    if (challenge == null) return response;

    _verifying = true;
    try {
      if (challenge.field.isEmpty) {
        ApiInterceptor.clearCaptchaCookie();
      }
      final proof = await verifyCaptcha(challenge);
      if (proof == null || !challenge.acceptsProof(proof)) {
        return response;
      }
      ApiInterceptor.setCaptchaCookie(proof);
      final verified = await retry(proof, challenge);
      if (CaptchaChallenge.fromBody(verified.data) != null) {
        ApiInterceptor.clearCaptchaCookie();
      }
      return verified;
    } finally {
      _verifying = false;
    }
  }
}
