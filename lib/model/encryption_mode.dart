import 'package:blast_qr/l10n/extension.dart';
import 'package:flutter/widgets.dart';

/// Whether files are sent encrypted (Settings > Sending > Encryption).
enum EncryptionMode {
  /// Ask before each send, with encryption pre-selected.
  ask,

  /// Always encrypt, with a generated password, without asking.
  always,

  /// Never encrypt, without asking.
  never;

  String title(BuildContext context) => switch (this) {
    EncryptionMode.ask => context.l10n.encryption_ask,
    EncryptionMode.always => context.l10n.encryption_always,
    EncryptionMode.never => context.l10n.encryption_never,
  };
}
