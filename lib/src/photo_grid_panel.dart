import 'dart:async';

import 'package:flutter/material.dart';
import 'package:morphing_composer/src/composer_item.dart';
import 'package:morphing_composer/src/composer_theme.dart';
import 'package:morphing_composer/src/morphing_composer.dart';
import 'package:morphing_composer/src/photo_library.dart';

/// Where the composer's photos come from.
enum PhotoSource {
  /// The in-app grid over a [PhotoLibrary] (iOS).
  grid,

  /// The system photo picker, which the caller opens (Android: no photo permission).
  system;

  /// The grid on iOS, the system picker elsewhere.
  static PhotoSource of(TargetPlatform platform) => platform == TargetPlatform.iOS ? grid : system;
}

/// The composer's photo panel: the [library]'s photos, most recent first and paged, picked in
/// order (each shows its number), up to [max]. A pick past [max] is refused with [limitMessage].
/// "Add N" ([addLabel]) hands the picks to [onAdd] in order, flies each into its attachment thumb
/// and closes the menu. Under limited access a [manageLabel] row lets the user change which photos
/// the app sees. Put it in a `MorphingComposer` item through [PhotoGridPanel.item].
class PhotoGridPanel extends StatefulWidget {
  const new({
    required this.library,
    required this.max,
    required this.addLabel,
    required this.limitMessage,
    required this.manageLabel,
    required this.backLabel,
    required this.onAdd,
    super.key,
    this.deniedMessage,
    this.backIcon,
    this.columns = 3,
    this.pageSize = 60,
  });

  /// The «Photos» item: with [PhotoSource.grid] it opens [panel] (a [PhotoGridPanel]); with
  /// [PhotoSource.system] it calls [onSystemPicker] and closes the menu, never reading a library.
  static ComposerItem item({
    required String label,
    required Widget icon,
    required PhotoSource source,
    required VoidCallback onSystemPicker,
    required WidgetBuilder panel,
    String id = 'photos',
  }) => ComposerItem(
    id: id,
    label: label,
    icon: icon,
    panel: source == PhotoSource.grid ? panel : null,
    onTap: source == PhotoSource.system ? onSystemPicker : null,
  );

  final PhotoLibrary library;

  /// How many may be picked (the files still allowed).
  final int max;
  final String Function(int count) addLabel;
  final String limitMessage;
  final String manageLabel;

  /// The back button's name (back to the item list).
  final String backLabel;
  final ValueChanged<List<PhotoAsset>> onAdd;

  /// Shown when the app may not read the library.
  final String? deniedMessage;

  /// The back button's icon; an arrow (mirrored in RTL) by default.
  final Widget? backIcon;
  final int columns;
  final int pageSize;

  /// How long the refusal stays.
  static const limitLength = Duration(milliseconds: 2500);

  @override
  State<PhotoGridPanel> createState() => _PhotoGridPanelState();
}

