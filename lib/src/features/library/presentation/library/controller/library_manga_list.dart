// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../features/offline/data/offline_cache_everything.dart';
import '../../../../../features/offline/data/offline_cover_warmer.dart';
import '../../../../../features/offline/data/offline_read_fallback.dart';
import '../../../../../features/offline/data/offline_repository.dart';
import '../../../../../features/offline/data/server_reachability.dart';
import '../../../../../utils/crash/diagnostics.dart';
import '../../../../../utils/crash/redact_tokens.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/manga_cover/providers/manga_cover_providers.dart';
import '../../../../auth/data/auth_credentials_store.dart';
import '../../../../manga_book/data/manga_book/manga_book_repository.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../data/category_repository.dart';

part 'library_manga_list.g.dart';

@riverpod
Future<List<MangaDto>?> libraryMangaList(Ref ref) async {
  final sessionCurrent = watchAuthSession(ref);
  bool current() => ref.mounted && sessionCurrent();
  final offlineDb = ref.watch(offlineReadDatabaseProvider);
  final categoryRepository = ref.watch(categoryRepositoryProvider);
  // The first unread chapter only feeds the "continue reading" button, off by
  // default; turning it on refetches the list with it.
  final withFirstUnread = ref
      .watch(showContinueReadingButtonProvider)
      .ifNull(false);
  // Captured before the await; touching ref after the async gap throws if this
  // provider was disposed mid-build. The keepAlive notifiers outlive it.
  final reachability = ref.read(serverUnreachableProvider.notifier);
  final connecting = ref.read(serverConnectingProvider.notifier);
  final sync = ref.read(offlineSyncProvider);
  final coverWarmer = ref.read(offlineCoverWarmerProvider.notifier);
  final bookRepository = ref.read(mangaBookRepositoryProvider);
  final cacheEverything = ref
      .watch(offlineCacheEverythingProvider)
      .ifNull(false);
  // Ordered against push acks: captured before the fetch goes out.
  final fetchGen = sync?.syncGeneration ?? 0;
  // Mirror only genuine server responses. Fallback DTOs are catalog echoes:
  // they already carry the unread correction (double-applied if written
  // back), and the DTO round-trip loses lastReadAt and real chapter numbers.
  var fromServer = false;
  final offlineFirst =
      ref.watch(viewOfflineNowProvider) || ref.watch(serverUnreachableProvider);

  // Full offline cache: hand the shelf its local copy immediately and check the
  // server in the background, so startup never waits on the network — and works
  // with none. Falls through to the normal network read while the catalog is
  // still empty (first run after enabling it).
  if (cacheEverything && !offlineFirst && offlineDb != null) {
    final cached = await offlineCatalogLibrary(db: offlineDb, fullCache: true);
    // Trigger the background mirror/refresh whenever one is due — even when the
    // catalog is still empty. On a freshly-enabled cache the drift mirror may
    // not be populated yet, so `cached` is empty; if the refresh were nested
    // inside `if (cached.isNotEmpty)` it would never run and the shelf would
    // stay empty until the user toggled the setting off and on again (the
    // reported "first enable shows No manga found, re-enable fixes it" bug).
    final lastRefresh = ref.read(fullCacheRefreshClockProvider);
    final refreshDue =
        lastRefresh == null ||
        DateTime.now().difference(lastRefresh) > kFullCacheRefreshInterval;
    if (refreshDue) {
      // Deferred past this build: Riverpod forbids modifying another provider
      // while this one is building (the same reason the reachability flip
      // below is deferred). The clock is marked before the fetch so the
      // rebuild it triggers can't start a second refresh.
      Future(() {
        if (!current()) return;
        try {
          ref.read(fullCacheRefreshClockProvider.notifier).mark();
        } catch (_) {}
        unawaited(() async {
          // The shelf already shows the local copy; the spinner in the app
          // bar is the only sign that the server is being checked behind it.
          void markConnecting(bool value) {
            try {
              connecting.set(value);
            } catch (_) {}
          }

          markConnecting(true);
          try {
            final fresh = await categoryRepository.getAllLibraryMangas(
              withFirstUnread: withFirstUnread,
            );
            if (!current()) return;
            if (fresh != null) {
              if (sync != null) {
                // Await the manga metadata + category-membership mirror
                // before the invalidateSelf below. These writes are what the
                // catalog-served shelf reads for its category buckets; if they
                // stayed fire-and-forget the rebuild raced ahead and read the
                // still-empty offline_manga_categories table, so every
                // library category rendered "No manga found" until a manual
                // refresh or the 10-minute cache clock. pruneRemoved/
                // coverWarm/mirrorChapters are heavier and don't affect
                // category display, so they stay deferred.
                final membershipSyncs = [
                  for (final manga in fresh)
                    sync.syncManga(manga, fetchedAtGen: fetchGen),
                ];
                unawaited(sync.pruneRemovedLibraryManga(fresh));
                await Future.wait(membershipSyncs);
              }
              unawaited(coverWarmer.warmLibraryCovers(fresh));
              unawaited(
                mirrorLibraryChapters(
                  sync: sync,
                  repository: bookRepository,
                  db: offlineDb,
                  library: fresh,
                ),
              );
              reachability.set(false, reason: 'library-full-cache');
            }
          } catch (_) {
            // Keep serving the local copy; the offline banner reports the
            // outage from here.
            if (current()) {
              reachability.set(true, reason: 'library-full-cache');
            }
          } finally {
            markConnecting(false);
            if (current()) ref.invalidateSelf();
          }
        }());
      });
    }
    if (cached != null && cached.isNotEmpty) {
      // A catalog whose series carry no category membership at all buckets
      // everything into the default tab (see `categoryMangaListProvider`), so
      // the other tabs look empty until the category pass lands — which the
      // refresh scheduled above repairs (it awaits its membership writes before
      // invalidating this provider).
      //
      // Do NOT fall through to the network read here instead: that path reports
      // reachability, and reachability is what this provider watches — with the
      // server down the two flip each other forever and the whole shelf
      // flickers. Serving the catalog keeps the feedback loop out.
      final catalogHasMemberships = cached.any(
        (m) => m.categories.nodes.isNotEmpty,
      );
      recordDiagnostic(
        '[${DateTime.now().toIso8601String()}] library-list: '
        'source=catalog(full-cache) manga=${cached.length}'
        '${catalogHasMemberships ? '' : ' incomplete=no-category-membership'}\n',
      );
      return cached;
    }
  }

  // Everything below needs the server: an empty on-device catalog has nothing
  // to fall back to, and an unadmitted auth session can't reach the server, so
  // bail here. This only fires when the local-catalog branch above did NOT
  // already return a populated shelf — i.e. when we truly have no local copy.
  // The "view offline" path still proceeds, because there libraryWithOffline
  // Fallback serves the local catalog without touching the server.
  if (!current() && !offlineFirst) return null;

  final List<MangaDto>? list;
  try {
    list = await libraryWithOfflineFallback(
      fetch: () async {
        // Set inside the fetch (never during this provider's build phase, which
        // Riverpod forbids) so the app bar can spin while it runs.
        void markConnecting(bool value) {
          try {
            connecting.set(value);
          } catch (_) {}
        }

        markConnecting(true);
        try {
          final r = await categoryRepository.getAllLibraryMangas(
            withFirstUnread: withFirstUnread,
          );
          fromServer = true;
          return r;
        } finally {
          markConnecting(false);
        }
      },
      // Only read the native-only DB when offline is available (never on web).
      db: offlineDb,
      offlineEnabled: offlineDb != null,
      offlineFirst: offlineFirst,
      // Full cache serves the whole catalogued library, not just the series
      // with files on this device.
      fullCache: cacheEverything,
      // Riverpod forbids modifying another provider while this one is building,
      // so defer the flip to a later tick (past the build) and ignore it if the
      // container is already gone.
      onReachability: (reachable) {
        Future(() {
          try {
            if (current()) {
              reachability.set(!reachable, reason: 'library-fetch');
            }
          } catch (_) {}
        });
      },
    );
  } catch (e) {
    // Connection errors never reach the provider-failure log, and this is the
    // list every library tab filters.
    recordDiagnostic(
      redactTokens(
        '[${DateTime.now().toIso8601String()}] library-list: failed '
        'offlineFirst=$offlineFirst error=${e.runtimeType}: $e\n',
      ),
    );
    rethrow;
  }
  if (!current()) return null;
  // Which list the library shows, each time it's rebuilt: the server's or the
  // on-device catalog (downloaded series only).
  recordDiagnostic(
    '[${DateTime.now().toIso8601String()}] library-list: '
    'source=${fromServer ? 'server' : 'catalog'} manga=${list?.length} '
    'offlineFirst=$offlineFirst\n',
  );
  if (list != null && fromServer) {
    if (sync != null) {
      for (final manga in list) {
        unawaited(sync.syncManga(manga, fetchedAtGen: fetchGen));
      }
      unawaited(sync.pruneRemovedLibraryManga(list));
    }
    // Top up missing library covers in the durable cover cache, so a series
    // never opened still has its cover when the server is unreachable.
    unawaited(coverWarmer.warmLibraryCovers(list));
    // Full cache also mirrors every series' chapter list, so an unopened series
    // still has its chapter list offline.
    if (cacheEverything) {
      unawaited(
        mirrorLibraryChapters(
          sync: sync,
          repository: bookRepository,
          db: offlineDb,
          library: list,
        ),
      );
    }
  }
  return list;
}
