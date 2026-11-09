// The bridge to the system's photo library: it runs on a device only, so unit tests cover the
// grid through MemoryPhotoLibrary instead.
// coverage:ignore-file

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:morphing_composer/src/photo_library.dart';
import 'package:photo_manager/photo_manager.dart';

/// The device's photo library through `photo_manager`: images only, most recent first, limited
/// access respected. Used on iOS only; Android keeps the system photo picker.
class DevicePhotoLibrary implements PhotoLibrary {
  static const _option = PermissionRequestOption(
    androidPermission: AndroidPermission(type: RequestType.image, mediaLocation: false),
  );

  AssetPathEntity? _recent;

  @override
  Future<PhotoAccess> access() async => _map(await PhotoManager.getPermissionState(requestOption: _option));

  @override
  Future<PhotoAccess> request() async => _map(await PhotoManager.requestPermissionExtend(requestOption: _option));

  @override
  Future<List<PhotoAsset>> recent({required int page, required int size}) async {
    if (page == 0) _recent = null;
    final path = _recent ??= await _all();
    if (path == null) return const [];
    final assets = await path.getAssetListPaged(page: page, size: size);
    return [for (final asset in assets) _DevicePhoto(asset)];
  }

  @override
  Future<void> manage() => PhotoManager.presentLimited(type: RequestType.image);

  Future<AssetPathEntity?> _all() async {
    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: FilterOptionGroup(orders: [const OrderOption()]),
    );
    return paths.isEmpty ? null : paths.first;
  }

  static PhotoAccess _map(PermissionState state) => switch (state) {
    PermissionState.authorized => PhotoAccess.full,
    PermissionState.limited => PhotoAccess.limited,
    _ => PhotoAccess.denied,
  };
}

class _DevicePhoto implements PhotoAsset {
  new(this.entity);

  final AssetEntity entity;

  @override
  String get id => entity.id;

  @override
  ImageProvider get thumbnail => _Thumbnail(entity);

  @override
  String? get semanticLabel => entity.title;

  @override
  Future<Uint8List?> load({required int maxSide, required int quality}) => entity.thumbnailDataWithOption(
    ThumbnailOption.ios(
      size: ThumbnailSize.square(maxSide),
      quality: quality,
      deliveryMode: DeliveryMode.highQualityFormat,
    ),
  );
}

/// A grid-sized thumbnail of [entity], decoded by Flutter's image cache.
@immutable
class _Thumbnail extends ImageProvider<_Thumbnail> {
  const new(this.entity);

  final AssetEntity entity;

  @override
  Future<_Thumbnail> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Thumbnail key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final bytes = await entity.thumbnailDataWithSize(const ThumbnailSize.square(320), quality: 80);
    if (bytes == null) throw StateError('No thumbnail for ${entity.id}');
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) => other is _Thumbnail && other.entity.id == entity.id;

  @override
  int get hashCode => entity.id.hashCode;
}
