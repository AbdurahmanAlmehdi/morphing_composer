import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Roboto and the Material icons from the Flutter SDK, so captured frames show real text
/// (widget tests otherwise draw every glyph as a box).
Future<void> loadSdkFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = root != null
      ? '$root/bin/cache/artifacts'
      : File(Platform.resolvedExecutable).parent.parent.parent.path;
  final dir = '$artifacts/material_fonts';
  Future<ByteData> font(String name) async => ByteData.sublistView(await File('$dir/$name').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(font('Roboto-$weight.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(font('MaterialIcons-Regular.otf'))).load();
}

/// Writes numbered PNG frames of whatever sits under [key] to `build/frames/<name>/`.
class FrameWriter {
  new(this.name) : dir = Directory('build/frames/$name') {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final String name;
  final Directory dir;
  final GlobalKey key = GlobalKey();
  var _count = 0;

  /// Wraps the scene to capture.
  Widget boundary(Widget child) => RepaintBoundary(key: key, child: child);

  /// Captures the current frame [times] times (a still held for that many frames).
  Future<void> capture(WidgetTester tester, {int times = 1}) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
      for (var i = 0; i < times; i++) {
        File('${dir.path}/${(_count++).toString().padLeft(4, '0')}.png').writeAsBytesSync(png);
      }
    });
  }
}
