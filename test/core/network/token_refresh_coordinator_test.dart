import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

void main() {
  test('serializes concurrent refresh calls onto the same future', () async {
    var refreshCalls = 0;
    final completer = Completer<String?>();
    final coordinator = TokenRefreshCoordinator(
      refreshToken: () {
        refreshCalls += 1;
        return completer.future;
      },
    );

    final futures = [
      coordinator.refreshToken(),
      coordinator.refreshToken(),
      coordinator.refreshToken(),
    ];

    expect(refreshCalls, 1);

    completer.complete('token-1');

    expect(await Future.wait(futures), ['token-1', 'token-1', 'token-1']);
  });

  test('allows a new refresh after the previous one completes', () async {
    var refreshCalls = 0;
    final coordinator = TokenRefreshCoordinator(
      refreshToken: () async {
        refreshCalls += 1;
        return 'token-$refreshCalls';
      },
    );

    expect(await coordinator.refreshToken(), 'token-1');
    expect(await coordinator.refreshToken(), 'token-2');
    expect(refreshCalls, 2);
  });
}
