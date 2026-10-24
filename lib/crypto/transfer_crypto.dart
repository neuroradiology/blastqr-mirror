import 'dart:typed_data';

import 'package:blast_qr/crypto/password.dart';
import 'package:blastqr_crypto/blastqr_crypto.dart';

export 'package:blastqr_crypto/blastqr_crypto.dart' show TransferCryptoError;

/// Encrypts and decrypts transfer objects (Argon2id + ChaCha20-Poly1305, in
/// Rust via blastqr_crypto). Passwords are normalized first, so a generated
/// code can be typed loosely on the receiver.
abstract final class TransferCrypto {
  /// Bytes encryption adds to a transfer object.
  static int get overhead => envelopeOverhead();

  static Future<Uint8List> encrypt(Uint8List plain, String password) =>
      encryptTransfer(plain: plain, password: normalizePassword(password));

  /// Throws [TransferCryptoError] if the password is wrong or the data is
  /// damaged.
  static Future<Uint8List> decrypt(Uint8List envelope, String password) =>
      decryptTransfer(envelope: envelope, password: normalizePassword(password));
}
