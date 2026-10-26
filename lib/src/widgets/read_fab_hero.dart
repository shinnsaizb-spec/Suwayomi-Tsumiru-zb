// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

/// Shared-element tag for the read button.
///
/// The library's "back to top" button and the series page's "start / resume"
/// button share it, so the round button on the shelf morphs into the labelled
/// one on the series page instead of the two just appearing.
const String kReadFabHeroTag = 'read-fab';

/// Wraps the read button so it can morph across the shelf → series transition.
///
/// Unlike the cover, this one keeps Hero's default cross-fade: the two ends are
/// different widgets (a round icon button and a labelled pill), so fading
/// between them reads as one control changing shape, while reusing the source
/// widget would leave the pill's label missing for the whole flight.
class ReadFabHero extends StatelessWidget {
  const ReadFabHero({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;
    return Hero(
      tag: kReadFabHeroTag,
      transitionOnUserGestures: true,
      child: child,
    );
  }
}
