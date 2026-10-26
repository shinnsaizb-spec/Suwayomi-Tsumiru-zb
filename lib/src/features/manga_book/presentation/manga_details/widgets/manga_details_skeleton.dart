// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/theme/brand.dart';
import '../../../../../widgets/read_fab_hero.dart';
import '../../../../offline/data/offline_repository.dart';
import '../../../../offline/data/server_reachability.dart';
import '../../../../offline/presentation/series_offline_button.dart';
import '../../../../../widgets/manga_cover/list/manga_cover_descriptive_list_tile.dart';
import '../../../../../widgets/manga_cover/manga_cover_hero.dart';
import '../../../../../widgets/server_image.dart';
import 'manga_action_button.dart';
import 'manga_rating_bar.dart';
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
      // Same expression the loaded page uses (`selectedChapters` is empty while
      // loading). When it is false the Scaffold consumes the status bar inset
      // for the app bar and the body starts below it — taking the opposite
      // branch here is what put the frame's contents up under the bar until the
      // data arrived.
      extendBodyBehindAppBar: !ref.watch(serverUnreachableProvider),
      // Same bar the loaded page shows at rest: transparent, no title, the same
      // scrim, and the same actions in the same order. The actions are inert
      // here, but drawn with live callbacks so they do not change colour when
      // the data arrives — a bar that grows three buttons mid-load is exactly
      // the flicker this frame exists to avoid.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x73000000), Colors.transparent],
            ),
          ),
        ),
        actions: [
          if (context.isTablet) ...[
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.category_rounded),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          ],
          // Download presets, then the chapter organizer, then the overflow —
          // the same three the loaded page shows on a phone.
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => const [],
          ),
        ],
      ),
      // Present from the first frame as well: the shelf's back-to-top button
      // morphs into this one, and a Hero needs a destination on the arriving
      // route.
      floatingActionButton: ReadFabHero(
        child: BrandFab(
          label: Text(context.l10n.start),
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: () {},
        ),
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
          // Action row: the real buttons in their default state, so only the
          // icons' "active" highlight changes once the data lands.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: MangaActionButton(
                    icon: const Icon(Icons.favorite_border_rounded),
                    label: context.l10n.addToLibrary,
                    onPressed: () {},
                  ),
                ),
                Expanded(
                  child: MangaActionButton(
                    icon: const Icon(Icons.sync_rounded),
                    label: context.l10n.tracking,
                    onPressed: () {},
                  ),
                ),
                if (ref.watch(offlineEnabledProvider))
                  Expanded(child: SeriesOfflineButton(mangaId: mangaId)),
                Expanded(
                  child: MangaActionButton(
                    icon: const Icon(Icons.public_rounded),
                    label: context.l10n.webView,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // The rating row is fixed furniture, and it reads its own provider
          // rather than the details query — so it is drawn for real here: the
          // label and five empty stars are on screen immediately, and the stars
          // light up as soon as the stored rating resolves.
          MangaRatingBar(mangaId: mangaId),
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