class _PhotoGridPanelState extends State<PhotoGridPanel> {
  PhotoAccess? _access;
  final _photos = <PhotoAsset>[];
  final _picked = <PhotoAsset>[];
  final _cellKeys = <String, GlobalKey>{};
  int _page = 0;
  bool _loading = false;
  bool _ended = false;
  bool _refused = false;
  Timer? _refusal;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _refusal?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final access = await widget.library.access();
    if (!mounted) return;
    setState(() {
      _access = access;
      _photos.clear();
      _page = 0;
      _ended = access == PhotoAccess.denied;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _ended) return;
    _loading = true;
    try {
      final page = await widget.library.recent(page: _page, size: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _page++;
        _photos.addAll(page);
        _ended = page.length < widget.pageSize;
      });
    } on Exception {
      // The library couldn't be read (a platform error): what loaded stays, and no more is asked.
      if (mounted) setState(() => _ended = true);
    } finally {
      _loading = false;
    }
  }

  bool _scrolled(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 600) unawaited(_more());
    return false;
  }

  void _toggle(PhotoAsset photo) {
    final at = _picked.indexWhere((p) => p.id == photo.id);
    if (at >= 0) {
      setState(() => _picked.removeAt(at));
    } else if (_picked.length >= widget.max) {
      _refusal?.cancel();
      setState(() => _refused = true);
      _refusal = Timer(PhotoGridPanel.limitLength, () {
        if (mounted) setState(() => _refused = false);
      });
    } else {
      setState(() => _picked.add(photo));
    }
  }

  void _add() {
    final scope = ComposerScope.maybeOf(context);
    final picked = List<PhotoAsset>.of(_picked);
    for (final photo in picked) {
      final cell = _cellKeys[photo.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (cell == null || !cell.attached) continue;
      scope?.flyFrom(
        photo.id,
        cell.localToGlobal(Offset.zero) & cell.size,
        Image(image: photo.thumbnail, fit: BoxFit.cover, excludeFromSemantics: true),
      );
    }
    widget.onAdd(picked);
    scope?.controller.close();
  }

  Future<void> _manage() async {
    await widget.library.manage();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ComposerTheme.of(context);
    final denied = _access == PhotoAccess.denied;
    return Column(
      children: [
        if (_access == PhotoAccess.limited)
          Semantics(
            button: true,
            child: GestureDetector(
              key: const ValueKey('photo_grid.manage'),
              behavior: HitTestBehavior.opaque,
              onTap: _manage,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(widget.manageLabel, style: theme.itemStyle),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (denied)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(widget.deniedMessage ?? '', style: theme.itemStyle, textAlign: TextAlign.center),
                  ),
                )
              else
                NotificationListener<ScrollNotification>(
                  onNotification: _scrolled,
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 72),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.columns,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _photos.length,
                    itemBuilder: (context, index) => _cell(_photos[index], theme),
                  ),
                ),
              if (_refused)
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 72,
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.resolvedSelectionColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            widget.limitMessage,
                            textAlign: TextAlign.center,
                            style: theme.itemStyle.copyWith(color: theme.resolvedOnSelectionColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(start: 12, end: 12, bottom: 12, child: _footer(theme)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(ComposerTheme theme) => Row(
    children: [
      Semantics(
        button: true,
        label: widget.backLabel,
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('photo_grid.back'),
          onTap: () => ComposerScope.maybeOf(context)?.controller.back(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: theme.surfaceColor, shape: BoxShape.circle, boxShadow: theme.shadows),
            child: IconTheme(
              data: IconThemeData(color: theme.resolvedIconColor, size: 22),
              child: widget.backIcon ?? const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ),
      const Spacer(),
      if (_picked.isNotEmpty)
        Semantics(
          button: true,
          child: GestureDetector(
            key: const ValueKey('photo_grid.add'),
            onTap: _add,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: theme.resolvedSelectionColor, borderRadius: BorderRadius.circular(24)),
              child: Text(
                widget.addLabel(_picked.length),
                style: theme.itemStyle.copyWith(color: theme.resolvedOnSelectionColor),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _cell(PhotoAsset photo, ComposerTheme theme) {
    final order = _picked.indexWhere((p) => p.id == photo.id);
    final picked = order >= 0;
    return Semantics(
      button: true,
      selected: picked,
      label: photo.semanticLabel,
      value: picked ? '${order + 1}' : null,
      child: GestureDetector(
        key: ValueKey('photo_grid.photo.${photo.id}'),
        onTap: () => _toggle(photo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(
              key: _cellKeys.putIfAbsent(photo.id, GlobalKey.new),
              child: Image(
                image: photo.thumbnail,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (context, _, _) => ColoredBox(color: theme.barColor),
              ),
            ),
            PositionedDirectional(
              top: 6,
              end: 6,
              child: _OrderBadge(order: picked ? order + 1 : null, theme: theme),
            ),
          ],
        ),
      ),
    );
  }
}

/// A picked photo's number on the selection colour; an empty ring until it is picked.
class _OrderBadge extends StatelessWidget {
  const new({required this.order, required this.theme});

  final int? order;
  final ComposerTheme theme;

  @override
  Widget build(BuildContext context) {
    final order = this.order;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: order == null ? const Color(0x33000000) : theme.resolvedSelectionColor,
            border: Border.all(
              color: order == null ? const Color(0xFFFFFFFF) : theme.resolvedOnSelectionColor,
              width: 1.5,
            ),
          ),
          child: order == null
              ? null
              : Center(
                  child: MediaQuery.withNoTextScaling(
                    child: Text(
                      '$order',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.resolvedOnSelectionColor,
                        height: 1,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
