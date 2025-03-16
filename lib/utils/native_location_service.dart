import 'dart:io';
import 'package:flutter/services.dart';

class NativeLocationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.native_location',
  );

  /// Fetches native location data.
  /// Expected keys: 'latitude', 'longitude', 'accuracy'
  static Future<Map<String, dynamic>?> getNativeLocation() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await _channel.invokeMethod('getLocation');
      return Map<String, dynamic>.from(result);
    }
    return null;
  }
}
