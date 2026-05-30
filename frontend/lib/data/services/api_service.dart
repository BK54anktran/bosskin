import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/server_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/language_service.dart';
import 'auth_service.dart';
import 'device_service.dart';

class ApiService {
  static ApiService? _instance;

  late final Dio _dio;

  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'bosskin',
      publicKey: 'bosskin_key',
    ),
  );

  ApiService._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ServerConfig.baseUrl,
        connectTimeout: const Duration(
          milliseconds: AppConstants.connectTimeout,
        ),
        receiveTimeout: const Duration(
          milliseconds: AppConstants.receiveTimeout,
        ),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  static ApiService get instance =>
      _instance ??= ApiService._();

  Dio get dio => _dio;

  bool get _isLinuxDev =>
      !kIsWeb && Platform.isLinux;

  // =========================================================
  // SAFE STORAGE
  // =========================================================

  Future<String?> _safeRead(String key) async {
    if (_isLinuxDev) {
      if (key == AppConstants.tokenKey ||
          key == AppConstants.adminTokenKey) {
        return AuthService.instance.currentUser?.token;
      }
      return null;
    }

    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Storage read error: $e');
      return null;
    }
  }

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  static void reset() {
    _instance = null;
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _safeRead(
            AppConstants.tokenKey,
          );

          final deviceId =
              DeviceService.instance.deviceId ??
                  await DeviceService.instance
                      .getOrCreateDeviceId();
          final localeTag = LanguageService.instance.locale.toLanguageTag();

          if (token != null) {
            options.headers['Authorization'] =
                'Bearer $token';
          }
          options.headers['Accept-Language'] = localeTag;

          options.headers['X-Device-ID'] =
              deviceId;

          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final isUnauthorized = statusCode == 401;
          final isForbidden = statusCode == 403;
          final alreadyRetried =
              error.requestOptions.extra['__refreshed_after_permission_error'] ==
                  true;

          final shouldRefresh = isUnauthorized || isForbidden;

          if (shouldRefresh &&
              !_isAuthEndpoint(error.requestOptions.path) &&
              !alreadyRetried) {
            final refreshed = await AuthService.instance.refreshToken();

            if (refreshed) {
              final token = await _safeRead(
                AppConstants.tokenKey,
              );

              final opts = error.requestOptions;
              opts.extra['__refreshed_after_permission_error'] = true;

              opts.headers['Authorization'] =
                  'Bearer $token';

              try {
                final resp =
                    await _dio.fetch(opts);

                handler.resolve(resp);

                return;
              } catch (_) {
                handler.next(error);

                return;
              }
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  bool _isAuthEndpoint(String path) {
    return path.startsWith('/api/v1/auth/') ||
        path.startsWith('/admin/auth/');
  }

  Future<T> get<T>(
    String path,
    T Function(dynamic) fromJson, {
    Map<String, dynamic>? queryParams,
  }) async {
    final response = await _dio.get(
      path,
      queryParameters: queryParams,
    );

    return fromJson(response.data);
  }

  Future<T> post<T>(
    String path,
    T Function(dynamic) fromJson,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post(
      path,
      data: body,
    );

    return fromJson(response.data);
  }

  Future<T> put<T>(
    String path,
    T Function(dynamic) fromJson,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.put(
      path,
      data: body,
    );

    return fromJson(response.data);
  }

  Future<T> patch<T>(
    String path,
    T Function(dynamic) fromJson,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch(
      path,
      data: body,
    );

    return fromJson(response.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }
}
