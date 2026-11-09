import 'package:flutter/widgets.dart';

/// One row of the composer's item list. An item with a [panel] opens it (the surface morphs into
/// the panel, registered under [id]); one without calls [onTap] and closes the menu.
@immutable
class ComposerItem {
  const new({required this.id, required this.label, required this.icon, this.panel, this.onTap});

  /// The item's and its panel's id, for `ComposerController.open`.
  final String id;
  final String label;
  final Widget icon;

  /// Builds the panel the surface grows into; it fills the space above the keyboard.
  final WidgetBuilder? panel;

  /// Called for an item without a [panel], as the menu closes.
  final VoidCallback? onTap;
}

/// A file waiting above the field: its [thumb], and a remove button named [removeLabel]. Give a
/// picked photo the photo's id, so it morphs from its grid cell into this thumb.
@immutable
class ComposerAttachment {
  const new({
    required this.id,
    required this.thumb,
    required this.removeLabel,
    required this.onRemove,
    this.semanticLabel,
  });

  final Object id;

  /// The square picture (an image, or a file's icon and name); clipped to the thumb's corners.
  final Widget thumb;

  /// The remove button's name for screen readers.
  final String removeLabel;
  final VoidCallback onRemove;

  /// What the thumb shows, for screen readers.
  final String? semanticLabel;
}
