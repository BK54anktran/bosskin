import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';

class DeviceService {
  static final DeviceService instance = DeviceService._();

  DeviceService._();

  final _storage = const FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'bosskin',
      publicKey: 'bosskin_key',
    ),
  );

  String? _deviceId;

  String? get deviceId => _deviceId;

  Future<String> getOrCreateDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      // Bypass secure storage on WSL/Linux dev
      if (!kIsWeb && Platform.isLinux) {
        _deviceId = 'linux-dev-device';
        return _deviceId!;
      }

      _deviceId = await _storage.read(
        key: AppConstants.deviceIdKey,
      );

      if (_deviceId == null) {
        _deviceId = const Uuid().v4();

        await _storage.write(
          key: AppConstants.deviceIdKey,
          value: _deviceId,
        );
      }

      return _deviceId!;
    } catch (e) {
      debugPrint('DeviceService error: $e');

      _deviceId ??= const Uuid().v4();

      return _deviceId!;
    }
  }
}