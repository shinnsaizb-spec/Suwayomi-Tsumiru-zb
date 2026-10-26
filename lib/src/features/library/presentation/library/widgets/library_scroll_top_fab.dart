// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../../../../../utils/motion/reduce_motion.dart';
import '../../../../../utils/theme/brand.dart';
import '../../../../../widgets/read_fab_hero.dart';

/// How far the shelf must scroll before the button appears — roughly one screen
/// of covers, so it never shows on a shelf that already fits.
const double _kShowAfter = 600;

/// "Back to top" button overlaid on the shelf.
///
/// Driven by scroll notifications rather than a controller on purpose: the shelf
/// has four layout variants (categories / grouped × search bar always-on or
/// toggled) and only some of them own a ScrollController. Wrapping the shared
/// body catches all four, and the concrete `ScrollPosition` needed to animate
/// back comes off the notification itself.
///
/// The button carries the same Hero as the series page's start/resume button, so
/// opening a series morphs this round button into that labelled one.
class LibraryScrollTopFab extends StatefulWidget {
  const LibraryScrollTopFab({super.key, required this.child});

  final Widget child;

  @override
  State<LibraryScrollTopFab> createState() => _LibraryScrollTopFabState();
}

class _LibraryScrollTopFabState extends State<LibraryScrollTopFab> {
  bool _visible = false;

  /// The controller the shelf's own lists attach to.
  ///
  /// The category / grouped lists are plain `CustomScrollView`s with no
  /// controller, so they all use the ambient `PrimaryScrollController`. Owning
  /// it here is what makes "back to top" act on the tab that is actually on
  /// screen: the notifications alone could only describe whichever scrollable
  /// happened to report, and on a `TabBarView` that was not always the visible
  /// one — pressing the button scrolled a background tab instead.
  final ScrollController _controller = ScrollController();

  /// Every scroll position the shelf has reported, plus the outer position of
  /// the surrounding `NestedScrollView` when there is one.
  ///
  /// A single position is not enough: the shelf nests an inner list inside a
  /// `NestedScrollView` (and one per category tab), so animating just the one
  /// the notification carried left the collapsing header in place, and on a
  /// second tab it animated a position that belonged to the first.
  final Set<ScrollPosition> _positions = <ScrollPosition>{};

  static ScrollPosition? _ancestorPosition(BuildContext? context) {
    ScrollPosition? found;
    context?.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.position.hasPixels) found = state.position;
        return false;
      }
      return true;
    });
    return found;
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics is ScrollPosition) _positions.add(metrics);
    final outer = _ancestorPosition(notification.context);
    if (outer != null) _positions.add(outer);

    final visible = metrics.pixels > _kShowAfter;
    if (visible != _visible) setState(() => _visible = visible);
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _backToTop() {
    // Prefer the controller's own positions: those are the lists that are
    // mounted right now, which is what the user is looking at.
    //
    // The ones collected from notifications must not be driven alongside them.
    // A `TabBarView` keeps positions around after their tab is disposed, and
    // `animateTo` on one of those throws (a disposed position has no context to
    // create its ticker from) — the throw aborted this loop before the visible
    // list was reached, which is why the button appeared to do nothing while a
    // background tab jumped. They stay only as the fallback for the nested
    // layout, where the lists attach to their own controller instead.
    final own = _controller.positions.toList();
    final targets = own.isNotEmpty ? own : _positions.toList();
    for (final position in targets) {
      if (!position.hasPixels || position.pixels <= 0) continue;
      try {
        position.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // A position whose scrollable is gone; nothing to scroll.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    return PrimaryScrollController(
      controller: _controller,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.child,
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedScale(
                scale: _visible ? 1 : 0,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: _visible
                    ? ReadFabHero(
                        child: _BrandSquareButton(
                          onPressed: _backToTop,
                          icon: const Icon(Icons.vertical_align_top_rounded),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square version of [BrandFab]: same gradient, same glow, same corner radius
/// and same height as the series page's read button, so the two read as one
/// control morphing rather than two different buttons swapping places.
class _BrandSquareButton extends StatelessWidget {
  const _BrandSquareButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final Widget icon;

  /// BrandFab's height: 14dp of padding above and below a 20dp row.
  static const double _size = 48;
  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: brand.gradient,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: brandGlow(Theme.of(context).colorScheme),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: onPressed,
          child: SizedBox(
            width: _size,
            height: _size,
            child: IconTheme.merge(
              data: IconThemeData(color: brand.onGradient, size: 20),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
