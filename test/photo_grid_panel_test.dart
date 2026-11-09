import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphing_composer/morphing_composer.dart';

import 'helpers/harness.dart';

/// A library whose second page fails, as the platform can.
class _Failing extends MemoryPhotoLibrary {
  new(super.photos);

  @override
  Future<List<PhotoAsset>> recent({required int page, required int size}) async {
    if (page > 0) {
      pageCalls++;
      throw PlatformException(code: 'unavailable');
    }
    return await super.recent(page: page, size: size);
  }
}

void main() {
  late ComposerController controller;
  late Calls calls;

  setUp(() {
    controller = ComposerController();
    calls = Calls();
  });
  tearDown(() => controller.dispose());

  Future<void> openGrid(WidgetTester tester, MemoryPhotoLibrary library, {int max = 3}) async {
    await tester.pumpWidget(
      composerApp(
        composerScreen(
          controller: controller,
          items: sampleItems(library: library, calls: calls, max: max),
        ),
      ),
    );
    controller.open('photos');
    await tester.pumpAndSettle();
  }

  testWidgets('the most recent photos come first', (tester) async {
    await openGrid(tester, MemoryPhotoLibrary(samplePhotos()));
    expect(tester.getTopLeft(photoCell('p0')).dy, lessThan(tester.getTopLeft(photoCell('p8')).dy));
  });

  testWidgets('badges follow the selection order', (tester) async {
    await openGrid(tester, MemoryPhotoLibrary(samplePhotos()));
    await tester.tap(photoCell('p3'));
    await tester.tap(photoCell('p1'));
    await tester.pump();
    expect(badgeOf(tester, 'p3'), '1');
    expect(badgeOf(tester, 'p1'), '2');
    expect(badgeOf(tester, 'p0'), isNull);

    await tester.tap(photoCell('p3'));
    await tester.pump();
    expect(badgeOf(tester, 'p3'), isNull);
    expect(badgeOf(tester, 'p1'), '1');
  });

  testWidgets("with a cap of 3, a 4th pick is refused with the caller's message", (tester) async {
    await openGrid(tester, MemoryPhotoLibrary(samplePhotos()));
    for (final id in ['p0', 'p1', 'p2']) {
      await tester.tap(photoCell(id));
    }
    await tester.pump();
    expect(find.text('Up to 3 files'), findsNothing);

    await tester.tap(photoCell('p5'));
    await tester.pump();
    expect(find.text('Up to 3 files'), findsOneWidget);
    expect(badgeOf(tester, 'p5'), isNull);
    expect(find.text('Add 3'), findsOneWidget);

    await tester.pump(PhotoGridPanel.limitLength);
    expect(find.text('Up to 3 files'), findsNothing);
  });

  testWidgets('"Add 2" returns the two in order and closes the menu', (tester) async {
    await openGrid(tester, MemoryPhotoLibrary(samplePhotos()));
    expect(find.text('Add 0'), findsNothing);
    await tester.tap(photoCell('p5'));
    await tester.tap(photoCell('p2'));
    await tester.pump();
    await tester.tap(find.text('Add 2'));
    await tester.pumpAndSettle();
    expect(calls.added, [
      ['p5', 'p2'],
    ]);
    expect(controller.isOpen, isFalse);
  });

  testWidgets('limited access shows "manage", which asks again and reloads', (tester) async {
    final library = MemoryPhotoLibrary(samplePhotos(3), accessLevel: PhotoAccess.limited);
    await openGrid(tester, library);
    expect(find.text('Manage photos'), findsOneWidget);
    expect(library.accessCalls, 1);

    await tester.tap(find.text('Manage photos'));
    await tester.pumpAndSettle();
    expect(library.manageCalls, 1);
    expect(library.accessCalls, 2);
    expect(photoCell('p2'), findsOneWidget);
  });

  testWidgets('full access shows no "manage" row', (tester) async {
    await openGrid(tester, MemoryPhotoLibrary(samplePhotos(3)));
    expect(find.text('Manage photos'), findsNothing);
  });

  testWidgets('denied access shows the message and reads no photos', (tester) async {
    final library = MemoryPhotoLibrary(samplePhotos(), accessLevel: PhotoAccess.denied);
    await openGrid(tester, library);
    expect(find.text('No access to photos'), findsOneWidget);
    expect(library.pageCalls, 0);
  });

  testWidgets('more photos load as the grid scrolls', (tester) async {
    final library = MemoryPhotoLibrary(samplePhotos(200));
    await openGrid(tester, library);
    expect(library.pageCalls, 1);
    await tester.drag(find.byType(GridView), const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(library.pageCalls, 2);
    final delegate = tester.widget<GridView>(find.byType(GridView)).childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 120);
  });

  testWidgets('a page that fails keeps what loaded and asks no more', (tester) async {
    final library = _Failing(samplePhotos(200));
    await openGrid(tester, library);
    await tester.drag(find.byType(GridView), const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(library.pageCalls, 2);
    await tester.drag(find.byType(GridView), const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(library.pageCalls, 2, reason: 'no page is asked again after a failure');
    final delegate = tester.widget<GridView>(find.byType(GridView)).childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 60);
  });

  testWidgets('the back button returns to the items', (tester) async {
    await openGrid(tester, MemoryPhotoLibrary(samplePhotos()));
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(controller.level, ComposerController.menu);
  });

  testWidgets('PhotoSource.system calls the picker callback and never reads the library', (tester) async {
    final library = MemoryPhotoLibrary(samplePhotos());
    await tester.pumpWidget(
      composerApp(
        composerScreen(
          controller: controller,
          items: sampleItems(library: library, calls: calls, source: PhotoSource.system),
        ),
      ),
    );
    controller.openMenu();
    await tester.pumpAndSettle();
    await tester.tap(itemRow('photos'));
    await tester.pumpAndSettle();
    expect(calls.systemPicker, 1);
    expect(controller.isOpen, isFalse);
    expect(find.byType(PhotoGridPanel), findsNothing);
    expect(library.accessCalls + library.requestCalls + library.pageCalls + library.manageCalls, 0);
  });

  test('the grid on iOS, the system picker elsewhere', () {
    expect(PhotoSource.of(TargetPlatform.iOS), PhotoSource.grid);
    expect(PhotoSource.of(TargetPlatform.android), PhotoSource.system);
  });

  test('the memory library answers what it was given', () async {
    final library = MemoryPhotoLibrary(samplePhotos(5), accessLevel: PhotoAccess.limited);
    expect(await library.request(), PhotoAccess.limited);
    expect((await library.recent(page: 1, size: 2)).map((p) => p.id), ['p2', 'p3']);
    expect(await library.photos.first.load(maxSide: 2048, quality: 85), isNotEmpty);
    expect(library.requestCalls, 1);
  });

  test('a swatch is a 2 × 2 bitmap of its colour', () {
    final bytes = solidBitmap(const Color(0xFF102030));
    expect(String.fromCharCodes(bytes.take(2)), 'BM');
    expect(bytes.length, 70);
    expect(bytes.sublist(54, 57), [0x30, 0x20, 0x10]);
  });
}
