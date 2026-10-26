// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/manga_cover/list/manga_cover_descriptive_list_tile.dart';
import '../../../../../widgets/manga_cover/manga_cover_hero.dart';
import '../../../../library/presentation/library/controller/library_manga_list.dart';
import '../../../domain/manga/manga_model.dart';

/// The series page's frame, drawn while its data is still loading.
///
/// Two jobs. The cover Hero has to be present on the destination route *when
/// the transition starts*, otherwise the first push has nothing to fly into and
/// the animation appears to need a second visit. And the frame must not change
/// when the data lands: the cover is drawn from the shelf's cached entry with
/// the very widget the loaded page uses, at the same inset, so the artwork does
/// not blink or jump at the hand-over.
class MangaDetailsSkeleton extends ConsumerWidget {
  const MangaDetailsSkeleton({super.key, required this.mangaId});

  final int mangaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = _cachedManga(ref);
    final surface = context.theme.colorScheme.surfaceContainerHighest;
    Widget bar({double height = 44}) => Container(
      height: height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 8),
        children: [
          if (cached != null)
            MangaCoverDescriptiveListTile(
              manga: cached,
              showBadges: false,
              titleMaxLines: null,
            )
          else
            Padding(
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
                        color: surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
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
  /// which is the case where the cover has to land without a visible change.
  MangaDto? _cachedManga(WidgetRef ref) {
    final list = ref.watch(libraryMangaListProvider).value;
    if (list == null) return null;
    for (final manga in list) {
      if (manga.id == mangaId) return manga;
    }
    return null;
  }
}
