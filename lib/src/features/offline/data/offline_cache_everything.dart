// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../constants/db_keys.dart';
import '../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../manga_book/data/manga_book/manga_book_repository.dart';
import '../../manga_book/domain/manga/manga_model.dart';
import 'offline_database.dart';
import 'offline_sync.dart';

/// Master switch for the full offline cache.
///
/// On: the whole library is mirrored to this device — manga metadata, chapter
/// lists and covers — the library is served from that local copy first, and the
/// server is checked in the background. Off: the shipped behaviour, where the
/// on-device catalog only covers series with downloaded files.
///
/// Hand-written rather than `@riverpod` so enabling it needs no code
/// generation run.
class OfflineCacheEverything extends Notifier<bool?>
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.offlineCacheEverything);
}

final offlineCacheEverythingProvider =
    NotifierProvider<OfflineCacheEverything, bool?>(
  OfflineCacheEverything.new,
);

/// When the full-cache library was last refreshed from the server.
///
/// The background refresh rebuilds the library provider when it lands, so
/// without this throttle that rebuild would immediately start another fetch —
/// a refresh loop. Held in a keep-alive provider instead of a static so it
/// resets with the app session.
class FullCacheRefreshClock extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void mark() => state = DateTime.now();
}

final fullCacheRefreshClockProvider =
    NotifierProvider<FullCacheRefreshClock, DateTime?>(FullCacheRefreshClock.new);

/// How stale the local copy may get before the background refresh runs again.
const kFullCacheRefreshInterval = Duration(minutes: 10);

/// Mirrors every library manga's chapter list into the on-device catalog, so a
/// series that was never opened still has its chapter list offline.
///
/// Background-only and deliberately gentle: bounded concurrency, one pass per
/// library load, and series that already have local chapters are skipped. A
/// failure (source hiccup, dropped connection) skips that series and lets the
/// next pass retry it.
Future<void> mirrorLibraryChapters({
  required OfflineSync? sync,
  required MangaBookRepository repository,
  required OfflineDatabase? db,
  required List<MangaDto> library,
  int concurrency = 3,
}) async {
  if (sync == null || db == null || library.isEmpty) return;

  final Set<int> alreadyMirrored;
  try {
    alreadyMirrored = {
      for (final entry in (await db.chapterCountByManga()).entries)
        if (entry.value > 0) entry.key,
    };
  } catch (_) {
    return;
  }

  final pending = [
    for (final manga in library)
      if (!alreadyMirrored.contains(manga.id)) manga.id,
  ];

  for (var i = 0; i < pending.length; i += concurrency) {
    final batch = pending.skip(i).take(concurrency);
    await Future.wait([
      for (final mangaId in batch)
        () async {
          try {
            final chapters = await repository.getChapterList(mangaId);
            if (chapters == null || chapters.isEmpty) return;
            await sync.syncChapters(chapters);
          } catch (_) {
            // Leave this series for the next pass.
          }
        }(),
    ]);
  }
}
