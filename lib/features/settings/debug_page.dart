import 'dart:io';

import 'package:blast_qr/app_settings.dart';
import 'package:blast_qr/color_scheme.dart';
import 'package:blast_qr/debug_channel.dart';
import 'package:blast_qr/features/scan/decode_stats.dart';
import 'package:blast_qr/features/scan/scan_camera.dart';
import 'package:blast_qr/features/settings/widgets/setting_group_title.dart';
import 'package:blast_qr/l10n/extension.dart';
import 'package:blast_qr/widgets/bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

// Developer-only page, so the text in it isn't translated.
class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = DecodeStats.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.debug),
        actions: [
          // Builder, so the share sheet can anchor to the button on iPad.
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Share',
              onPressed: () => _share(buttonContext),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedShare08),
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: stats.clear,
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: stats,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).padding.bottom,
            ),
            children: [
              const SettingGroupTitle(title: 'Camera'),
              _FutureRow('Device', DebugChannel.deviceModel),
              _Row('Settings', stats.camera ?? '-'),
              if (Platform.isAndroid)
                _FutureRow(
                  'Supported frame rates',
                  DebugChannel.backCameraFpsRanges,
                ),
              if (Platform.isIOS) const _IphoneExperiments(),
              const SettingGroupTitle(title: 'Last transfers'),
              if (stats.transfers.isEmpty)
                const ListTile(title: Text('No transfers yet')),
              for (final (i, transfer) in stats.transfers.indexed)
                _TransferTile(transfer, initiallyExpanded: i == 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Text(
                  'Kept in memory for the last 5 transfers. Per-second code '
                  'and data rates only count time spent receiving. "New codes" '
                  'is out of all codes read; the rest are repeats. Decode time '
                  'covers every frame, with or without a QR code, including '
                  'the hand-off to the decoder isolate.',
                  style: TextStyle(color: context.color.outline),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    final stats = DecodeStats.instance;
    final info = await PackageInfo.fromPlatform();
    final lines = [
      'blastQR debug export, ${DateTime.now().toIso8601String()}',
      'App: ${info.version}+${info.buildNumber}',
      'Device: ${await _orUnavailable(DebugChannel.deviceModel)}',
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Camera settings: ${stats.camera ?? '-'}',
      if (Platform.isAndroid)
        'Supported frame rates: ${await _orUnavailable(DebugChannel.backCameraFpsRanges)}',
      for (final (i, t) in stats.transfers.indexed) ...[
        '',
        '## Transfer ${i + 1}: ${_transferTitle(t)}',
        'Camera: ${t.camera}',
        for (final (label, value) in _transferRows(t)) '$label: $value',
      ],
      if (stats.transfers.isEmpty) ...['', 'No transfers yet'],
    ];
    final text = lines.join('\n');

    // Fresh folder each time, so files from an earlier share don't tag along.
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}/debug_export',
    );
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create();
    final files = [
      await File('${dir.path}/blastqr-debug.txt').writeAsString(text),
    ];
    for (final (i, t) in stats.transfers.indexed) {
      for (final frame in t.savedFrames) {
        files.add(
          await File(
            '${dir.path}/${_frameName(i, frame)}.png',
          ).writeAsBytes(frame.png),
        );
      }
    }

    if (!buttonContext.mounted) return;
    final button = buttonContext.findRenderObject() as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'blastQR debug export',
        files: [for (final f in files) XFile(f.path)],
        sharePositionOrigin: button.localToGlobal(Offset.zero) & button.size,
      ),
    );
  }

  static Future<String> _orUnavailable(Future<String> value) =>
      value.catchError((_) => 'Unavailable');
}

/// Ways to undo the iPhone camera defaults, for comparing. They apply right
/// away and are part of each transfer's camera label.
class _IphoneExperiments extends StatelessWidget {
  const _IphoneExperiments();

  static const _exposures = <double?>[null, 0, 4, 2, 1, 0.5];

