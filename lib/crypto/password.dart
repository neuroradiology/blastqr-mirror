import 'dart:math';

/// Crockford base32: no I, L, O or U, so a code read aloud or retyped is
/// hard to get wrong.
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Characters in a generated password (60 bits).
const generatedPasswordLength = 12;

/// Custom passwords shorter than this get a warning (but are allowed).
const minRecommendedPasswordLength = 8;

/// A new random password, e.g. `K7M2-QX9P-4RTA`.
String generatePassword() {
  final random = Random.secure();
  final code = String.fromCharCodes(
    List.generate(
      generatedPasswordLength,
      (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
    ),
  );
  return formatPassword(code);
}

/// Shows a generated code in groups of 4 (`K7M2-QX9P-4RTA`). Other
/// passwords are returned unchanged.
String formatPassword(String password) {
  final code = _asCode(password);
  if (code == null) return password;
  return [
    for (var i = 0; i < code.length; i += 4) code.substring(i, i + 4),
  ].join('-');
}

/// The exact text the key is derived from. Both sender and receiver use it.
///
/// A generated code can be typed loosely: any case, with or without dashes
/// or spaces, and O/I/L for 0/1/1. Anything else is a custom password and
/// is only trimmed.
String normalizePassword(String password) =>
    _asCode(password) ?? password.trim();

/// Whether [password] has the shape of a generated code.
bool isGeneratedCode(String password) => _asCode(password) != null;

/// The canonical code (12 uppercase characters, no dashes), or null if
/// [password] isn't shaped like a generated code.
String? _asCode(String password) {
  final buffer = StringBuffer();
  for (final rune in password.trim().toUpperCase().runes) {
    var c = String.fromCharCode(rune);
    if (c == '-' || c == ' ') continue;
    c = switch (c) {
      'O' => '0',
      'I' || 'L' => '1',
      _ => c,
    };
    if (!_alphabet.contains(c)) return null;
    buffer.write(c);
  }
  final code = buffer.toString();
  return code.length == generatedPasswordLength ? code : null;
}
