// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/account/data/account_providers.dart';
import '../features/account/domain/account_access.dart';

/// Hardcoded allowlist of extension packages (plugins) that **non-admin**
/// accounts are allowed to see.
///
/// Everything not listed here is hidden outright: its sources disappear from
/// browse, global search and bulk migration, and the extension itself
/// disappears from the Extensions screen. The user cannot override it — it is
/// compiled in.
///
/// Rules:
///
/// - **Empty set = restriction disabled.** Everyone sees everything. Keep it
///   empty unless you actually want to lock the server down.
/// - Only enforced when the server has the account system enabled **and** the
///   signed-in user is not an ADMIN. A single-user / no-login server is never
///   restricted, so you cannot lock yourself out of your own server.
/// - Match on `pkgName`, not the display name — plugins rename themselves.
///   The Sources filter screen prints each package id under the plugin name, so
///   you can copy it from there.
///
/// Example:
/// ```dart
/// const kMemberVisibleExtensionPackages = <String>{
///   'eu.kanade.tachiyomi.extension.all.mangadex',
///   'eu.kanade.tachiyomi.extension.zh.copymanga',
/// };
/// ```
const kMemberVisibleExtensionPackages = <String>{
  // Baozi Manhua / 包子漫画 — keiyoushi extensions-source `src/zh/baozimanhua`
  'eu.kanade.tachiyomi.extension.zh.baozimanhua',
  // BaoziManhuaPlus / 包子漫画+ — LittleSurvival/copymanga-copy20 repo. Listed
  // alongside the one above because both are "Baozi Manhua" to a reader, and
  // an extra id here is harmless when the extension is not installed.
  'eu.kanade.tachiyomi.extension.zh.baozimanhuaplus',
  // CopyManga / 拷贝漫画 — LittleSurvival/copymanga-copy20
  'eu.kanade.tachiyomi.extension.zh.copymanga',
  // Zaimanhua / 再漫画 — keiyoushi extensions-source `src/zh/zaimanhua`
  'eu.kanade.tachiyomi.extension.zh.zaimanhua',

  // The built-in Local source is a package too, so it is hidden for members
  // unless listed. Uncomment to keep it available:
  // 'eu.kanade.tachiyomi.source.local',
};

/// `null` means "no restriction". Otherwise only these packages are visible.
///
/// Note the deliberate fallbacks: no account system, or a session that has not
/// settled yet, both mean *unrestricted*. Filtering before the session settles
/// would make the whole browse list flicker on every launch, and there is
/// nothing to protect on a server without accounts.
final visibleExtensionPackagesProvider = Provider<Set<String>?>((ref) {
  if (kMemberVisibleExtensionPackages.isEmpty) return null;
  final access = ref.watch(settledAccountAccessProvider);
  if (access.capability != AccountCapability.supported) return null;
  if (access.canEditRoles) return null; // ADMIN sees everything.
  return kMemberVisibleExtensionPackages;
});