  static String _label(double? ms) => switch (ms) {
    null => 'Automatic, max ${ScanCamera.defaultMaxExposureMs} ms (default)',
    0 => 'Automatic, no limit',
    final ms => 'Fixed $ms ms',
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Column(
      children: [
        const SettingGroupTitle(title: 'iPhone camera experiments'),
        SwitchListTile.adaptive(
          title: const Text('Allow video HDR'),
          subtitle: const Text('Off by default'),
          value: settings.debugVideoHdr,
          onChanged: settings.updateDebugVideoHdr,
          activeTrackColor: context.color.primary,
        ),
        ListTile(
          title: const Text('Exposure time'),
          subtitle: Text(_label(settings.debugExposureMs)),
          onTap: () => showPickerSheet(
            context,
            title: 'Exposure time',
            message:
                'Long exposures blend two codes into one frame when the '
                'sender changes code mid-capture. A fixed exposure raises ISO '
                'to keep the brightness, so the image gets noisier.',
            selectedItemIndex: _exposures.indexOf(settings.debugExposureMs),
            items: _exposures.map(_label).toList(),
            onItemTap: (i) => settings.updateDebugExposureMs(_exposures[i]),
          ),
        ),
      ],
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile(this.transfer, {required this.initiallyExpanded});

  final TransferStats transfer;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    return ExpansionTile(
      // Keyed by start time, so a new transfer at the top doesn't take over
      // the expanded state of the one that was there.
      key: ValueKey(t.started),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      title: Text(_transferTitle(t)),
      subtitle: Text('${t.camera} · ${_fps(t.newCodesPerSecond)} new codes/s'),
      children: [
        for (final (label, value) in _transferRows(t)) _Row(label, value),
        if (t.savedFrames.isNotEmpty)
          _FrameStrip(t.savedFrames, maxCodes: t.maxCodesPerFrame),
      ],
    );
  }
}

String _frameName(int transferIndex, SavedFrame frame) =>
    'transfer${transferIndex + 1}_${frame.at.inMilliseconds}ms_'
    '${frame.codes}codes';

/// Saved camera frames, outlined in the error colour when fewer codes were
/// read from them than from the best frame. Tap one to see it full size.
class _FrameStrip extends StatelessWidget {
  const _FrameStrip(this.frames, {required this.maxCodes});

  final List<SavedFrame> frames;
  final int maxCodes;

  bool _failed(SavedFrame frame) => frame.codes == 0 || frame.codes < maxCodes;

  String _codes(SavedFrame frame) => maxCodes > 1
      ? '${frame.codes} of $maxCodes codes read'
      : frame.codes > 0
      ? 'code read'
      : 'no code read';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            maxCodes > 1
                ? 'Frames the decoder saw (red: fewer codes than the best '
                      'frame, $maxCodes)'
                : 'Frames the decoder saw (red: no code read)',
            style: TextStyle(color: context.color.outline),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: frames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final frame = frames[i];
                return GestureDetector(
                  onTap: () => _open(context, frame),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: _failed(frame)
                            ? context.color.error
                            : context.color.primary,
                      ),
                    ),
                    child: Image.memory(frame.png, gaplessPlayback: true),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, SavedFrame frame) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              '${(frame.at.inMilliseconds / 1000).toStringAsFixed(2)} s · '
              '${_codes(frame)}',
            ),
          ),
          body: InteractiveViewer(
            maxScale: 8,
            child: Center(child: Image.memory(frame.png)),
          ),
        ),
      ),
    );
  }
}

String _transferTitle(TransferStats t) {
  final status = identical(t, DecodeStats.instance.current)
      ? 'Receiving'
      : t.completed
      ? 'Complete'
      : 'Stopped';
  final time = t.started.toIso8601String().substring(11, 19);
  return '$time · ${_kb(t.size)} · $status';
}

