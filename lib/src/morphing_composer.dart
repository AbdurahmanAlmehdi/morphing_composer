import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:morphing_composer/src/composer_controller.dart';
import 'package:morphing_composer/src/composer_item.dart';
import 'package:morphing_composer/src/composer_theme.dart';

/// What a panel inside a `MorphingComposer` can reach: its [controller] (to step back or close)
/// and [flyFrom], which morphs a picked photo from its grid cell into its attachment thumb.
class ComposerScope extends InheritedWidget {
  const new({required this.controller, required this.flyFrom, required super.child, super.key});

  final ComposerController controller;

  /// Morphs a picture from a global rect into the thumb of the attachment with that id, once the
  /// caller has added it (in the same frame). Nothing flies with reduced motion.
  final void Function(Object id, Rect globalRect, Widget picture) flyFrom;

  static ComposerScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ComposerScope>();

  @override
  bool updateShouldNotify(ComposerScope oldWidget) => controller != oldWidget.controller;
}

/// A chat composer like ChatGPT's: the bar (a trigger at the start, the field, a
/// [trailing] slot for voice and send) sits under [child], and one surface grows out of the
/// trigger into the [items] list, then into an item's panel. One spring drives the surface's size,
/// corner and position; there is no separate sheet. The field keeps focus throughout, so the
/// keyboard stays up and the surface rides above it.
///
/// Back, an edge swipe from the start edge and a tap outside each step back one level (a panel to
/// the list, the list to the bar). With reduced motion the surface cross-fades instead of morphing.
/// Put it where the screen's body ends (it fills the space it gets; [child] takes what the bar
/// leaves). Every word comes from the caller.
class MorphingComposer extends StatefulWidget {
  const new({
    required this.child,
    required this.textController,
    required this.hintText,
    required this.triggerLabel,
    required this.backLabel,
    required this.items,
    super.key,
    this.controller,
    this.onOpenChanged,
    this.focusNode,
    this.trailing,
    this.attachments = const [],
    this.enabled = true,
    this.theme,
    this.triggerIcon,
    this.removeIcon,
    this.menuWidth = 220,
    this.padding = const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
  });

  /// What sits above the bar (the conversation).
  final Widget child;
  final TextEditingController textController;
  final String hintText;

  /// The trigger's name for screen readers ("Add").
  final String triggerLabel;

  /// The name of the area outside an open menu, which steps back one level, for screen readers.
  final String backLabel;
  final List<ComposerItem> items;

  /// Drives the open level from outside; else the composer keeps its own.
  final ComposerController? controller;

  /// Called with the new level (`null`, [ComposerController.menu] or a panel's id).
  final ValueChanged<String?>? onOpenChanged;
  final FocusNode? focusNode;

  /// Voice and send, at the bar's end.
  final Widget? trailing;

  /// Files waiting above the field; the bar grows to hold them.
  final List<ComposerAttachment> attachments;

  /// Off: the field and the trigger take no input (offline, out of quota).
  final bool enabled;

  /// The look; else the theme's [ComposerTheme] extension, else [ComposerTheme.fallback].
  final ComposerTheme? theme;

  /// The trigger's icon; a plus by default.
  final Widget? triggerIcon;

  /// The icon on an attachment's remove button; a cross by default.
  final Widget? removeIcon;

  /// The item list's width at text scale 1; it grows with the text.
  final double menuWidth;

  /// Around the bar.
  final EdgeInsetsDirectional padding;

  /// The surface's key, for finding it in tests.
  static const ValueKey<String> surfaceKey = ValueKey('morphing_composer.surface');

  /// The trigger's key, for finding it in tests.
  static const ValueKey<String> triggerKey = ValueKey('morphing_composer.trigger');

  /// How long the cross-fade takes with reduced motion.
  static const fadeLength = Duration(milliseconds: 200);

  /// The corner of an attachment's thumb, which an attachment's own overlay matches.
  static const thumbRadius = 12.0;

  @override
  State<MorphingComposer> createState() => _MorphingComposerState();
}

/// Where the surface sits in the composer and how round it is.
@immutable
class _Shape {
  const new(this.rect, this.radius);

  factory lerp(_Shape a, _Shape b, double t) =>
      _Shape(Rect.lerp(a.rect, b.rect, t)!, math.max(0, lerpDouble(a.radius, b.radius, t)!));

  final Rect rect;
  final double radius;
}

/// A picked photo on its way from its grid cell (global) to its thumb.
@immutable
class _Flight {
  const new(this.from, this.picture);

  final Rect from;
  final Widget picture;
}

