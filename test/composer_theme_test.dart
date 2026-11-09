import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphing_composer/morphing_composer.dart';

void main() {
  testWidgets('the theme comes from the extension, else the colour scheme', (tester) async {
    const brand = ComposerTheme(barColor: Colors.amber, surfaceColor: Colors.teal, itemStyle: TextStyle());
    late ComposerTheme found;
    late ComposerTheme fallback;
    final plain = ThemeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [brand]),
        home: Builder(
          builder: (context) {
            found = ComposerTheme.of(context);
            return Theme(
              data: plain,
              child: Builder(
                builder: (context) {
                  fallback = ComposerTheme.of(context);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(found, same(brand));
    expect(fallback.surfaceColor, plain.colorScheme.surfaceContainerHighest);
  });

  test('copyWith and lerp', () {
    const a = ComposerTheme(barColor: Colors.black, surfaceColor: Colors.black, itemStyle: TextStyle());
    final b = a.copyWith(barRadius: 10, surfaceRadius: 10, barColor: Colors.white);
    expect(b.barColor, Colors.white);
    expect(a.lerp(b, 0.5).barRadius, 18);
    expect(a.lerp(null, 0.5), same(a));
  });
}
