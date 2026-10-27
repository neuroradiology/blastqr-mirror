import 'package:flutter/services.dart';

/// iOS camera settings the camera plugin doesn't offer.
abstract final class ScanCamera {
  static const _channel = MethodChannel('blastqr/camera');

  /// The iPhone exposes for up to 1/120 s and merges frames for video HDR.
  /// Either blends two QR codes into one frame whenever the sender changes
  /// code mid-capture, so both are kept short or off by default.
  static const defaultMaxExposureMs = 2.0;

  /// [maxExposureMs] caps automatic exposure, null leaves it uncapped.
  /// [exposureMs] fixes the exposure instead, for testing.
  static Future<void> configure({
    required bool videoHdr,
    required double? maxExposureMs,
    required double? exposureMs,
  }) => _channel.invokeMethod('configureScanCamera', {
    'videoHdr': videoHdr,
    'maxExposureMs': maxExposureMs,
    'exposureMs': exposureMs,
  });
}
