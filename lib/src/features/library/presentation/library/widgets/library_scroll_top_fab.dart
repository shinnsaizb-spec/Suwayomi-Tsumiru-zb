// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../../../../../utils/motion/reduce_motion.dart';
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
  ScrollPosition? _position;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    // Standard scrollables report their ScrollPosition here, which is the only
    // handle on the position available from a notification.
    if (metrics is ScrollPosition) _position = metrics;
    final visible = metrics.pixels > _kShowAfter;
    if (visible != _visible) setState(() => _visible = visible);
    return false;
  }

  void _backToTop() {
    final position = _position;
    if (position == null || !position.hasPixels) return;
    position.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    return NotificationListener<ScrollNotification>(
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
                      child: FloatingActionButton.small(
                        // Our own Hero wraps this one; the FAB's built-in hero
                        // would nest inside it and trip the duplicate-tag
                        // assertion.
                        heroTag: null,
                        onPressed: _backToTop,
                        child: const Icon(Icons.vertical_align_top_rounded),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
