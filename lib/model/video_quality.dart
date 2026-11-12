import 'package:blast_qr/l10n/app_localizations.dart';

/// What videos are compressed to when sending without HD.
enum VideoQuality {
  original,
  low,
  lowest;

  /// The video bitrate to aim for, or null when videos are sent as they
  /// are. 540p looks fine on a phone and at about 1 Mbps sends in about real
  /// time; 360p at 400 kbps sends more than twice as fast.
  int? get videoBitrate => switch (this) {
    original => null,
    low => 1000000,
    lowest => 400000,
  };

  String title(AppLocalizations l10n) => switch (this) {
    original => l10n.video_quality_original,
    low => l10n.video_quality_low,
    lowest => l10n.video_quality_lowest,
  };
}
