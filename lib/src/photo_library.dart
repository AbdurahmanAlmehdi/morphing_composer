import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// How much of the photo library the app may read.
enum PhotoAccess {
  full,

  /// Only the photos the user chose (iOS «limited access»); the grid offers a "manage" row.
  limited,
  denied,
}

/// One photo in a [PhotoLibrary].
abstract interface class PhotoAsset {
  String get id;

  /// A small picture for the grid and the attachment thumb.
  ImageProvider get thumbnail;

  /// What it shows, for screen readers, if known.
  String? get semanticLabel;

  /// The photo as a JPEG at most [maxSide] on its long side, at [quality] 0–100 (as
  /// `image_picker`'s `maxWidth` and `imageQuality`), or `null` when it can't be read. The app owns
  /// both rules, so there are no defaults here.
  Future<Uint8List?> load({required int maxSide, required int quality});
}

/// Where the photo grid reads photos from: `DevicePhotoLibrary` (photo_manager, iOS) in the app, a
/// [MemoryPhotoLibrary] in tests and previews.
abstract interface class PhotoLibrary {
  /// The current access, without asking.
  Future<PhotoAccess> access();

  /// Asks the system for access (once the app's own explanation has been shown).
  Future<PhotoAccess> request();

  /// The most recent photos first, [size] to a page.
  Future<List<PhotoAsset>> recent({required int page, required int size});

  /// Lets the user change which photos the app may see (under [PhotoAccess.limited]).
  Future<void> manage();
}

/// A photo held in memory.
class MemoryPhotoAsset implements PhotoAsset {
  const new({required this.id, required this.thumbnail, this.bytes, this.semanticLabel});

  /// A square of [color], for previews and tests.
  factory swatch(String id, Color color, {String? semanticLabel}) {
    final image = MemoryImage(solidBitmap(color));
    return MemoryPhotoAsset(id: id, thumbnail: image, bytes: image.bytes, semanticLabel: semanticLabel);
  }

  @override
  final String id;
  @override
  final ImageProvider thumbnail;
  @override
  final String? semanticLabel;
  final Uint8List? bytes;

  @override
  Future<Uint8List?> load({required int maxSide, required int quality}) async => bytes;
}

/// A [PhotoLibrary] over a fixed list, for tests and previews. It counts what it was asked.
class MemoryPhotoLibrary implements PhotoLibrary {
  new(this.photos, {this.accessLevel = PhotoAccess.full});

  /// Most recent first.
  final List<PhotoAsset> photos;
  PhotoAccess accessLevel;

  /// How many times each method ran.
  int accessCalls = 0;
  int requestCalls = 0;
  int pageCalls = 0;
  int manageCalls = 0;

  @override
  Future<PhotoAccess> access() async {
    accessCalls++;
    return accessLevel;
  }

  @override
  Future<PhotoAccess> request() async {
    requestCalls++;
    return accessLevel;
  }

  @override
  Future<List<PhotoAsset>> recent({required int page, required int size}) async {
    pageCalls++;
    if (accessLevel == PhotoAccess.denied) return const [];
    return photos.skip(page * size).take(size).toList();
  }

  @override
  Future<void> manage() async => manageCalls++;
}

/// A 2 × 2 bitmap (BMP) of [color]: a picture that decodes everywhere, with no asset.
Uint8List solidBitmap(Color color) {
  const side = 2;
  const row = 8; // 2 pixels × 3 bytes, padded to 4.
  const pixels = row * side;
  final data = ByteData(54 + pixels)
    ..setUint8(0, 0x42) // 'B'
    ..setUint8(1, 0x4D) // 'M'
    ..setUint32(2, 54 + pixels, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, side, Endian.little)
    ..setInt32(22, side, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, pixels, Endian.little);
  int channel(double value) => (value * 255).round().clamp(0, 255);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final at = 54 + y * row + x * 3;
      data
        ..setUint8(at, channel(color.b))
        ..setUint8(at + 1, channel(color.g))
        ..setUint8(at + 2, channel(color.r));
    }
  }
  return data.buffer.asUint8List();
}
