// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../global_providers/global_providers.dart';

/// Upper bound of the tap mute, in milliseconds — the slider's right end.
const int kReaderTapMuteMaxMs = 2000;

/// How long a tap is ignored after the reader scrolls, in the vertical modes.
///
/// User-tunable because the right value depends on how the person reads: a
/// quick flick leaves the list coasting for a while, and a fixed window either
/// swallows deliberate taps or lets the misfires through.
final readerTapMuteAfterScrollProvider =
    NotifierProvider<ReaderTapMuteAfterScrollController, Duration>(
      ReaderTapMuteAfterScrollController.new,
    );

class ReaderTapMuteAfterScrollController extends Notifier<Duration> {
  @override
  Duration build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored =
        prefs.getInt(DBKeys.readerTapMuteAfterScrollMs.name) ??
        DBKeys.readerTapMuteAfterScrollMs.initial as int;
    return Duration(milliseconds: stored.clamp(0, kReaderTapMuteMaxMs));
  }

  Future<void> setMilliseconds(int milliseconds) async {
    final clamped = milliseconds.clamp(0, kReaderTapMuteMaxMs);
    state = Duration(milliseconds: clamped);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(DBKeys.readerTapMuteAfterScrollMs.name, clamped);
  }
}
