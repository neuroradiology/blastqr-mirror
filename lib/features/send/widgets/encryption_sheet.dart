import 'package:blast_qr/app_settings.dart';
import 'package:blast_qr/color_scheme.dart';
import 'package:blast_qr/crypto/password.dart';
import 'package:blast_qr/features/send/widgets/file_header_widget.dart';
import 'package:blast_qr/l10n/extension.dart';
import 'package:blast_qr/model/encryption_mode.dart';
import 'package:blast_qr/widgets/blast_text_field.dart';
import 'package:blast_qr/widgets/bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

/// How a send should be encrypted. [password] is null for a plain send.
typedef SendEncryption = ({String? password});

/// Decides whether the next send (one file or a batch) is encrypted, using
/// the Encryption setting. Returns null if the user cancelled the send.
Future<SendEncryption?> chooseSendEncryption(BuildContext context) async {
  final mode = Provider.of<AppSettings>(context, listen: false).encryptionMode;
  switch (mode) {
    case EncryptionMode.never:
      return (password: null);
    case EncryptionMode.always:
      return (password: generatePassword());
    case EncryptionMode.ask:
      return showSheet<SendEncryption>(
        context: context,
        title: context.l10n.encrypt_prompt_title,
        message: context.l10n.encrypt_prompt_msg,
        body: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: EncryptionSheet(),
        ),
      );
  }
}

/// Shows a generated password the sender can regenerate or edit, and asks
/// whether to send encrypted. Pops with a [SendEncryption].
class EncryptionSheet extends StatefulWidget {
  const EncryptionSheet({super.key});

  @override
  State<EncryptionSheet> createState() => _EncryptionSheetState();
}

class _EncryptionSheetState extends State<EncryptionSheet> {
  final _controller = TextEditingController(text: generatePassword());
  bool _editing = false;

  String get _password => _controller.text.trim();

  bool get _isShort =>
      !isGeneratedCode(_password) &&
      _password.length < minRecommendedPasswordLength;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _regenerate() {
    setState(() {
      _editing = false;
      _controller.text = generatePassword();
    });
  }

  void _edit() {
    setState(() {
      _editing = true;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  void _sendEncrypted() {
    if (_password.isEmpty) return;
    Navigator.of(context).pop<SendEncryption>((
      password: formatPassword(_password),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (_editing)
          BlastTextField(
            controller: _controller,
            hintText: context.l10n.password,
            autofocus: true,
            textAlign: TextAlign.center,
            style: passwordTextStyle(context, fontSize: 24),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendEncrypted(),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: context.color.surfaceContainer,
              border: Border.all(color: context.color.outline),
            ),
            child: SelectableText(
              _password,
              textAlign: TextAlign.center,
              style: passwordTextStyle(context, fontSize: 28),
            ),
          ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _regenerate,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  size: 18,
                  color: context.color.onSurface,
                ),
                label: Text(context.l10n.new_password),
              ),
            ),
            if (!_editing)
              Expanded(
                child: TextButton.icon(
                  onPressed: _edit,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedPencilEdit01,
                    size: 18,
                    color: context.color.onSurface,
                  ),
                  label: Text(context.l10n.edit_password),
                ),
              ),
          ],
        ),
        if (_isShort && _password.isNotEmpty)
          Text(
            context.l10n.password_short_warning,
            style: TextStyle(color: context.color.error),
          ),
        ElevatedButton(
          onPressed: _password.isEmpty ? null : _sendEncrypted,
          child: Text(context.l10n.send_encrypted),
        ),
        OutlinedButton(
          onPressed:
              () => Navigator.of(
                context,
              ).pop<SendEncryption>((password: null)),
          child: Text(context.l10n.send_unencrypted),
        ),
      ],
    );
  }
}
