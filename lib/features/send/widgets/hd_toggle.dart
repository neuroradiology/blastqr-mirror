import 'package:blast_qr/app_settings.dart';
import 'package:blast_qr/color_scheme.dart';
import 'package:blast_qr/features/send/send_plan.dart';
import 'package:blast_qr/l10n/extension.dart';
import 'package:blast_qr/model/file_wrapper.dart';
import 'package:blast_qr/widgets/strike_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Whether photos are sent as they are. Starts from the "compress photos by
/// default" setting.
ValueNotifier<bool> hdNotifier(BuildContext context) => ValueNotifier(
  !Provider.of<AppSettings>(context, listen: false).compressPhotosByDefault,
);

/// [preview] with the HD toggle beside it when any of [files] could be
/// compressed.
class HdTogglePreview extends StatelessWidget {
  const HdTogglePreview({
    super.key,
    required this.files,
    required this.hd,
    required this.preview,
  });

  final List<FileWrapper> files;
  final ValueNotifier<bool> hd;
  final Widget preview;

  static bool showsToggle(List<FileWrapper> files) =>
      files.any(isCompressibleImage);

  @override
  Widget build(BuildContext context) {
    if (!showsToggle(files)) return preview;
    const gap = SizedBox(width: 12);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // An invisible twin keeps the preview centred.
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _HdToggle(hd: hd),
          ),
          gap,
          preview,
          gap,
          _HdToggle(hd: hd),
        ],
      ),
    );
  }
}

class _HdToggle extends StatelessWidget {
  const _HdToggle({required this.hd});

  final ValueNotifier<bool> hd;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: hd,
      builder: (context, on, _) {
        final color = on
            ? context.color.primary
            : context.color.secondary.withValues(alpha: 0.5);
        return Tooltip(
          message: context.l10n.hd_tooltip,
          child: Semantics(
            button: true,
            toggled: on,
            child: CustomPaint(
              foregroundPainter: on
                  ? null
                  : StrikePainter(
                      color: color,
                      gapColor: context.color.primaryContainer,
                    ),
              child: Material(
                color: on ? color : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: color, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => hd.value = !on,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      'HD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: on ? context.color.onPrimary : color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
