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
    final content = InheritedTheme.captureAll(
      heroContext,
      Material(type: MaterialType.transparency, child: hero.child),
    );

    // Coming back to the shelf, the tile can be half scrolled out of view. The
    // flight is drawn in the navigator's overlay, above the list and outside its
    // clip, so the artwork would hang past the cell and then vanish as the list
    // clipped it. Clipping the shuttle to the list's viewport makes it disappear
    // exactly where the cell does. Push is left alone: there the cover is
    // supposed to leave the list.
    if (flightDirection != HeroFlightDirection.pop) return content;
    final viewport = _viewportOf(heroContext);
    if (viewport == null) return content;
    return _ViewportClipped(viewport: viewport, child: content);
  }

  /// The render box of the scrollable that contains [context], if any.
  static RenderBox? _viewportOf(BuildContext context) {
    final state = Scrollable.maybeOf(context);
    final box = state?.context.findRenderObject();
    return box is RenderBox && box.attached ? box : null;
  }
}

/// Clips its child to [viewport]'s on-screen rect, recomputed every frame.
class _ViewportClipped extends StatefulWidget {
  const _ViewportClipped({required this.viewport, required this.child});

  final RenderBox viewport;
  final Widget child;

  @override
  State<_ViewportClipped> createState() => _ViewportClippedState();
}

class _ViewportClippedState extends State<_ViewportClipped> {
  final GlobalKey _shuttleKey = GlobalKey();

  @override
  Widget build(BuildContext context) => ClipRect(
    clipper: _ViewportClipper(
      viewport: widget.viewport,
      shuttleKey: _shuttleKey,
    ),
    child: KeyedSubtree(key: _shuttleKey, child: widget.child),
  );
}

class _ViewportClipper extends CustomClipper<Rect> {
  _ViewportClipper({required this.viewport, required this.shuttleKey});

  final RenderBox viewport;
  final GlobalKey shuttleKey;

  @override
  Rect getClip(Size size) {
    final full = Offset.zero & size;
    final shuttle = shuttleKey.currentContext?.findRenderObject();
    if (shuttle is! RenderBox || !shuttle.attached || !viewport.attached) {
      return full;
    }
    final view = viewport.localToGlobal(Offset.zero) & viewport.size;
    final origin = shuttle.localToGlobal(Offset.zero);
    final local = view.shift(-origin).intersect(full);
    // A disjoint rect would clip everything away; fall back to no clipping.
    if (local.isEmpty || local.width <= 0 || local.height <= 0) return full;
    return local;
  }

  @override
  bool shouldReclip(_ViewportClipper oldClipper) => true;
}
