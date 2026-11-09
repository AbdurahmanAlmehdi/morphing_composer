// Renders the README's gif frames: `tool/capture.sh`. Not part of the test suite.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphing_composer/morphing_composer.dart';

import 'frames.dart';

const _frame = Duration(milliseconds: 40);

void main() {
  testWidgets('morphing_composer.gif', (tester) async {
    await tester.runAsync(loadSdkFonts);
    final frames = FrameWriter('morphing_composer');
    final library = MemoryPhotoLibrary([
      for (final (i, color) in Colors.primaries.take(12).indexed)
        MemoryPhotoAsset.swatch('p$i', color, semanticLabel: 'Photo $i'),
    ]);
    final attached = <PhotoAsset>[];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', platform: TargetPlatform.iOS),
        home: Align(
          alignment: Alignment.topLeft,
          child: frames.boundary(
            SizedBox(
              width: 393,
              height: 560,
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: MorphingComposer(
                    textController: TextEditingController(),
                    hintText: 'Message',
                    triggerLabel: 'Add',
                    backLabel: 'Close menu',
                    items: [
                      const ComposerItem(id: 'camera', label: 'Camera', icon: Icon(Icons.photo_camera_outlined)),
                      PhotoGridPanel.item(
                        label: 'Photos',
                        icon: const Icon(Icons.photo_outlined),
                        source: PhotoSource.grid,
                        onSystemPicker: () {},
                        panel: (context) => PhotoGridPanel(
                          library: library,
                          max: 4,
                          addLabel: (n) => 'Add $n',
                          limitMessage: 'Up to 4 photos',
                          manageLabel: 'Manage photos',
                          backLabel: 'Back',
                          onAdd: (photos) => setState(() => attached.addAll(photos)),
                        ),
                      ),
                      const ComposerItem(id: 'files', label: 'Files', icon: Icon(Icons.attach_file)),
                      const ComposerItem(id: 'commands', label: 'Commands', icon: Icon(Icons.bolt)),
                    ],
                    attachments: [
                      for (final photo in attached)
                        ComposerAttachment(
                          id: photo.id,
                          thumb: Image(image: photo.thumbnail, fit: BoxFit.cover),
                          removeLabel: 'Remove',
                          onRemove: () {},
                        ),
                    ],
                    trailing: const SizedBox.square(dimension: 48, child: Icon(Icons.arrow_upward)),
                    child: ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      children: const [
                        _Bubble('Here are the totals for this week.', mine: false),
                        _Bubble('How did we do this week?', mine: true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> play(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(_frame);
        await frames.capture(tester);
      }
    }

    await frames.capture(tester, times: 15);
    await tester.tap(find.byKey(MorphingComposer.triggerKey));
    await play(20);
    await frames.capture(tester, times: 10);
    await tester.tap(find.byKey(const ValueKey('morphing_composer.item.photos')));
    await tester.pump();
    await precacheImages(tester);
    await play(22);
    for (final id in ['p4', 'p1']) {
      await tester.tap(find.byKey(ValueKey('photo_grid.photo.$id')));
      await play(6);
    }
    await frames.capture(tester, times: 8);
    await tester.tap(find.text('Add 2'));
    await tester.pump();
    await precacheImages(tester);
    await play(25);
    await frames.capture(tester, times: 40);
  });
}

class _Bubble extends StatelessWidget {
  const new(this.text, {required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF2F9BFF) : const Color(0xFFEDEDF0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
    ),
  );
}
