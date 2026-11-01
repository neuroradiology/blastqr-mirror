import 'dart:io';

// The camera plugins have no image stream on Windows yet.
bool get canScanWithCamera => !Platform.isWindows;

bool get isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;
