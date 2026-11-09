// Golden helpers register tests synchronously.
// ignore_for_file: discarded_futures

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:morphing_composer/morphing_composer.dart';

import '../helpers/harness.dart';

/// A phone's lower part: the chat, and the composer at [level], with two attachments if asked.
Widget _phone({
  required Brightness brightness,
  required TextDirection direction,
  String? level,
  bool withAttachments = false,
}) {
  final calls = Calls();
  final photos = samplePhotos();
  return SizedBox(
    width: 393,
    height: 560,
    child: composerScreen(
      controller: ComposerController(open: level),
      items: sampleItems(library: MemoryPhotoLibrary(photos), calls: calls),
      attachments: withAttachments ? [attachmentFor(photos[4], calls), attachmentFor(photos[1], calls)] : const [],
      brightness: brightness,
      direction: direction,
    ),
  );
}

void main() {
  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      final variant = '${direction.name}_${brightness.name}';
      goldenTest(
        'the composer closed, its items, the photos panel and the strip, $variant',
        fileName: 'composer_$variant',
        skip: !goldensEnabled,
        pumpBeforeTest: (tester) async {
          await tester.pumpAndSettle();
          await precacheImages(tester);
          await tester.tap(photoCell('p4'));
          await tester.tap(photoCell('p1'));
          await tester.pumpAndSettle();
        },
        builder: () => GoldenTestGroup(
          columns: 2,
          children: [
            GoldenTestScenario(
              name: 'closed',
              child: _phone(brightness: brightness, direction: direction),
            ),
            GoldenTestScenario(
              name: 'items',
              child: _phone(brightness: brightness, direction: direction, level: ComposerController.menu),
            ),
            GoldenTestScenario(
              name: 'photos panel, 2 picked',
              child: _phone(brightness: brightness, direction: direction, level: 'photos'),
            ),
            GoldenTestScenario(
              name: 'attachments strip',
              child: _phone(brightness: brightness, direction: direction, withAttachments: true),
            ),
          ],
        ),
      );
    }
  }
}
