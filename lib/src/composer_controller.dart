import 'package:flutter/widgets.dart';

/// Which level of a `MorphingComposer` is open: none (just the bar), the item list
/// ([ComposerController.menu]) or an item's panel (its id). Hand one to the composer to drive it
/// from outside (a controlled open state); listen to it, or pass `onOpenChanged`, to hear changes.
class ComposerController extends ChangeNotifier {
  /// Starts at [open]: `null` (closed), [menu], or a panel's id.
  new({String? open}) : _level = open;

  /// The level of the item list.
  static const menu = 'menu';

  String? _level;

  /// The open level: `null`, [menu] or a panel's id.
  String? get level => _level;
  set level(String? value) {
    if (value == _level) return;
    _level = value;
    notifyListeners();
  }

  bool get isOpen => _level != null;

  /// Opens the item list.
  void openMenu() => level = menu;

  /// Opens the panel registered under [id] (or the item list, for [menu]).
  // The plan names it open(id), beside back() and close().
  // ignore: use_setters_to_change_properties
  void open(String id) => level = id;

  /// Steps back one level: a panel to the item list, the item list to the bar.
  void back() => level = _level == null || _level == menu ? null : menu;

  /// Closes everything, back to the bar.
  void close() => level = null;
}
