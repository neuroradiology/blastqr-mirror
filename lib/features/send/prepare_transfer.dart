import 'dart:math';

import 'package:blast_qr/app_preferences.dart';
import 'package:blast_qr/features/send/helpers/file_qr_encoder.dart';
import 'package:blast_qr/features/send/helpers/video_compression.dart';
import 'package:blast_qr/features/send/send_files.dart';
import 'package:blast_qr/features/send/send_options.dart';
import 'package:blast_qr/model/file_wrapper.dart';
import 'package:blast_qr/model/image_compression_settings.dart';
import 'package:blast_qr/model/video_quality.dart';
import 'package:blastqr_video/blastqr_video.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Sends larger than this get a warning first.
const largeTransferBytes = 2500000;

/// Photos and videos up to this size aren't worth re-encoding.
const minCompressibleMediaBytes = 400000;

@visibleForTesting
bool videoCompressionSupported = BlastqrVideo.isSupported;

bool isCompressibleImage(FileWrapper file) =>
    file.type.allowsImageCompression && file.size > minCompressibleMediaBytes;

/// Whether it's worth re-encoding is only known once it's read, see
/// [encodeSettingsFor].
bool isCompressibleVideo(FileWrapper file) =>
    videoCompressionSupported &&
    AppPreferences.videoQuality != VideoQuality.original &&
    file.type.isVideo &&
    file.size > minCompressibleMediaBytes;

bool isCompressibleMedia(FileWrapper file) =>
    isCompressibleImage(file) || isCompressibleVideo(file);

/// The fewest bytes [files] could be sent in once compressed: photos may
/// shrink to almost nothing, videos to at most [maxVideoBytes].
int minSendBytes(List<FileWrapper> files) => files.fold(
  0,
  (sum, f) =>
      sum +
      switch (f) {
        _ when isCompressibleImage(f) => 0,
        _ when isCompressibleVideo(f) => min(f.size, maxVideoBytes),
        _ => f.size,
      },
);

/// Compressed photos come out at about this size with the default settings.
const _estimatedImageBytes = 400000;

/// About how many bytes [files] are sent in, before gzip. [videos] has
/// what's known of the videos, by path, from [BlastqrVideo.probe]; until a
/// video is known it counts as at most [maxVideoBytes].
int estimateSendBytes(
  List<FileWrapper> files, {
  required bool compressMedia,
  Map<String, VideoInfo> videos = const {},
}) => files.fold(0, (sum, f) {
  if (!compressMedia) return sum + f.size;
  if (isCompressibleImage(f)) return sum + min(f.size, _estimatedImageBytes);
  if (!isCompressibleVideo(f)) return sum + f.size;
  final info = videos[f.file.path];
  if (info == null) return sum + min(f.size, maxVideoBytes);
  final settings = encodeSettingsFor(
    info,
    sourceBytes: f.size,
    quality: AppPreferences.videoQuality,
  );
  return sum +
      (settings == null ? f.size : estimatedVideoBytes(info, settings));
});

/// A transfer object ready to show as QR codes (see [buildTransferObject]).
class PreparedTransfer {
  const PreparedTransfer({
    required this.files,
    required this.name,
    required this.bytes,
    required this.gzipped,
    required this.password,
    required this.compressed,
  });

  /// The files picked, to show what's being sent.
  final List<FileWrapper> files;

  /// The name the receiver saves a single file as, or the bundle's name.
  final String name;

  final Uint8List bytes;
  final bool gzipped;

  /// Set when encrypted, to show to the user.
  final String? password;

  /// Whether photos or videos were compressed, as the user asked. Such
  /// sends skip the long transfer prompt: the user already made them as
  /// small as they can be.
  final bool compressed;

  bool get isBundle => files.length > 1;
}

/// Builds what [files] are sent as: photos and videos compressed if
/// [SendOptions.compressMedia], several files zipped into one, the name
/// applied, then gzipped if that helps and encrypted if there's a password.
///
/// Video compression is reported to [onProgress] from 0 to 1, and stops
/// with [VideoCompressionCancelled] once [cancel] completes.
Future<PreparedTransfer> prepareTransfer(
  List<FileWrapper> files,
  SendOptions options, {
  required ImageCompressionSettings imageSettings,
  void Function(double progress)? onProgress,
  Future<void>? cancel,
}) async {
  final compress = options.compressMedia && files.any(isCompressibleMedia);
  final content = files.length > 1
      ? await _bundle(
          files,
          compress: compress,
          imageSettings: imageSettings,
          onProgress: onProgress,
          cancel: cancel,
        )
      : await _singleFile(
          files.single,
          renamed: options.fileName,
          compress: compress,
          imageSettings: imageSettings,
          onProgress: onProgress,
          cancel: cancel,
        );
  final transfer = await buildTransferObject(
    fileName: content.name,
    content: content.bytes,
    tryGzip: content.tryGzip,
    password: options.password,
    isBundle: files.length > 1,
  );
  debugPrint(
    'Prepared ${content.name}: '
    '${files.fold(0, (sum, f) => sum + f.size)} -> ${transfer.bytes.length}',
  );
  return PreparedTransfer(
    files: files,
    name: content.name,
    bytes: transfer.bytes,
    gzipped: transfer.gzipped,
    password: options.password,
    compressed: compress,
  );
}

typedef _Content = ({String name, Uint8List bytes, bool tryGzip});

Future<_Content> _bundle(
  List<FileWrapper> files, {
  required bool compress,
  required ImageCompressionSettings imageSettings,
  void Function(double progress)? onProgress,
  Future<void>? cancel,
}) async {
  final bundle = await createSendBundle(
    files,
    icSettings: compress ? imageSettings : null,
    compressVideos: compress,
    onProgress: onProgress,
    cancel: cancel,
  );
  try {
    return (
      name: bundle.name,
      bytes: await bundle.file.readAsBytes(),
      tryGzip: true,
    );
  } finally {
    await bundle.file.delete();
  }
}

/// A re-encoded file takes its new format's extension, also when
/// [renamed].
Future<_Content> _singleFile(
  FileWrapper file, {
  required String? renamed,
  required bool compress,
  required ImageCompressionSettings imageSettings,
  void Function(double progress)? onProgress,
  Future<void>? cancel,
}) async {
  String reencodedName(String extension) =>
      '${p.basenameWithoutExtension(renamed ?? file.name)}.$extension';

  if (compress && isCompressibleVideo(file)) {
    final video = await compressVideo(
      file,
      onProgress: onProgress,
      cancel: cancel,
    );
    if (video != null) {
      return (
        name: reencodedName(video.extension),
        bytes: await video.file.readAsBytes(),
        tryGzip: false,
      );
    }
  }
  final bytes = await file.file.readAsBytes();
  if (compress && isCompressibleImage(file)) {
    final image = await FileQrEncoder.compressImage(bytes, imageSettings);
    if (image != null) {
      return (
        name: reencodedName(
          imageSettings.outputFormat.extension ?? file.type.extension,
        ),
        bytes: image,
        tryGzip: false,
      );
    }
  }
  return (
    name: renamed ?? file.name,
    bytes: bytes,
    tryGzip: !file.type.isPrecompressed,
  );
}
