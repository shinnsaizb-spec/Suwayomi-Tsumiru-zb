// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import '../../../../../constants/enum.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../../manga_collection/domain/collection_model.dart';
import 'library_controller.dart';

/// Slots [collections] into an already-sorted manga list under the library's
/// active sort, so a collection sorts by the same rule as the manga beside it
/// instead of always sitting at the top.
///
/// The manga order itself is never recomputed — the provider chain already
/// sorted it, and re-sorting here could disagree with it. Only the collections
/// are ordered among themselves (by the same rule, over their members' values)
/// and merged in, so a collection lands where a series with the same numbers
/// would.
///
/// [descending] mirrors the library's direction preference: true is the
/// provider's default and means the primary key runs ascending, matching
/// [library_controller]'s own `sortDirToggle`.
List<Object> sortLibraryEntries({
  required List<MangaDto> manga,
  required List<Collection> collections,
  required MangaSort axis,
  required bool descending,
  required int seed,
  Map<int, MangaDto>? memberStatsFrom,
}) {
  if (collections.isEmpty) return List<Object>.from(manga);
  if (manga.isEmpty) return List<Object>.from(collections);

  // A library hides the manga that live in one of [collections], so [manga]
  // arrives filtered. The collections' sort keys still need those members'
  // numbers (unread sums, dates), which is what [memberStatsFrom] supplies.
  final byId = memberStatsFrom ?? {for (final m in manga) m.id: m};
  final toggle = descending ? 1 : -1;

  final orderedCollections = [...collections]
    ..sort((a, b) {
      final primary = _compareCollectionToCollection(
        a,
        b,
        axis: axis,
        toggle: toggle,
        seed: seed,
        byId: byId,
      );
      if (primary != 0) return primary;
      final byName = compareTitlesFolded(a.name, b.name);
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });

  // Two-pointer merge: the manga keep their order, collections interleave.
  final merged = <Object>[];
  var collectionIndex = 0;
  for (final entry in manga) {
    while (collectionIndex < orderedCollections.length) {
      final collection = orderedCollections[collectionIndex];
      final comparison = _compareCollectionToManga(
        collection,
        entry,
        axis: axis,
        toggle: toggle,
        seed: seed,
        byId: byId,
      );
      if (comparison > 0) break; // the collection belongs after this manga
      merged.add(collection);
      collectionIndex++;
    }
    merged.add(entry);
  }
  for (; collectionIndex < orderedCollections.length; collectionIndex++) {
    merged.add(orderedCollections[collectionIndex]);
  }
  return merged;
}

/// Reads a numeric field the server may send as an int or a String.
///
/// The DTO mixes both — `unreadCount` is an int while `inLibraryAt` and every
/// date field are Strings — and a catalog-served DTO re-encodes them. Without
/// this, comparing a collection's int key against a manga's String key throws
/// `type 'String' is not a subtype of type 'num'` and takes the whole library
/// down with it.
int _asInt(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v) ?? 0,
  _ => 0,
};

/// An epoch timestamp normalised to SECONDS.
///
/// The two sides of the date-added axis don't share a unit: a collection's
/// `createdAt` is Dart's `millisecondsSinceEpoch`, while the server's
/// `inLibraryAt` is a `LongString` whose unit depends on the server (epoch
/// seconds on some builds, milliseconds on others). Compared raw, one side
/// always sat ~1000x away from the other, so every collection was pinned to one
/// end of the shelf no matter the direction. 1e12 seconds is the year 33658, so
/// anything larger is milliseconds.
int _asEpochSeconds(Object? value) {
  final raw = _asInt(value);
  return raw > 1000000000000 ? raw ~/ 1000 : raw;
}

