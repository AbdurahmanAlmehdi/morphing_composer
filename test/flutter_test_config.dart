import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/harness.dart';

/// Platform goldens: compared on macOS only, skipped on CI.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  return await AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: goldensEnabled),
      ciGoldensConfig: const CiGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
