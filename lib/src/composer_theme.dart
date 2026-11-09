import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// How the composer looks: the bar, the surface it grows into, and the corner it morphs from. Put
/// one in `ThemeData.extensions` or pass it to `MorphingComposer.theme`; without either,
/// [ComposerTheme.fallback] reads the colour scheme.
@immutable
class ComposerTheme extends ThemeExtension<ComposerTheme> {
  const new({
    required this.barColor,
    required this.surfaceColor,
    required this.itemStyle,
    this.barRadius = 26,
    this.surfaceRadius = 28,
    this.textStyle,
    this.hintStyle,
    this.iconColor,
    this.selectionColor,
    this.onSelectionColor,
    this.shadows = const [],
  });

  /// The neutral look from [scheme].
  factory fallback(ColorScheme scheme) => ComposerTheme(
    barColor: scheme.surfaceContainerHigh,
    surfaceColor: scheme.surfaceContainerHighest,
    itemStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: scheme.onSurface),
  );

  /// The theme in effect at [context]: the one a `MorphingComposer` above passes down, else the
  /// extension, else [ComposerTheme.fallback].
  factory of(BuildContext context) {
    final scoped = context.dependOnInheritedWidgetOfExactType<ComposerThemeScope>()?.theme;
    if (scoped != null) return scoped;
    final theme = Theme.of(context);
    return theme.extension<ComposerTheme>() ?? ComposerTheme.fallback(theme.colorScheme);
  }

  /// The bar's fill (trigger, field, trailing slot).
  final Color barColor;

  /// The fill of the surface the bar grows into (the item list, then a panel).
  final Color surfaceColor;

  /// A menu item's label.
  final TextStyle itemStyle;

  final double barRadius;
  final double surfaceRadius;

  /// The field's text; else [itemStyle] at the regular weight.
  final TextStyle? textStyle;

  /// The field's placeholder; else [textStyle] at 60 % opacity.
  final TextStyle? hintStyle;

  /// The trigger's and the items' icons; else [itemStyle]'s colour.
  final Color? iconColor;

  /// A picked photo's order badge and the "Add N" button; else [iconColor].
  final Color? selectionColor;

  /// The ink on [selectionColor]; else [surfaceColor].
  final Color? onSelectionColor;

  /// The surface's shadow while it floats over the screen.
  final List<BoxShadow> shadows;

  TextStyle get resolvedTextStyle => textStyle ?? itemStyle.copyWith(fontWeight: FontWeight.w400);
  TextStyle get resolvedHintStyle =>
      hintStyle ??
      resolvedTextStyle.copyWith(color: (resolvedTextStyle.color ?? const Color(0xFF000000)).withValues(alpha: 0.6));
  Color get resolvedIconColor => iconColor ?? itemStyle.color ?? const Color(0xFF000000);
  Color get resolvedSelectionColor => selectionColor ?? resolvedIconColor;
  Color get resolvedOnSelectionColor => onSelectionColor ?? surfaceColor;

  @override
  ComposerTheme copyWith({
    Color? barColor,
    Color? surfaceColor,
    TextStyle? itemStyle,
    double? barRadius,
    double? surfaceRadius,
    TextStyle? textStyle,
    TextStyle? hintStyle,
    Color? iconColor,
    Color? selectionColor,
    Color? onSelectionColor,
    List<BoxShadow>? shadows,
  }) => ComposerTheme(
    barColor: barColor ?? this.barColor,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    itemStyle: itemStyle ?? this.itemStyle,
    barRadius: barRadius ?? this.barRadius,
    surfaceRadius: surfaceRadius ?? this.surfaceRadius,
    textStyle: textStyle ?? this.textStyle,
    hintStyle: hintStyle ?? this.hintStyle,
    iconColor: iconColor ?? this.iconColor,
    selectionColor: selectionColor ?? this.selectionColor,
    onSelectionColor: onSelectionColor ?? this.onSelectionColor,
    shadows: shadows ?? this.shadows,
  );

  @override
  ComposerTheme lerp(covariant ComposerTheme? other, double t) {
    if (other == null) return this;
    return ComposerTheme(
      barColor: Color.lerp(barColor, other.barColor, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      itemStyle: TextStyle.lerp(itemStyle, other.itemStyle, t)!,
      barRadius: lerpDouble(barRadius, other.barRadius, t)!,
      surfaceRadius: lerpDouble(surfaceRadius, other.surfaceRadius, t)!,
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      hintStyle: TextStyle.lerp(hintStyle, other.hintStyle, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      selectionColor: Color.lerp(selectionColor, other.selectionColor, t),
      onSelectionColor: Color.lerp(onSelectionColor, other.onSelectionColor, t),
      shadows: BoxShadow.lerpList(shadows, other.shadows, t) ?? const [],
    );
  }
}

/// Passes a [ComposerTheme] down to the composer's bar, menu and panels (`MorphingComposer.theme`).
class ComposerThemeScope extends InheritedWidget {
  const new({required this.theme, required super.child, super.key});

  final ComposerTheme theme;

  @override
  bool updateShouldNotify(ComposerThemeScope oldWidget) => theme != oldWidget.theme;
}
