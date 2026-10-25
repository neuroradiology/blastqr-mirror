import 'package:blast_qr/color_scheme.dart';
import 'package:blast_qr/crypto/password.dart';
import 'package:blast_qr/features/send/widgets/custom_password_sheet.dart';
import 'package:blast_qr/file_name_utils.dart';
import 'package:blast_qr/l10n/extension.dart';
import 'package:blast_qr/model/file_wrapper.dart';
import 'package:blast_qr/widgets/bottom_sheets.dart';
import 'package:blast_qr/widgets/file_preview.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// How a send should go. [password] is null for a plain send. [fileName] is
/// the name the receiver gets, or null to keep the file's own name.
typedef SendOptions = ({String? password, String? fileName});

/// A plain send.
const SendOptions plainSend = (password: null, fileName: null);

/// An encrypted send with a new generated password.
SendOptions encryptedSend({String? fileName}) =>
    (password: generatePassword(), fileName: fileName);

/// Asks how the next send of [files] (one file or a batch) goes: Send or
/// Send password-encrypted (long press to choose the password), and renaming
/// a single file. Returns null if the user cancelled the send.
Future<SendOptions?> chooseSendOptions(
  BuildContext context,
  List<FileWrapper> files,
) async {
  final result = await showSheet<_SendSheetResult>(
    context: context,
    title: context.l10n.send,
    body: _SendSheet(files: files),
  );
  if (result == null) return null;
  if (!result.customPassword) return result.options;

  // The Send sheet is closed by now; cancelling this one cancels the send.
  if (!context.mounted) return null;
  final password = await showCustomPasswordSheet(context);
  if (password == null) return null;
  return (password: password, fileName: result.options.fileName);
}

/// What the Send sheet closed with. [customPassword] means the user long
/// pressed "Send password-encrypted" and wants to choose the password next.
typedef _SendSheetResult = ({SendOptions options, bool customPassword});

class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.files});

  final List<FileWrapper> files;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  late final _nameController = TextEditingController(
    text: widget.files.first.name,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The new name, or null if it's unchanged (or only a batch is sent).
  String? get _fileName {
    if (widget.files.length != 1) return null;
    final original = widget.files.first.name;
    final typed = _nameController.text.trim();
    if (typed.isEmpty || typed == original) return null;
    return sanitizeFileName(typed);
  }

  void _close(SendOptions options, {bool customPassword = false}) {
    Navigator.of(context).pop<_SendSheetResult>((
      options: options,
      customPassword: customPassword,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.files.first;
    return Column(
      children: [
        if (widget.files.length == 1) ...[
          FileThumbnail(file: file, size: 92),
          // Same rename field as the receiver's result sheet.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                suffixIcon: Padding(
                  padding: const EdgeInsetsGeometry.all(12),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit01,
                    color: context.color.onSurface,
                  ),
                ),
                contentPadding: const EdgeInsets.fromLTRB(48, 0, 0, 8),
              ),
              onTap: () {
                // Select the name without its extension.
                final dotIndex = _nameController.text.lastIndexOf('.');
                _nameController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset:
                      dotIndex > 0 ? dotIndex : _nameController.text.length,
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            file.sizeInkB,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.color.secondary),
          ),
        ] else
          FilesPreview(files: widget.files),
        const SizedBox(height: 8),
        SendTile(
          onTap: () => _close((password: null, fileName: _fileName)),
        ),
        SendEncryptedTile(
          onTap: () => _close(encryptedSend(fileName: _fileName)),
          // Closes this sheet; chooseSendOptions then opens the password one.
          onLongPress:
              () => _close(
                (password: null, fileName: _fileName),
                customPassword: true,
              ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// "Send" option, as in the Files tab sheets.
class SendTile extends StatelessWidget {
  const SendTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: HugeIcon(
        icon: HugeIcons.strokeRoundedQrCode,
        color: context.color.primary,
      ),
      title: Text(context.l10n.send),
    );
  }
}

/// "Send password-encrypted" option. The password is generated and shown on
/// the QR page. A long press (hidden option) lets the user pick it.
class SendEncryptedTile extends StatelessWidget {
  const SendEncryptedTile({super.key, required this.onTap, this.onLongPress});

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      onLongPress: onLongPress,
      leading: HugeIcon(
        icon: HugeIcons.strokeRoundedSquareLock02,
        color: context.color.primary,
      ),
      title: Text(context.l10n.send_encrypted),
    );
  }
}
