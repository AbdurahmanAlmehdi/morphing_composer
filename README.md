# morphing_composer

[![pub package](https://img.shields.io/pub/v/morphing_composer.svg)](https://pub.dev/packages/morphing_composer)
[![CI](https://github.com/AbdurahmanAlmehdi/morphing_composer/actions/workflows/ci.yaml/badge.svg)](https://github.com/AbdurahmanAlmehdi/morphing_composer/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A chat composer for Flutter whose bar morphs into its attachment menu and panels, like ChatGPT's.
One surface grows out of the + button into the menu, then into a panel such as the in-app photo
grid, while the keyboard stays up. Picked photos fly into their thumbnails above the field.

<img src="https://raw.githubusercontent.com/AbdurahmanAlmehdi/morphing_composer/main/doc/morphing_composer.gif" width="393" alt="The composer's + button morphing into a menu, then a photo grid; two picked photos fly into the bar">

Depends only on Flutter and [`photo_manager`](https://pub.dev/packages/photo_manager) (for the
device photo library). The look comes from a `ComposerTheme` and every word from you, so it fits
any design system and any language (it mirrors in RTL).

Inspired by the React Native [expo-morphing-menu](https://github.com/rit3zh/expo-morphing-menu).

## Install

```sh
flutter pub add morphing_composer
```

## Use

```dart
MorphingComposer(
  textController: text,
  hintText: 'Message',
  triggerLabel: 'Add',
  backLabel: 'Close menu',
  items: [
    ComposerItem(id: 'camera', label: 'Camera', icon: const Icon(Icons.photo_camera_outlined), onTap: openCamera),
    PhotoGridPanel.item(
      label: 'Photos',
      icon: const Icon(Icons.photo_outlined),
      source: PhotoSource.of(Theme.of(context).platform), // the grid on iOS, the system picker elsewhere
      onSystemPicker: openSystemPicker,
      panel: (context) => PhotoGridPanel(
        library: DevicePhotoLibrary(),
        max: 4,
        addLabel: (n) => 'Add $n',
        limitMessage: 'Up to 4 photos',
        manageLabel: 'Manage photos',
        backLabel: 'Back',
        onAdd: (photos) => setState(() => attached.addAll(photos)),
      ),
    ),
  ],
  attachments: [
    for (final photo in attached)
      ComposerAttachment(
        id: photo.id, // the same id, so the photo flies from its cell into this thumb
        thumb: Image(image: photo.thumbnail, fit: BoxFit.cover),
        removeLabel: 'Remove',
        onRemove: () => setState(() => attached.remove(photo)),
      ),
  ],
  trailing: IconButton(onPressed: send, icon: const Icon(Icons.arrow_upward)),
  child: conversation, // what sits above the bar
)
```

Put it where the screen's body ends: it fills the space it gets, and `child` takes what the bar
leaves.

## Platform setup

`DevicePhotoLibrary` reads the photo library through `photo_manager`. On iOS add a usage string to
`ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Attach photos to your messages.</string>
```

To use it on Android too, follow [photo_manager's setup](https://pub.dev/packages/photo_manager#android-config-preparation).
Or keep the system photo picker there (`PhotoSource.system`, the default off iOS via
`PhotoSource.of`), which needs no permission. Implement `PhotoLibrary` yourself to back the grid
with anything else.

## How it behaves

- The bar: a trigger at the start, the field, and a trailing slot (voice, send). An attachments
  strip above the field grows the bar.
- One surface grows out of the trigger into the item list (above the bar, at its start), then into
  an item's panel (the space above the keyboard, over the bar). One spring drives its size, corner
  and position; there is no separate sheet. A new level mid-move starts from where the surface is.
- The field keeps focus throughout, so the keyboard stays up; the surface rides above it.
- Back, an edge swipe from the start edge and a tap outside each step back one level (a panel to the
  list, the list to the bar).
- Reduced motion (`MediaQuery.disableAnimations`): the surface takes its place at once and fades
  (200 ms) instead of morphing; nothing flies.
- Directional: the trigger, the list and the edge swipe sit at the start, so RTL mirrors them.

## API

| | |
|---|---|
| `MorphingComposer` | The composer. `child` is the conversation above the bar. Words: `hintText`, `triggerLabel`, `backLabel` (the area outside an open menu, for screen readers). `items`, `attachments`, `trailing`, `enabled`, `controller`, `onOpenChanged`, `focusNode`, `theme`, `triggerIcon`, `removeIcon`, `menuWidth`, `padding`. `surfaceKey` and `triggerKey` find it in tests. |
| `ComposerController` | The open level: `null`, `ComposerController.menu` or a panel's id. `openMenu()`, `open(id)`, `back()`, `close()`, `level` (settable: a controlled open state). |
| `ComposerItem` | `id`, `label`, `icon`, and either a `panel` builder (opens it) or `onTap` (called as the menu closes). |
| `ComposerAttachment` | A thumb above the field: `id`, `thumb`, `removeLabel`, `onRemove`, `semanticLabel`. |
| `ComposerScope` | What a panel reaches: `controller`, and `flyFrom(id, globalRect, picture)`, which morphs a picture into the thumb of the attachment with that id once the caller adds it **in the same frame**. |
| `ComposerTheme` | `ThemeExtension`: `barColor`, `surfaceColor`, `itemStyle`, `barRadius`, `surfaceRadius`, `textStyle`, `hintStyle`, `iconColor`, `selectionColor`, `onSelectionColor`, `shadows`. `ComposerTheme.of(context)` reads the composer's own theme, then the extension, then the colour scheme. |
| `PhotoGridPanel` | The photos panel over a `PhotoLibrary`: recent first, paged (`pageSize`), multi-select with order badges, capped at `max` (a pick past it shows `limitMessage`), "Add N" (`addLabel`) hands the picks to `onAdd` in order, flies them into their thumbs and closes the menu. A `manageLabel` row under limited access; `deniedMessage` when denied; `backLabel`/`backIcon`. |
| `PhotoGridPanel.item` | The Photos item: `PhotoSource.grid` opens the panel; `PhotoSource.system` calls `onSystemPicker` and closes the menu without reading any library. `PhotoSource.of(platform)` is the grid on iOS, the system picker elsewhere. |
| `PhotoLibrary`, `PhotoAsset`, `PhotoAccess` | The library interface: `access()` (never asks), `request()` (asks), `recent(page, size)`, `manage()`. An asset has an `id`, a `thumbnail` `ImageProvider`, a `semanticLabel` and `load(maxSide, quality)` (JPEG bytes). |
| `DevicePhotoLibrary` | `photo_manager`, images only, most recent first, limited access respected (iOS). |
| `MemoryPhotoLibrary`, `MemoryPhotoAsset` | For tests and previews; `MemoryPhotoAsset.swatch(id, color)` is a one-colour picture. The library counts its calls. |

## Example

[`example/`](example/lib/main.dart) is a small chat: Camera, Photos (the device's photos on iOS,
colour swatches elsewhere) and a Commands panel.

## Contributing

`flutter analyze` and `flutter test`. The goldens (tagged `golden`) compare on macOS only and are
skipped on CI. `tool/capture.sh` re-renders the gif above.

## License

[MIT](LICENSE)
