// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/manga_cover/list/manga_cover_descriptive_list_tile.dart';
import '../../../../../widgets/manga_cover/manga_cover_hero.dart';
import '../../../../../widgets/server_image.dart';
import '../../../../library/presentation/library/controller/library_manga_list.dart';
import '../../../domain/manga/manga_model.dart';

/// The series page's frame, drawn while its data is still loading.
///
/// Three jobs:
/// 1. the cover Hero has to be on the destination route *when the transition
///    starts*, or the first push has nothing to fly into and the animation
///    appears to need a second visit;
/// 2. it has to look like the page it becomes — same blurred backdrop, same
///    cover block, same action row — so the arrival does not jump;
/// 3. nothing in it may change when the data lands, which is why the cover and
///    the backdrop are drawn from the shelf's cached series.
///
/// It also keeps a transparent app bar with the back button, so the page can be
/// left while it is still loading.
class MangaDetailsSkeleton extends ConsumerWidget {
  const MangaDetailsSkeleton({super.key, required this.mangaId});

  final int mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = _cachedManga(ref);
    final scheme = context.theme.colorScheme;
    final surface = scheme.surface;
    final placeholder = scheme.surfaceContainerHighest;
    final hasCover = cached?.thumbnailUrl.isNotBlank ?? false;

    Widget bar({double height = 44, double width = double.infinity}) =>
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: placeholder,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // The immersive header: blurred cover, accent tint, then the cover and
          // title block — the same stack the loaded page draws, so the backdrop
          // does not appear out of nowhere when the data arrives.
          Stack(
            children: [
              if (hasCover)
                Positioned.fill(
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: ServerImage(
                        imageUrl: cached!.thumbnailUrl ?? '',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(child: ColoredBox(color: placeholder)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.30),
                        surface.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surface.withValues(alpha: 0.10),
                        surface.withValues(alpha: 0.70),
                        surface,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 8,
                ),
                child: cached != null
                    ? MangaCoverDescriptiveListTile(
                        manga: cached,
                        showBadges: false,
                        titleMaxLines: null,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: MangaCoverHero(
                            tag: mangaCoverHeroTag(mangaId),
                            child: SizedBox(
                              width: 110,
                              height: 165,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: placeholder,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const Positioned.fill(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 8),
          // Action row: four equal columns, matching the loaded page's buttons.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: placeholder,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        bar(height: 8, width: 40),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 8; i++) ...[
                  bar(),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The shelf's copy of this series, when the page was opened from the shelf —
  /// the case where the cover has to land without a visible change.
  MangaDto? _cachedManga(WidgetRef ref) {
    final list = ref.watch(libraryMangaListProvider).value;
    if (list == null) return null;
    for (final manga in list) {
      if (manga.id == mangaId) return manga;
    }
    return null;
  }
}
