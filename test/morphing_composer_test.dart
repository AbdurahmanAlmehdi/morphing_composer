import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphing_composer/morphing_composer.dart';

import 'helpers/harness.dart';

void main() {
  late ComposerController controller;
  late MemoryPhotoLibrary library;
  late Calls calls;

  setUp(() {
    controller = ComposerController();
    library = MemoryPhotoLibrary(samplePhotos());
    calls = Calls();
  });
  tearDown(() => controller.dispose());

  Widget screen({
    TextDirection direction = TextDirection.ltr,
    FocusNode? focusNode,
    List<ComposerAttachment> attachments = const [],
    bool enabled = true,
    bool reduceMotion = false,
  }) => composerApp(
    composerScreen(
      controller: controller,
      calls: calls,
      items: sampleItems(library: library, calls: calls),
      direction: direction,
      focusNode: focusNode,
      attachments: attachments,
      enabled: enabled,
    ),
    reduceMotion: reduceMotion,
  );

  group('levels', () {
    testWidgets('the trigger opens the items', (tester) async {
      await tester.pumpWidget(screen());
      expect(surface, findsNothing);

      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(controller.level, ComposerController.menu);
      expect(calls.opened, [ComposerController.menu]);
      for (final label in ['Camera', 'Photos', 'Files', 'Commands']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets("open('photos') shows the panel; back() returns to the items", (tester) async {
      await tester.pumpWidget(screen());
      controller.open('photos');
      await tester.pumpAndSettle();
      expect(find.byType(PhotoGridPanel), findsOneWidget);
      expect(find.text('Camera'), findsNothing);

      controller.back();
      await tester.pumpAndSettle();
      expect(find.byType(PhotoGridPanel), findsNothing);
      expect(find.text('Camera'), findsOneWidget);

      controller.back();
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(calls.opened, ['photos', ComposerController.menu, null]);
    });

    testWidgets('an item with a panel opens it; one without calls back and closes', (tester) async {
      await tester.pumpWidget(screen());
      controller.openMenu();
      await tester.pumpAndSettle();
      await tester.tap(itemRow('commands'));
      await tester.pumpAndSettle();
      expect(controller.level, 'commands');
      expect(find.text('/report'), findsOneWidget);

      controller.back();
      await tester.pumpAndSettle();
      await tester.tap(itemRow('camera'));
      await tester.pumpAndSettle();
      expect(calls.camera, 1);
      expect(controller.isOpen, isFalse);
      expect(surface, findsNothing);
    });

    testWidgets('a level the composer starts at shows at once', (tester) async {
      controller = ComposerController(open: ComposerController.menu);
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.text('Camera'), findsOneWidget);
    });

    testWidgets('a disabled composer ignores the trigger and closes', (tester) async {
      await tester.pumpWidget(screen(enabled: false));
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);

      await tester.pumpWidget(screen());
      controller.openMenu();
      await tester.pumpAndSettle();
      await tester.pumpWidget(screen(enabled: false));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isFalse);
    });

    testWidgets('a controller handed in later takes over', (tester) async {
      await tester.pumpWidget(screen());
      final other = ComposerController(open: ComposerController.menu);
      controller = other;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Camera'), findsOneWidget);
    });
  });

  group('stepping back', () {
    testWidgets('Back closes one level at a time', (tester) async {
      await tester.pumpWidget(screen());
      controller.open('photos');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.level, ComposerController.menu);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.level, isNull);
      expect(surface, findsNothing);
    });

    testWidgets('a tap outside closes one level at a time', (tester) async {
      await tester.pumpWidget(screen());
      controller.openMenu();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(300, 100));
      await tester.pumpAndSettle();
      expect(controller.level, isNull);

      controller.open('photos');
      await tester.pumpAndSettle();
      // The panel fills the screen; the edge beside it is outside.
      await tester.tapAt(const Offset(4, 300));
      await tester.pumpAndSettle();
      expect(controller.level, ComposerController.menu);
    });

    for (final direction in TextDirection.values) {
      testWidgets('an edge swipe from the start edge steps back, ${direction.name}', (tester) async {
        await tester.pumpWidget(screen(direction: direction));
        controller.open('photos');
        await tester.pumpAndSettle();
        final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final rtl = direction == TextDirection.rtl;
        await tester.dragFrom(Offset(rtl ? width - 4 : 4, 300), Offset(rtl ? -120 : 120, 0));
        await tester.pumpAndSettle();
        expect(controller.level, ComposerController.menu);
      });
    }

    testWidgets('a tap on the trigger while closed opens, and the barrier names itself', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(screen());
      expect(
        tester.getSemantics(trigger),
        matchesSemantics(
          label: 'Add',
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Close menu'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('focus and keyboard', () {
    testWidgets('the field keeps focus while the menu and a panel are open', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(screen(focusNode: focus));
      await tester.showKeyboard(find.byType(TextField));
      expect(focus.hasFocus, isTrue);

      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.tap(itemRow('photos'));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.tap(photoCell('p0'));
      await tester.pump();
      await tester.tapAt(const Offset(4, 300));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('the list rides above the keyboard', (tester) async {
      await tester.pumpWidget(screen());
      controller.openMenu();
      await tester.pumpAndSettle();
      final before = surfaceRect(tester);

      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final after = surfaceRect(tester);
      final keyboard = 900 / tester.view.devicePixelRatio;
      expect(after.bottom, moreOrLessEquals(before.bottom - keyboard));
      expect(after.size, before.size);
    });
  });

  group('motion', () {
    testWidgets('the surface grows out of the trigger on a spring', (tester) async {
      await tester.pumpWidget(screen());
      final from = tester.getRect(trigger);
      await tester.tap(trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      final early = surfaceRect(tester);
      await tester.pumpAndSettle();
      final settled = surfaceRect(tester);
      expect(early.width, greaterThan(from.width - 1));
      expect(early.width, lessThan(settled.width));
      // It grows from the bar's start: in LTR its left edge stays by the trigger.
      expect(settled.left, moreOrLessEquals(from.left - 4));
      expect(settled.bottom, lessThan(from.top));
    });

    testWidgets('in RTL the list sits at the right, by the trigger', (tester) async {
      await tester.pumpWidget(screen(direction: TextDirection.rtl));
      final from = tester.getRect(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(surfaceRect(tester).right, moreOrLessEquals(from.right + 4));
    });

    testWidgets('with reduced motion the surface switches without the spring', (tester) async {
      await tester.pumpWidget(screen());
      controller.openMenu();
      await tester.pumpAndSettle();
      final menu = surfaceRect(tester);
      controller.open('photos');
      await tester.pumpAndSettle();
      final panel = surfaceRect(tester);
      controller.close();
      await tester.pumpAndSettle();

      await tester.pumpWidget(screen(reduceMotion: true));
      await tester.tap(trigger);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(surfaceRect(tester), menu);
      controller.open('photos');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(surfaceRect(tester), panel);

      // It fades out in place.
      controller.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(surfaceRect(tester), panel);
      await tester.pump(MorphingComposer.fadeLength);
      await tester.pump();
      expect(surface, findsNothing);
    });

    testWidgets('a new level mid-move starts from where the surface is', (tester) async {
      await tester.pumpWidget(screen());
      controller.openMenu();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = surfaceRect(tester);
      controller.open('photos');
      await tester.pump();
      expect(surfaceRect(tester).width, moreOrLessEquals(mid.width, epsilon: 1));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoGridPanel), findsOneWidget);
    });
  });

  group('attachments', () {
    testWidgets('the strip shows above the field and grows the bar', (tester) async {
      await tester.pumpWidget(screen());
      final bare = tester.getRect(find.byType(TextField));
      final photos = samplePhotos(2);
      await tester.pumpWidget(screen(attachments: [for (final p in photos) attachmentFor(p, calls)]));
      await tester.pumpAndSettle();
      final thumb = tester.getRect(find.bySemanticsLabel('Photo 0'));
      expect(thumb.bottom, lessThanOrEqualTo(tester.getRect(find.byType(TextField)).top));
      expect(tester.getRect(find.byType(TextField)).bottom, moreOrLessEquals(bare.bottom));

      await tester.tap(find.bySemanticsLabel('Remove p1'));
      expect(calls.removed, ['p1']);
    });

    testWidgets('picked photos fly from their cells into their thumbs', (tester) async {
      final photos = samplePhotos();
      var attachments = <ComposerAttachment>[];
      late StateSetter rebuild;
      final items = sampleItems(library: library, calls: calls);
      // The caller adds the picks as attachments in the same frame, as the app does.
      final adding = [
        for (final item in items)
          if (item.id == 'photos')
            ComposerItem(
              id: item.id,
              label: item.label,
              icon: item.icon,
              panel: (context) => PhotoGridPanel(
                library: library,
                max: 3,
                addLabel: (n) => 'Add $n',
                limitMessage: 'Up to 3 files',
                manageLabel: 'Manage photos',
                backLabel: 'Back',
                onAdd: (picked) => rebuild(() {
                  attachments = [for (final p in picked) attachmentFor(photos.firstWhere((x) => x.id == p.id), calls)];
                }),
              ),
            )
          else
            item,
      ];
      await tester.pumpWidget(
        composerApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return composerScreen(controller: controller, items: adding, attachments: attachments);
            },
          ),
        ),
      );
      controller.open('photos');
      await tester.pumpAndSettle();
      await tester.tap(photoCell('p4'));
      await tester.tap(photoCell('p1'));
      await tester.pump();
      await tester.tap(find.text('Add 2'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      double opacityOf(String id) => tester
          .widget<Opacity>(find.descendant(of: find.byKey(ValueKey<Object>(id)), matching: find.byType(Opacity)))
          .opacity;
      expect(opacityOf('p4'), 0);
      expect(opacityOf('p1'), 0);
      await tester.pumpAndSettle();
      expect(opacityOf('p4'), 1);
      expect(controller.isOpen, isFalse);
    });
  });

  test('the controller steps back one level and ignores repeats', () {
    final c = ComposerController();
    var notified = 0;
    c
      ..addListener(() => notified++)
      ..back()
      ..open('photos')
      ..open('photos');
    expect(notified, 1);
    c.back();
    expect(c.level, ComposerController.menu);
    c.back();
    expect(c.level, isNull);
    c
      ..level = 'files'
      ..close();
    expect(c.isOpen, isFalse);
    c.dispose();
  });
}
