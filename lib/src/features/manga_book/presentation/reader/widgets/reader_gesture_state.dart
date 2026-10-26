// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

// Small, dependency-free providers that bridge gesture state between reader
// widget-tree branches that don't otherwise share a parent close enough to
// thread a constructor parameter through cleanly. Both are read (never
// watched — these are gesture-time queries, not something that should
// trigger a rebuild) via `ref.read(...)` inside gesture callbacks/recognizer
// factories, and written the same way from wherever the state actually lives.

import 'package:hooks_riverpod/legacy.dart';

/// Whether the touch that is currently down landed while the strip was still
/// coasting from the reader's own fling. Such a tap arrests the scroll and
/// nothing else — the next one opens the chrome. The long strip snapshots this
/// on pointer-down, mirroring Komikku's `tapDuringManualScroll`
/// (`WebtoonRecyclerView.kt:72-75`, consumed at `:244-248`).
final readerTapArrestsFlingProvider = StateProvider<bool>((ref) => false);

/// Whether ZoomView is currently zoomed in past 1x, written by the
/// continuous reader modes' zoom wrapper. Read by
/// [DirectionalSwipeGestureHandler] so its chapter-swipe/last-page-swipe
/// recognizers can yield the single-finger gesture arena to ZoomView's own
/// pan while zoomed, the same way they already yield outright in vertical
/// mode — see the recognizers' `isZoomedIn` callback in
/// `single_touch_drag_recognizers.dart`.
final readerIsZoomedInProvider = StateProvider<bool>((ref) => false);

/// How long a tap stays ignored after the reader last scrolled.
///
/// A webtoon fling keeps the list moving after the finger lifts, and the next
/// touch frequently lands while it is still coasting — a short drag of a few
/// pixels then reads as a tap and toggles the chrome. A movement threshold
/// alone does not catch it (the fling is already underway), so the tap handler
/// also refuses for this window after any scroll motion.
const kReaderTapAfterScrollWindow = Duration(seconds: 2);

/// Wall-clock time of the last scroll motion in the reader. Written by the
/// scroll notification listener and by the tap gate when it sees a drag.
final readerLastScrollAtProvider = StateProvider<DateTime?>((ref) => null);
