import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphing_composer/morphing_composer.dart';

/// Whether golden files are compared: on macOS only, never on CI.
final bool goldensEnabled =
    Platform.isMacOS && !Platform.environment.containsKey('CI') && !Platform.environment.containsKey('GITHUB_ACTIONS');

const swatchColors = [
  Color(0xFFE57373),
  Color(0xFF64B5F6),
  Color(0xFF81C784),
  Color(0xFFFFD54F),
  Color(0xFFBA68C8),
  Color(0xFF4DB6AC),
  Color(0xFFFF8A65),
  Color(0xFF90A4AE),
  Color(0xFFA1887F),
];

/// [count] coloured photos, `p0` the most recent.
List<PhotoAsset> samplePhotos([int count = 9]) => [
  for (var i = 0; i < count; i++)
    MemoryPhotoAsset.swatch('p$i', swatchColors[i % swatchColors.length], semanticLabel: 'Photo $i'),
];

/// What the composer's callers did, for assertions.
class Calls {
  final added = <List<String>>[];
  int camera = 0;
  int systemPicker = 0;
  final opened = <String?>[];
  final removed = <Object>[];
}

/// The four items of a chat menu: Camera, Photos (the grid or the system picker),
/// Files, and Commands (a panel of its own).
List<ComposerItem> sampleItems({
  required PhotoLibrary library,
  required Calls calls,
  PhotoSource source = PhotoSource.grid,
  int max = 3,
}) => [
  ComposerItem(
    id: 'camera',
    label: 'Camera',
    icon: const Icon(Icons.photo_camera_outlined),
    onTap: () => calls.camera++,
  ),
  PhotoGridPanel.item(
    label: 'Photos',
    icon: const Icon(Icons.photo_outlined),
    source: source,
    onSystemPicker: () => calls.systemPicker++,
    panel: (context) => PhotoGridPanel(
      library: library,
      max: max,
      addLabel: (n) => 'Add $n',
      limitMessage: 'Up to $max files',
      manageLabel: 'Manage photos',
      backLabel: 'Back',
      deniedMessage: 'No access to photos',
      onAdd: (photos) => calls.added.add([for (final p in photos) p.id]),
    ),
  ),
  const ComposerItem(id: 'files', label: 'Files', icon: Icon(Icons.attach_file)),
  ComposerItem(
    id: 'commands',
    label: 'Commands',
    icon: const Icon(Icons.bolt),
    panel: (context) => const Center(child: Text('/report')),
  ),
];

/// The thumb an attachment shows for [photo].
ComposerAttachment attachmentFor(PhotoAsset photo, Calls calls) => ComposerAttachment(
  id: photo.id,
  thumb: Image(image: photo.thumbnail, fit: BoxFit.cover),
  removeLabel: 'Remove ${photo.id}',
  onRemove: () => calls.removed.add(photo.id),
  semanticLabel: photo.semanticLabel,
);

/// A chat screen: a list above [MorphingComposer], on an iPhone-sized screen.
Widget composerScreen({
  required ComposerController controller,
  required List<ComposerItem> items,
  Calls? calls,
  TextEditingController? text,
  FocusNode? focusNode,
  List<ComposerAttachment> attachments = const [],
  bool enabled = true,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
}) => Theme(
  data: ThemeData(brightness: brightness, platform: TargetPlatform.iOS),
  child: Directionality(
    textDirection: direction,
    child: Scaffold(
      body: MorphingComposer(
        controller: controller,
        onOpenChanged: calls?.opened.add,
        textController: text ?? TextEditingController(),
        focusNode: focusNode,
        hintText: 'Ask about your store',
        triggerLabel: 'Add',
        backLabel: 'Close menu',
        items: items,
        attachments: attachments,
        enabled: enabled,
        trailing: const SizedBox.square(dimension: 48, child: Icon(Icons.arrow_upward)),
        child: ListView(children: [for (var i = 0; i < 20; i++) ListTile(title: Text('Message $i'))]),
      ),
    ),
  ),
);

/// [composerScreen] as the app's home, with reduced motion when asked.
Widget composerApp(Widget screen, {bool reduceMotion = false}) => MaterialApp(
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: app!,
  ),
  home: screen,
);

/// The surface's rect on screen.
Rect surfaceRect(WidgetTester tester) => tester.getRect(find.byKey(MorphingComposer.surfaceKey));

final Finder surface = find.byKey(MorphingComposer.surfaceKey);
final Finder trigger = find.byKey(MorphingComposer.triggerKey);
Finder photoCell(String id) => find.byKey(ValueKey('photo_grid.photo.$id'));
Finder itemRow(String id) => find.byKey(ValueKey('morphing_composer.item.$id'));

/// The order badge's number inside [id]'s cell, if any.
String? badgeOf(WidgetTester tester, String id) {
  final texts = find.descendant(of: photoCell(id), matching: find.byType(Text));
  if (texts.evaluate().isEmpty) return null;
  return tester.widget<Text>(texts.first).data;
}
