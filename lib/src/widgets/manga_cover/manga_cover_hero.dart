// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

/// Shared-element tag for a manga cover.
///
/// Every cover of the same series shares one tag so the image flies from the
/// list/grid tile into the details header (and back). Two covers of the same
/// series on one screen would break that — Hero asserts on duplicate tags — so
/// call sites that can repeat a series opt out with `enableHero: false`.
String mangaCoverHeroTag(int mangaId) => 'manga-cover-$mangaId';

/// Wraps a cover in a [Hero] for the tile → details transition.
///
/// The flight shuttle deliberately hands over the **source** widget rather than
/// cross-fading: both ends are the same `ServerImage` at different sizes, so a
/// fade would show the artwork twice. Borrowing the source widget also survives
/// the grid recycling the tile mid-flight.
class MangaCoverHero extends StatelessWidget {
  const MangaCoverHero({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  final String tag;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Honour "remove animations" (accessibility) and the app's own reduce-motion
    // setting: a shared-element flight is exactly the kind of motion it asks to
    // avoid.
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return Hero(
      tag: tag,
      // Keep the flight going when the user swipes back mid-transition.
      transitionOnUserGestures: true,
      flightShuttleBuilder: _shuttle,
      child: child,
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final heroContext = flightDirection == HeroFlightDirection.push
        ? fromHeroContext
        : toHeroContext;
    final hero = heroContext.widget as Hero;
    return InheritedTheme.captureAll(
      heroContext,
      Material(type: MaterialType.transparency, child: hero.child),
    );
  }
}
