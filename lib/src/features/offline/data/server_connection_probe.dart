// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../constants/db_keys.dart';
import '../../../utils/crash/diagnostics.dart';
import '../../../utils/crash/redact_tokens.dart';
import '../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../library/data/category_repository.dart';

/// Where the server stands right now, as the library's connection indicator
/// reports it.
enum ServerConnectionStatus {
  /// Nothing probed yet (first frame).
  unknown,

  /// A probe is in flight.
  connecting,

  /// The last probe succeeded.
  reachable,

  /// The last probe failed — no network, wrong address, or server down.
  unreachable,
}

/// How often the connection probe retries while the server is unreachable, in
/// seconds. 0 — the default — means it does not retry on its own; the user taps
/// the connection icon instead. Set from the offline settings screen.
///
/// Hand-written rather than generated so enabling it needs no code generation
/// run.
class ServerProbeRetrySeconds extends Notifier<int?>
    with SharedPreferenceClientMixin<int> {
  @override
  int? build() => initialize(DBKeys.serverProbeRetrySeconds);
}

final serverProbeRetrySecondsProvider =
    NotifierProvider<ServerProbeRetrySeconds, int?>(
  ServerProbeRetrySeconds.new,
);

/// A self-contained server probe, so the connection indicator does not depend
/// on whichever data read happens to be running.
///
/// The library is local-first when the full offline cache is on: it serves the
/// on-device catalog and checks the server behind it. That makes the data
/// providers the wrong place to learn "connected or not" — an early return
/// never touches the network, so nothing ever flipped the flag and the
/// indicator sat on "connected" forever. This runs its own (cheapest possible)
/// request and retries on a timer while the server is unreachable, which is
/// also what keeps a returning server noticed without the user pulling.
///
/// Hand-written rather than generated so enabling it needs no code generation
/// run.
class ServerConnectionProbe extends Notifier<ServerConnectionStatus> {
  Timer? _retryTimer;

  @override
  ServerConnectionStatus build() {
    ref.onDispose(() => _retryTimer?.cancel());
    return ServerConnectionStatus.unknown;
  }

  /// Probes the server, unless a probe is already in flight, and reports what it
  /// found so a caller can act on it (the library's retry button refreshes the
  /// shelf only once the server has actually answered).
  Future<ServerConnectionStatus> probe({bool retryOnFailure = true}) async {
    if (state == ServerConnectionStatus.connecting) return state;
    state = ServerConnectionStatus.connecting;
    try {
      final categories = await ref.read(categoryRepositoryProvider).getCategoryList();
      state = categories == null
          ? ServerConnectionStatus.unreachable
          : ServerConnectionStatus.reachable;
    } catch (_) {
      state = ServerConnectionStatus.unreachable;
    }
    if (state == ServerConnectionStatus.unreachable) {
      recordDiagnostic(
        redactTokens(
          '[${DateTime.now().toIso8601String()}] connection-probe: '
          'unreachable\n',
        ),
      );
      if (retryOnFailure) _scheduleRetry();
    } else {
      _retryTimer?.cancel();
    }
    return state;
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final seconds = ref.read(serverProbeRetrySecondsProvider);
    // No interval set: leave it to the user tapping the icon.
    if (seconds == null || seconds <= 0) return;
    _retryTimer = Timer(
      Duration(seconds: seconds.clamp(1, 24 * 60 * 60)),
      () => probe(),
    );
  }
}

final serverConnectionProbeProvider =
    NotifierProvider<ServerConnectionProbe, ServerConnectionStatus>(
  ServerConnectionProbe.new,
);
