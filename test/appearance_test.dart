import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedfinder/appearance.dart';

void main() {
  test('every colour except the default has a bundled icon', () {
    for (final a in accents.skip(1)) {
      expect(File('assets/icons/${a.iconName}.png').existsSync(), isTrue, reason: a.name);
    }
    expect(accents.first.iconName, isNull);
  });

  test('Dark Red is offered', () {
    expect(accents.map((a) => a.displayName), contains('Dark Red'));
  });
}
