// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';

import '../../../constants/app_sizes.dart';
import '../../../constants/enum.dart';
import '../../../widgets/server_image.dart';
import '../domain/collection_model.dart';

/// A collection drawn as a library grid cell: the same cover-first shape a
/// manga takes, so collections and manga sit next to each other in one grid.
///
/// A small badge marks it as a collection (so it is never mistaken for a
/// manga), and the member count is shown on the cover.
class CollectionGridTile extends StatelessWidget {
  const CollectionGridTile({
    super.key,
    required this.collection,
    this.onTap,
    this.showTitle = true,
    this.titleBelow = false,
    this.gridStyle = LibraryGridStyle.uniform,
  });

  final Collection collection;
  final VoidCallback? onTap;
  final bool showTitle;

  /// Comfortable grid: the title renders under the cover instead of overlaid.
  final bool titleBelow;

  /// Cover geometry. Uniform cells fill the cell they are given; the freeform
  /// styles take their height from a 2:3 box instead.
  final LibraryGridStyle gridStyle;

  bool get _freeform => gridStyle.isFreeform;

  @override
  Widget build(BuildContext context) {
    final cover = _cover(context);
    if (titleBelow) {
      return InkWell(
        onTap: onTap,
        child: _freeform
            // Freeform delegates leave the tile's height to the tile, so the
            // cover has to carry its own 2:3 box.
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 2 / 3, child: cover),
                  _titleSlot(context),
                ],
              )
            // The uniform delegate reserves kGridTitleExtent for the title.
            : Column(
                children: [Expanded(child: cover), _titleSlot(context)],
              ),
      );
    }

    final stacked = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          cover,
          Positioned(top: 4, right: 4, child: _collectionBadge(context)),
          if (showTitle)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _overlayTitle(context),
            ),
        ],
      ),
    );
    return InkWell(
      onTap: onTap,
      child: _freeform
          ? AspectRatio(aspectRatio: 2 / 3, child: stacked)
          : stacked,
    );
  }

  Widget _cover(BuildContext context) {
    final theme = Theme.of(context);
    final cover = collection.effectiveCoverUrl;
    return (cover == null || cover.isEmpty)
        ? ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.collections_bookmark_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : ServerImage(imageUrl: cover, fit: BoxFit.cover);
  }

  /// Marks the entry as a collection rather than a single manga.
  Widget _collectionBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.collections_bookmark_rounded,
        size: 12,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _overlayTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Text(
        collection.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }

  /// A fixed-height slot keeps the cell from overflowing at large text scales
  /// (same reason the manga tile computes its title height up front).
  Widget _titleSlot(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: kGridTitleExtent,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${collection.members.length} manga',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list-layout counterpart of [CollectionGridTile], for the library's list
/// and descriptive-list display modes.
class CollectionListTile extends StatelessWidget {
  const CollectionListTile({
    super.key,
    required this.collection,
    this.onTap,
    this.descriptive = false,
  });

  final Collection collection;
  final VoidCallback? onTap;

  /// Descriptive rows give the cover more room, like the manga counterpart.
  final bool descriptive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = collection.effectiveCoverUrl;
    final height = descriptive ? 132.0 : 56.0;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: height * 2 / 3,
          height: height,
          child: (cover == null || cover.isEmpty)
              ? ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.collections_bookmark_rounded),
                  ),
                )
              : ServerImage(imageUrl: cover, fit: BoxFit.cover),
        ),
      ),
      title: Text(
        collection.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Icon(
            Icons.collections_bookmark_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text('${collection.members.length} manga'),
        ],
      ),
    );
  }
}
