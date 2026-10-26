// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../constants/db_keys.dart';
import '../../global_providers/global_providers.dart';
import '../extensions/custom_extensions.dart';

/// Page-transition length, which is also the shared-element flight length —
/// Hero takes its duration from the route, so slowing one slows both.
enum PageTransitionSpeed {
  fast(Duration(milliseconds: 200)),
  normal(Duration(milliseconds: 300)),
  slow(Duration(milliseconds: 500)),
  slowest(Duration(milliseconds: 800));

  const PageTransitionSpeed(this.duration);

  final Duration duration;

  String label(BuildContext context) => switch (this) {
    PageTransitionSpeed.fast => context.l10n.pageTransitionFast,
    PageTransitionSpeed.normal => context.l10n.pageTransitionNormal,
    PageTransitionSpeed.slow => context.l10n.pageTransitionSlow,
    PageTransitionSpeed.slowest => context.l10n.pageTransitionSlowest,
  };
}

final pageTransitionSpeedProvider =
    NotifierProvider<PageTransitionSpeedController, PageTransitionSpeed>(
      PageTransitionSpeedController.new,
    );

class PageTransitionSpeedController extends Notifier<PageTransitionSpeed> {
  @override
  PageTransitionSpeed build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored =
        prefs.getInt(DBKeys.pageTransitionSpeed.name) ??
        DBKeys.pageTransitionSpeed.initial as int;
    return PageTransitionSpeed.values[stored.clamp(
      0,
      PageTransitionSpeed.values.length - 1,
    )];
  }

  Future<void> set(PageTransitionSpeed speed) async {
    state = speed;
    await ref
        .read(sharedPreferencesProvider)
        .setInt(DBKeys.pageTransitionSpeed.name, speed.index);
  }
}