List<(String, String)> _transferRows(TransferStats t) {
  final sorted = t.sortedDecodeMicros();
  int percentile(double p) => sorted[((sorted.length - 1) * p).round()];
  return [
    ('New codes per second', _fps(t.newCodesPerSecond)),
    (
      'New data per second',
      t.newBytesPerSecond == 0 ? '-' : '${_kb(t.newBytesPerSecond)}/s',
    ),
    ('Frames with a code', _share(t.framesWithCode, t.decoded)),
    if (t.maxCodesPerFrame > 1)
      (
        'Codes per frame',
        'avg ${t.decoded == 0 ? 0 : (t.codesRead / t.decoded).toStringAsFixed(1)}, '
            'max ${t.maxCodesPerFrame}',
      ),
    ('New codes', _share(t.newCodes, t.codesRead)),
    ('Time scanning', _seconds(t.scanTime)),
    ('Camera frame rate', _fps(t.cameraFps)),
    ('Decoded frame rate', _fps(t.decodedFps)),
    ('Frames skipped (decoder busy)', _share(t.skipped, t.frames)),
    if (sorted.isNotEmpty) ...[
      ('Decode time min', _ms(sorted.first)),
      (
        'Decode time average',
        _ms(sorted.reduce((a, b) => a + b) / sorted.length),
      ),
      ('Decode time median', _ms(percentile(0.5))),
      ('Decode time 95th percentile', _ms(percentile(0.95))),
      ('Decode time max', _ms(sorted.last)),
    ],
    ..._cameraRows(t.cameraSamples),
  ];
}

List<(String, String)> _cameraRows(List<CameraSample> samples) {
  if (samples.isEmpty) return const [];
  String range(double Function(CameraSample) value, int digits) {
    final values = samples.map(value).toList()..sort();
    final average = values.reduce((a, b) => a + b) / values.length;
    String f(double v) => v.toStringAsFixed(digits);
    return '${f(values.first)}–${f(values.last)} (avg ${f(average)})';
  }

  String modes(String Function(CameraSample) value) =>
      samples.map(value).toSet().join(', ');
  final first = samples.first;
  return [
    (
      'Camera format',
      '${first.format}, '
          '${first.minFps.round()}–${first.maxFps.round()} FPS',
    ),
    ('Camera samples', '${samples.length}'),
    ('Exposure time', '${range((s) => s.exposureMs, 1)} ms'),
    ('Exposure limit', '${range((s) => s.exposureLimitMs, 1)} ms'),
    ('ISO', range((s) => s.iso, 0)),
    ('Exposure bias', '${range((s) => s.exposureBias, 1)} EV'),
    ('Exposure mode', modes((s) => s.exposureMode)),
    ('Focus mode', modes((s) => s.focusMode)),
    ('Zoom', '${range((s) => s.zoom, 2)}×'),
    (
      'Video HDR',
      first.videoHdrSupported
          ? 'on in ${_share(samples.where((s) => s.videoHdr).length, samples.length)}'
          : 'not supported by this format',
    ),
    ('Lens position (0 near, 1 far)', range((s) => s.lensPosition, 2)),
    (
      'Focus adjusting',
      _share(samples.where((s) => s.adjustingFocus).length, samples.length),
    ),
    if (first.minFocusDistanceMm case final mm?)
      ('Min focus distance', '$mm mm'),
  ];
}

String _ms(num micros) => '${(micros / 1000).toStringAsFixed(1)} ms';

String _kb(num bytes) => '${(bytes / 1000).toStringAsFixed(0)} KB';

String _share(int part, int total) =>
    total == 0 ? '-' : '$part of $total (${(100 * part / total).round()}%)';

String _fps(double fps) => fps == 0 ? '-' : fps.toStringAsFixed(1);

String _seconds(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    // Long values go under the label, where they have the full width.
    if (value.length > 16) {
      return ListTile(
        title: Text(label),
        subtitle: Text(value, style: style),
      );
    }
    return ListTile(
      title: Text(label),
      trailing: Text(value, style: style),
    );
  }
}

/// A row whose value may be long, so it goes under the label.
class _FutureRow extends StatelessWidget {
  const _FutureRow(this.label, this.value);

  final String label;
  final Future<String> value;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: value,
      builder: (context, snapshot) => ListTile(
        title: Text(label),
        subtitle: Text(
          snapshot.hasError ? 'Unavailable' : snapshot.data ?? '…',
        ),
      ),
    );
  }
}
