// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/manga_cover/manga_cover_hero.dart';

/// The series page's frame, drawn while its data is still loading.
///
/// It exists for one reason beyond looking calm: the cover Hero has to be
/// present on the destination route *when the transition starts*. Without this
/// the first push had no Hero to fly into — the page only built its cover once
/// the query resolved — so the animation appeared to need a second visit. The
/// flight itself borrows the list's widget, so a placeholder box here is
/// enough; the real artwork takes over when the data lands.
class MangaDetailsSkeleton extends StatelessWidget {
  const MangaDetailsSkeleton({super.key, required this.mangaId});

  final int mangaId;

  static const double _coverWidth = 110;

  @override
  Widget build(BuildContext context) {
    final surface = context.theme.colorScheme.surfaceContainerHighest;
    Widget bar({double width = double.infinity, double height = 12}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 24,
          left: 16,
          right: 16,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MangaCoverHero(
                tag: mangaCoverHeroTag(mangaId),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: _coverWidth,
                    height: _coverWidth * 3 / 2,
                    child: ColoredBox(color: surface),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(height: 18),
                    const SizedBox(height: 10),
                    bar(width: 160),
                    const SizedBox(height: 10),
                    bar(width: 110),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < 8; i++) ...[
            bar(height: 44),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
