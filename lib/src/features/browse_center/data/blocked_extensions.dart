// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../constants/db_keys.dart';
import '../../../global_providers/global_providers.dart';

/// Extensions (plugins) the user blocked on this device.
///
/// Deliberately client-side: the server's `UserPermission` enum only has
/// coarse switches (`INSTALL_EXTENSIONS`, `UNINSTALL_EXTENSIONS`, …) and no
/// per-extension concept, so an admin cannot restrict which plugins a user may
/// use. This list is the local equivalent: every source belonging to a blocked
/// package is dropped from `browsableSourceListProvider`, which is what the
/// browse list, global search and bulk migration all read.
///
/// Stored as a plain `List<String>` of `pkgName`s in SharedPreferences, so it
/// survives restarts but is per-device and per-install (not synced).
final blockedExtensionPackagesProvider =
    NotifierProvider<BlockedExtensionPackages, Set<String>>(
      BlockedExtensionPackages.new,
    );

class BlockedExtensionPackages extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return {...?prefs.getStringList(DBKeys.blockedExtensionPackages.name)};
  }

  Future<void> setBlocked(String pkgName, bool blocked) async {
    if (pkgName.isEmpty) return;
    final next = {...state};
    if (blocked) {
      next.add(pkgName);
    } else {
      next.remove(pkgName);
    }
    if (next.length == state.length && next.containsAll(state)) return;
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(
          DBKeys.blockedExtensionPackages.name,
          next.toList()..sort(),
        );
  }

  Future<void> clear() async {
    state = const <String>{};
    await ref
        .read(sharedPreferencesProvider)
        .remove(DBKeys.blockedExtensionPackages.name);
  }
}