class _MorphingComposerState extends State<MorphingComposer> with TickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.86);

  /// The space between the bar and the list, and above an open panel.
  static const _gap = 8.0;

  /// Inside the bar, around the trigger, the field and the trailing slot.
  static const _barInset = 4.0;
  static const _trigger = 48.0;

  /// The field's least height: a tap target's.
  static const _minFieldHeight = 48.0;
  static const _thumb = 60.0;

  ComposerController? _own;
  late final AnimationController _morph = AnimationController.unbounded(vsync: this, value: 1)
    ..addStatusListener(_settled);
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  final GlobalKey _stackKey = GlobalKey();

  /// The level the surface shows (or is heading to), and the last open one, whose content stays
  /// while the surface closes.
  String? _shown;
  String? _content;

  /// Where the surface was when the current move started.
  _Shape? _from;
  double _fromOpacity = 0;
  Size _stack = Size.zero;
  double _barHeight = _trigger + 2 * _barInset;
  bool _reduced = false;
  final _flights = <Object, _Flight>{};
  final _thumbKeys = <Object, GlobalKey>{};
  bool _flightQueued = false;

  ComposerController get _controller => widget.controller ?? (_own ??= ComposerController());

  @override
  void initState() {
    super.initState();
    _shown = _controller.level;
    _content = _shown;
    _fromOpacity = _shown == null ? 0 : 1;
    _controller.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(MorphingComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
      _changed();
    }
    if (!widget.enabled && _controller.isOpen) _controller.close();
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    _morph.dispose();
    _flight.dispose();
    super.dispose();
  }

  void _changed() {
    final next = _controller.level;
    if (next == _shown) return;
    final shape = _shapeNow();
    final opacity = _opacityNow();
    setState(() {
      _from = shape;
      _fromOpacity = opacity;
      _shown = next;
      if (next != null) _content = next;
    });
    if (_reduced) {
      _morph
        ..value = 0
        ..animateTo(1, duration: MorphingComposer.fadeLength);
    } else {
      _morph
        ..value = 0
        ..animateWith(SpringSimulation(_spring, 0, 1, 0));
    }
    widget.onOpenChanged?.call(next);
  }

  void _settled(AnimationStatus status) {
    if (!status.isCompleted || !mounted) return;
    // A spring stops within its tolerance; land exactly on the level.
    if (_morph.value != 1) _morph.value = 1;
    setState(() {});
  }

  bool get _surfaceVisible => _shown != null || _morph.isAnimating;

  // Geometry, from the composer's size (current at layout time) and the bar's last height.

  EdgeInsets get _padding => widget.padding.resolve(Directionality.of(context));

  Rect get _bar {
    final p = _padding;
    return Rect.fromLTRB(
      p.left,
      _stack.height - p.bottom - _barHeight,
      _stack.width - p.right,
      _stack.height - p.bottom,
    );
  }

  Rect get _triggerRect {
    final bar = _bar;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = rtl ? bar.right - _barInset - _trigger : bar.left + _barInset;
    return Rect.fromLTWH(left, bar.bottom - _barInset - _trigger, _trigger, _trigger);
  }

  ComposerItem? _panelItem(String? level) {
    for (final item in widget.items) {
      if (item.id == level && item.panel != null) return item;
    }
    return null;
  }

  double get _itemExtent {
    final style = _theme.itemStyle;
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16) * (style.height ?? 1.3);
    return math.max(_trigger, line + 24);
  }

  Size get _menuSize {
    final width = math.min(_bar.width, MediaQuery.textScalerOf(context).scale(widget.menuWidth));
    return Size(width, widget.items.length * _itemExtent + 2 * _gap);
  }

  Rect _rectFor(String? level) {
    if (level == null) return _triggerRect;
    final bar = _bar;
    if (_panelItem(level) != null) return Rect.fromLTRB(bar.left, _gap, bar.right, bar.bottom);
    final size = _menuSize;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = rtl ? bar.right - size.width : bar.left;
    return Rect.fromLTWH(left, bar.top - _gap - size.height, size.width, size.height);
  }

  _Shape _shapeFor(String? level) => _Shape(_rectFor(level), level == null ? _trigger / 2 : _theme.surfaceRadius);

  _Shape _shapeNow() {
    final target = _shapeFor(_shown);
    final from = _from;
    if (from == null) return target;
    if (_reduced) return _shown == null ? from : target;
    return _Shape.lerp(from, target, _morph.value);
  }

  double _opacityNow() {
    final to = _shown == null ? 0.0 : 1.0;
    final t = _morph.value;
    final progress = _reduced || to <= _fromOpacity ? t : t * 2.5;
    return lerpDouble(_fromOpacity, to, progress.clamp(0.0, 1.0))!;
  }

  ComposerTheme get _theme => widget.theme ?? ComposerTheme.of(context);

  // Actions.

  void _toggle() => _controller.isOpen ? _controller.close() : _controller.openMenu();

  void _select(ComposerItem item) {
    if (item.panel != null) {
      _controller.open(item.id);
    } else {
      item.onTap?.call();
      _controller.close();
    }
  }

  double _swipe = 0;

  void _swiped(DragUpdateDetails details) {
    final inward = Directionality.of(context) == TextDirection.rtl ? -details.delta.dx : details.delta.dx;
    _swipe += inward;
  }

  void _swipeEnded(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx * (Directionality.of(context) == TextDirection.rtl ? -1 : 1);
    if (_swipe > 40 || velocity > 300) _controller.back();
    _swipe = 0;
  }

  void _flyFrom(Object id, Rect from, Widget picture) {
    if (_reduced) return;
    _flights[id] = _Flight(from, picture);
    if (_flightQueued) return;
    _flightQueued = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _flightQueued = false;
        if (!mounted) return;
        // A photo the caller didn't add (yet) doesn't fly.
        setState(() => _flights.removeWhere((key, _) => _thumbKeys[key]?.currentContext == null));
        if (_flights.isEmpty) return;
        _flight.forward(from: 0).whenCompleteOrCancel(() {
          if (mounted) setState(_flights.clear);
        });
      })
      ..ensureVisualUpdate();
  }

  void _barSized(Size size) {
    if (size.height != _barHeight) setState(() => _barHeight = size.height);
  }

  // Building.

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return ComposerThemeScope(
      theme: theme,
      child: ComposerScope(
        controller: _controller,
        flyFrom: _flyFrom,
        child: PopScope(
          canPop: _shown == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.back();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _stack = constraints.biggest;
              final open = _shown != null;
              return Stack(
                key: _stackKey,
                children: [
                  Column(
                    children: [
                      Expanded(child: widget.child),
                      Padding(
                        padding: widget.padding,
                        child: _SizeReporter(onSize: _barSized, child: _buildBar(theme)),
                      ),
                    ],
                  ),
                  if (open)
                    Positioned.fill(
                      child: ModalBarrier(onDismiss: _controller.back, semanticsLabel: widget.backLabel),
                    ),
                  if (_surfaceVisible)
                    AnimatedBuilder(animation: _morph, builder: (context, _) => _buildSurface(theme)),
                  if (open)
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: 16,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: _swiped,
                        onHorizontalDragEnd: _swipeEnded,
                        onTap: _controller.back,
                      ),
                    ),
                  for (final MapEntry(key: id, value: flight) in _flights.entries)
                    if (_flight.isAnimating)
                      AnimatedBuilder(animation: _flight, builder: (context, _) => _buildFlight(id, flight)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBar(ComposerTheme theme) {
    final open = _shown != null;
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.barColor, borderRadius: BorderRadius.circular(theme.barRadius)),
        child: Padding(
          padding: const EdgeInsets.all(_barInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: _reduced ? Duration.zero : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: AlignmentDirectional.bottomStart,
                child: widget.attachments.isEmpty ? const SizedBox(width: double.infinity) : _buildStrip(theme),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Semantics(
                    button: true,
                    label: widget.triggerLabel,
                    expanded: open,
                    enabled: widget.enabled,
                    excludeSemantics: true,
                    onTap: widget.enabled ? _toggle : null,
                    child: GestureDetector(
                      key: MorphingComposer.triggerKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.enabled ? _toggle : null,
                      child: SizedBox.square(
                        dimension: _trigger,
                        child: Center(
                          child: IconTheme(
                            data: IconThemeData(
                              color: theme.resolvedIconColor.withValues(alpha: widget.enabled ? 1 : 0.38),
                              size: 24,
                            ),
                            child: widget.triggerIcon ?? const Icon(Icons.add),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: _barInset),
                  Expanded(
                    // The field's own box holds its vertical padding, so its tap target is at least
                    // 48 high (the platform guidelines measure the field, not the bar around it).
                    child: TextField(
                      controller: widget.textController,
                      focusNode: widget.focusNode,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      textAlignVertical: TextAlignVertical.center,
                      style: theme.resolvedTextStyle,
                      cursorColor: theme.resolvedIconColor,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        constraints: const BoxConstraints(minHeight: _minFieldHeight),
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintMaxLines: 1,
                        hintStyle: theme.resolvedHintStyle,
                      ),
                    ),
                  ),
                  ?widget.trailing,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrip(ComposerTheme theme) {
    final ids = {for (final attachment in widget.attachments) attachment.id};
    _thumbKeys.removeWhere((id, _) => !ids.contains(id));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(_barInset),
      child: Row(
        children: [
          for (final attachment in widget.attachments)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _Thumb(
                key: ValueKey(attachment.id),
                pictureKey: _thumbKeys.putIfAbsent(attachment.id, GlobalKey.new),
                attachment: attachment,
                hidden: _flights.containsKey(attachment.id),
                theme: theme,
                removeIcon: widget.removeIcon,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSurface(ComposerTheme theme) {
    final shape = _shapeNow();
    final rect = Rect.fromLTWH(
      shape.rect.left,
      shape.rect.top,
      math.max(0, shape.rect.width),
      math.max(0, shape.rect.height),
    );
    final radius = BorderRadius.circular(math.min(shape.radius, rect.shortestSide / 2));
    final content = _content;
    final panel = _panelItem(content);
    final size = _rectFor(content).size;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        ignoring: _shown == null,
        child: Opacity(
          opacity: _opacityNow(),
          child: DecoratedBox(
            key: MorphingComposer.surfaceKey,
            decoration: BoxDecoration(color: theme.surfaceColor, borderRadius: radius, boxShadow: theme.shadows),
            child: ClipRRect(
              borderRadius: radius,
              child: AnimatedSwitcher(
                duration: MorphingComposer.fadeLength,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.bottomStart, children: [...previous, ?current]),
                child: OverflowBox(
                  key: ValueKey(panel == null ? ComposerController.menu : content),
                  alignment: AlignmentDirectional.bottomStart,
                  minWidth: size.width,
                  maxWidth: size.width,
                  minHeight: size.height,
                  maxHeight: size.height,
                  child: panel == null ? _buildMenu(theme) : Builder(builder: panel.panel!),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(ComposerTheme theme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: _gap),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in widget.items)
          Semantics(
            button: true,
            child: GestureDetector(
              key: ValueKey('morphing_composer.item.${item.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _select(item),
              child: SizedBox(
                height: _itemExtent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconTheme(
                        data: IconThemeData(color: theme.resolvedIconColor, size: 22),
                        child: ExcludeSemantics(child: item.icon),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.label, style: theme.itemStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildFlight(Object id, _Flight flight) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final thumb = _thumbKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || thumb == null || !thumb.hasSize) return const SizedBox.shrink();
    final to = thumb.localToGlobal(Offset.zero, ancestor: stack) & thumb.size;
    final from = stack.globalToLocal(flight.from.topLeft) & flight.from.size;
    final t = Curves.easeInOutCubic.transform(_flight.value);
    return Positioned.fromRect(
      rect: Rect.lerp(from, to, t)!,
      child: IgnorePointer(
        child: ClipRRect(borderRadius: BorderRadius.circular(MorphingComposer.thumbRadius * t), child: flight.picture),
      ),
    );
  }
}

/// An attachment's square picture, with its remove button at the top end.
class _Thumb extends StatelessWidget {
  const new({
    required this.pictureKey,
    required this.attachment,
    required this.hidden,
    required this.theme,
    super.key,
    this.removeIcon,
  });

  final GlobalKey pictureKey;
  final ComposerAttachment attachment;

  /// While its photo flies in from the grid.
  final bool hidden;
  final ComposerTheme theme;
  final Widget? removeIcon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _MorphingComposerState._thumb,
    child: Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: hidden ? 0 : 1,
            child: Semantics(
              image: true,
              label: attachment.semanticLabel,
              child: ClipRRect(
                key: pictureKey,
                borderRadius: BorderRadius.circular(MorphingComposer.thumbRadius),
                child: attachment.thumb,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 0,
          end: 0,
          child: Semantics(
            button: true,
            label: attachment.removeLabel,
            excludeSemantics: true,
            onTap: attachment.onRemove,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: attachment.onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: theme.resolvedIconColor,
                    shape: BoxShape.circle,
                    // A ring in the bar's colour keeps it apart from a light photo.
                    border: Border.all(color: theme.barColor, width: 1.5),
                  ),
                  child: IconTheme(
                    data: IconThemeData(size: 14, color: theme.barColor),
                    child: removeIcon ?? const Icon(Icons.close),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Reports its child's size after each layout that changes it.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const new({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  new(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    final reported = _last = size;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(reported);
    });
  }
}
