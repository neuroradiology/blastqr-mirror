import 'dart:typed_data';

import 'package:blast_qr/crypto/password.dart';
import 'package:blastqr_crypto/blastqr_crypto.dart';

export 'package:blastqr_crypto/blastqr_crypto.dart' show TransferCryptoError;

abstract final class TransferCrypto {
  static Future<Uint8List> encrypt(Uint8List plain, String password) =>
      encryptTransfer(plain: plain, password: normalizePassword(password));

  /// Encrypts the file at [inputPath] into a new file at [outputPath],
  /// without reading either into memory.
  static Future<void> encryptFile(
    String inputPath,
    String outputPath,
    String password,
  ) => encryptTransferFile(
    inputPath: inputPath,
    outputPath: outputPath,
    password: normalizePassword(password),
  );

  static Future<Uint8List> decrypt(Uint8List envelope, String password) =>
      decryptTransfer(
        envelope: envelope,
        password: normalizePassword(password),
      );
}