/// The collection's value on the active axis, as the same runtime type the
/// manga side produces for that axis (int or String), so the two are directly
/// comparable.
Comparable<Object> _collectionKey(
  Collection collection,
  MangaSort axis,
  int seed,
  Map<int, MangaDto> byId,
) {
  final members = [
    for (final member in collection.members)
      if (byId[member.mangaId] != null) byId[member.mangaId]!,
  ];
  int maxInt(int Function(MangaDto) read) {
    var best = 0;
    for (final m in members) {
      final value = read(m);
      if (value > best) best = value;
    }
    return best;
  }

  return switch (axis) {
    MangaSort.alphabetical => collection.name.toLowerCase(),
    // Summed, so a collection of unread series sorts where a series with that
    // many unread chapters would.
    MangaSort.unread => members.fold<int>(
      0,
      (sum, m) => sum + _asInt(m.unreadCount),
    ),
    MangaSort.dateAdded => _asEpochSeconds(collection.createdAt),
    MangaSort.totalChapters => collection.members.length,
    MangaSort.lastRead => maxInt((m) => _asInt(m.lastReadChapter?.lastReadAt)),
    MangaSort.lastUpdated => maxInt(
      (m) => _asInt(m.latestFetchedChapter?.fetchedAt),
    ),
    MangaSort.lastChapterDate => maxInt(
      (m) => _asInt(m.latestUploadedChapter?.uploadDate),
    ),
    MangaSort.lastUpdate => maxInt((m) => _asInt(m.chaptersLastFetchedAt)),
    // A collection carries no personal rating, so it sorts lowest, like an
    // unrated series.
    MangaSort.rating => 0,
    // Untracked, so it keeps the untracked series company at the end.
    MangaSort.trackerScore => 0,
    MangaSort.random => randomKey(collection.id.hashCode.abs(), seed),
  };
}

Comparable<Object> _mangaKey(MangaDto manga, MangaSort axis, int seed) =>
    switch (axis) {
      MangaSort.alphabetical => manga.title.toLowerCase(),
      MangaSort.unread => _asInt(manga.unreadCount),
      MangaSort.dateAdded => _asEpochSeconds(manga.inLibraryAt),
      MangaSort.totalChapters => _asInt(manga.chapters.totalCount),
      MangaSort.lastRead => _asInt(manga.lastReadChapter?.lastReadAt),
      MangaSort.lastUpdated => _asInt(manga.latestFetchedChapter?.fetchedAt),
      MangaSort.lastChapterDate => _asInt(
        manga.latestUploadedChapter?.uploadDate,
      ),
      MangaSort.lastUpdate => _asInt(manga.chaptersLastFetchedAt),
      MangaSort.rating => _asInt(manga.metaData.rating),
      MangaSort.trackerScore => 0,
      MangaSort.random => randomKey(manga.id, seed),
    };

/// The same special cases [library_controller]'s comparator applies, kept here
/// so a collection can't outrank a manga the library would have put first.
///
/// Defensive on purpose: this runs inside the sliver's build, so a throw here
/// blanks the library. A key pair that can't be compared — different runtime
/// types, or an axis added after this was written — counts as equal, which keeps
/// the shelf (and the order that was already sorted) on screen.
int _compareByAxis(
  Comparable<Object> a,
  Comparable<Object> b, {
  required MangaSort axis,
  required int toggle,
  required bool aIsCollection,
  required bool bIsCollection,
}) {
  switch (axis) {
    case MangaSort.random:
      // Direction is pinned for random, so the re-roll affordance isn't fought
      // by the direction toggle.
      return _safeCompare(a, b);
    case MangaSort.trackerScore:
      // Collections are untracked; untracked manga sort last too, so keep the
      // collection after a tracked manga and let two untracked entries fall
      // through to the title tie-break.
      if (aIsCollection && !bIsCollection) return 1;
      if (!aIsCollection && bIsCollection) return -1;
      return 0;
    case MangaSort.unread:
      final ua = _asInt(a);
      final ub = _asInt(b);
      if (ua == ub) return 0;
      // Zero unread sorts last in both directions.
      if (ua == 0) return 1;
      if (ub == 0) return -1;
      return ua.compareTo(ub) * toggle;
    default:
      return _safeCompare(a, b) * toggle;
  }
}

int _safeCompare(Comparable<Object> a, Comparable<Object> b) {
  if (a.runtimeType != b.runtimeType) return 0;
  try {
    return a.compareTo(b);
  } catch (_) {
    return 0;
  }
}

int _compareCollectionToCollection(
  Collection a,
  Collection b, {
  required MangaSort axis,
  required int toggle,
  required int seed,
  required Map<int, MangaDto> byId,
}) => _compareByAxis(
  _collectionKey(a, axis, seed, byId),
  _collectionKey(b, axis, seed, byId),
  axis: axis,
  toggle: toggle,
  aIsCollection: true,
  bIsCollection: true,
);

int _compareCollectionToManga(
  Collection collection,
  MangaDto manga, {
  required MangaSort axis,
  required int toggle,
  required int seed,
  required Map<int, MangaDto> byId,
}) => _compareByAxis(
  _collectionKey(collection, axis, seed, byId),
  _mangaKey(manga, axis, seed),
  axis: axis,
  toggle: toggle,
  aIsCollection: true,
  bIsCollection: false,
);
