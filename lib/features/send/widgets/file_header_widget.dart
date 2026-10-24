import 'package:blast_qr/color_scheme.dart';
import 'package:blast_qr/l10n/extension.dart';
import 'package:blast_qr/model/file_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class FileHeaderWidget extends StatelessWidget {
  const FileHeaderWidget({
    super.key,
    required this.file,
    required this.onTapDismiss,
    this.compressedSize,
    this.password,
  });

  final FileWrapper file;
  final VoidCallback onTapDismiss;
  final int? compressedSize;

  /// Shown with a lock when the transfer is encrypted.
  final String? password;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 12,
            children: [
              Container(
                width: 72,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      spreadRadius: 0,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: file.buildThumbnail(context, size: 72),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 36),
                      child: Text(
                        file.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    if (compressedSize != null && compressedSize != file.size)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          Text(file.sizeInkB),
                          const Icon(Icons.arrow_forward, size: 14),
                          Text(
                            '${(compressedSize! / 1000).toStringAsFixed(0)} KB',
                          ),
                        ],
                      )
                    else
                      Text(file.sizeInkB),
                    if (password != null) PasswordRow(password: password!),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            width: 36,
            child: IconButton(
              onPressed: onTapDismiss,
              style: IconButton.styleFrom(
                backgroundColor: context.color.primaryContainer,
                foregroundColor: context.color.onSurface,
              ),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.clear),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lock icon + password, with a button to hide it (e.g. while a camera that
/// shouldn't see it is pointed at the screen).
class PasswordRow extends StatefulWidget {
  const PasswordRow({super.key, required this.password});

  final String password;

  @override
  State<PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends State<PasswordRow> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedSquareLock02,
          size: 18,
          color: context.color.onSurface,
        ),
        Flexible(
          child: SelectableText(
            _visible ? widget.password : '••••-••••-••••',
            maxLines: 1,
            style: passwordTextStyle(context),
          ),
        ),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: context.l10n.show_password,
            onPressed: () => setState(() => _visible = !_visible),
            icon: HugeIcon(
              icon:
                  _visible
                      ? HugeIcons.strokeRoundedViewOff
                      : HugeIcons.strokeRoundedView,
              size: 18,
              color: context.color.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Monospace, so similar characters are easy to tell apart.
TextStyle? passwordTextStyle(BuildContext context, {double fontSize = 18}) {
  return Theme.of(context).textTheme.titleMedium?.copyWith(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Menlo', 'Roboto Mono', 'Courier'],
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
  );
}
