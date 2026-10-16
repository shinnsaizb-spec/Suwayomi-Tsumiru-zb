import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../constants/enum.dart';
import '../../../global_providers/global_providers.dart';
import '../../account/data/account_providers.dart';
import '../../account/domain/account_access.dart';
import '../../offline/data/offline_cache_everything.dart';
import '../../offline/data/offline_repository.dart';
import '../../offline/data/server_reachability.dart';
import 'category_repository.dart';

final defaultCategoryIdProvider = FutureProvider<int?>((ref) async {
  if (ref.watch(authTypeKeyProvider) != AuthType.uiLogin) return 0;
  // Full cache is local-first too: waiting for the server to answer here would
  // stall the whole library behind a network timeout, which is exactly what the
  // cache is meant to avoid.
  final fullCache = ref.watch(offlineCacheEverythingProvider) ?? false;
  final viewOffline = ref.watch(viewOfflineNowProvider);
  final unreachable = ref.watch(serverUnreachableProvider);
  final db = ref.watch(offlineReadDatabaseProvider);
  if ((viewOffline || unreachable || fullCache) && db != null) {
    final categories = await db.allOfflineCategories();
    final defaults = categories.where((category) => category.isDefaultCategory);
    if (defaults.length == 1) return defaults.single.id;
    // Nothing on the device says which category is the default — the usual
    // cause being a full cache switched on before any category was mirrored.
    // Returning null here stranded the whole shelf: the category mirror is
    // seeded by a pass that needs a non-null id (so it could never seed
    // itself), and uncategorized series are bucketed into a category only when
    // its id equals this one — so every tab rendered "No manga found" until the
    // user toggled the cache off and on again. Fall through to the server
    // instead, unless this is a deliberate "view offline" (or the server is
    // known to be down), where a network answer isn't available anyway.
    if (viewOffline || unreachable) return null;
  }
  final capabilityFuture = ref.watch(
    accountAccessProvider.selectAsync((access) => access.capability),
  );
  final repository = ref.watch(categoryRepositoryProvider);
  // Never leave this provider in an error state: Riverpod retries a failed
  // build on a backoff, and every retry rebuilds all of the shelf's tabs — a
  // visible flicker. "I can't tell you the default id" is a normal answer here;
  // the callers already treat null as "no default".
  try {
    final capability = await capabilityFuture;
    return switch (capability) {
      AccountCapability.unsupported => 0,
      AccountCapability.supported => await repository.getDefaultCategoryId(),
      _ => null,
    };
  } catch (_) {
    return null;
  }
});

final settledDefaultCategoryIdProvider = Provider<int?>((ref) {
  final value = ref.watch(defaultCategoryIdProvider);
  return value.isLoading || value.hasError ? null : value.value;
});
