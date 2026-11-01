import 'dart:io';

import 'package:blast_qr/app_settings.dart';
import 'package:blast_qr/features/files_received/files_page.dart';
import 'package:blast_qr/file_badge_count.dart';
import 'package:blast_qr/l10n/app_localizations.dart';
import 'package:blast_qr/platform_support.dart';
import 'package:blast_qr/widgets/file_list_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The desktop Received page: the file manager style list and its dialogs.
void main() {
  late Directory received;

  setUp(() {
    final documents = Directory.systemTemp.createTempSync('blastqr_test');
    received = Directory('${documents.path}/Received')..createSync();
    // Newest first: f0, f1, ...
    final now = DateTime.now();
    for (var i = 0; i < 4; i++) {
      File('${received.path}/f$i.txt')
        ..writeAsStringSync('x')
        ..setLastModifiedSync(now.subtract(Duration(minutes: i)));
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => documents.path,
        );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => received.parent.deleteSync(recursive: true));

  /// Lets real file system work (loading, watching) finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppSettings()),
          ChangeNotifierProvider(create: (_) => FileBadgeCount(value: null)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FilesPage(),
        ),
      ),
    );
    await settle(tester);
  }

  List<String> selectedNames(WidgetTester tester) => [
    for (final row in tester.widgetList<FileListRow>(find.byType(FileListRow)))
      if (row.selected) row.name,
  ];

  testWidgets('dialogs open from the list and keys work after', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('f1.txt'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('f2.txt'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(selectedNames(tester), ['f1.txt', 'f2.txt']);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 files selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    // The list has focus back without being clicked.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(selectedNames(tester), ['f3.txt']);

    await tester.tap(find.text('f0.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(selectedNames(tester), ['f0.txt']);
  }, skip: !isDesktop);

  testWidgets('files changed by other apps show up', (tester) async {
    await pumpPage(tester);
    expect(find.text('f1.txt'), findsOneWidget);

    await tester.runAsync(() async {
      File('${received.path}/f1.txt').deleteSync();
      File('${received.path}/f2.txt').renameSync('${received.path}/moved.txt');
      File('${received.path}/new.txt').writeAsStringSync('y');
    });
    await settle(tester);

    expect(find.text('f1.txt'), findsNothing);
    expect(find.text('f2.txt'), findsNothing);
    expect(find.text('moved.txt'), findsOneWidget);
    expect(find.text('new.txt'), findsOneWidget);

    // Stops the folder watchers before the folder is deleted.
    await tester.pumpWidget(const SizedBox());
  }, skip: !isDesktop);
}
