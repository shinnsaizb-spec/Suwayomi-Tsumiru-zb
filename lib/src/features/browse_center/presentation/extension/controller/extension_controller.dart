// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../constants/db_keys.dart';
import '../../../../../constants/extension_visibility.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/mixin/shared_preferences_client_mixin.dart';
import '../../../../../utils/mixin/state_provider_mixin.dart';
import '../../../../settings/presentation/browse/widgets/show_nsfw_switch/show_nsfw_switch.dart';
import '../../../data/blocked_extensions.dart';
import '../../../data/extension_repository/extension_repository.dart';
import '../../../domain/content_rating.dart';
import '../../../domain/extension/extension_model.dart';

part 'extension_controller.g.dart';

@riverpod
Future<List<Extension>?> extension(Ref ref) {
  final result = ref
      .watch(extensionRepositoryProvider)
      .getExtensionListStream();
  ref.keepAlive();
  return result;
}

@riverpod
AsyncValue<Map<String, List<Extension>>> extensionMap(Ref ref) {
  final extensionMap = <String, List<Extension>>{};
  final extensionListData = ref.watch(extensionProvider);
  final extensionList = [...?extensionListData.value];
  final showNsfw = ref.watch(showNSFWProvider).ifNull(true);
  // Blocked packages are hidden from every bucket (installed, updates, by
  // language) so a blocked plugin cannot be browsed, updated or uninstalled
  // from here. The Sources filter screen still lists them to unblock.
  final blocked = ref.watch(blockedExtensionPackagesProvider);
  // Hardcoded allowlist for non-admin accounts; null = no restriction.
  final allowed = ref.watch(visibleExtensionPackagesProvider);
  for (final e in extensionList) {
    if (blocked.contains(e.pkgName)) continue;
    if (allowed != null && !allowed.contains(e.pkgName)) continue;
    if (!showNsfw && isNsfwFromWarning(e.contentWarning)) continue;
    if (e.isInstalled.ifNull()) {
      if (e.hasUpdate.ifNull()) {
        extensionMap.update(
          "update",
          (value) => [...value, e],
          ifAbsent: () => [e],
        );
      } else {
        extensionMap.update(
          "installed",
          (value) => [...value, e],
          ifAbsent: () => [e],
        );
      }
    } else {
      extensionMap.update(
        e.language?.code?.toLowerCase() ?? "other",
        (value) => [...value, e],
        ifAbsent: () => [e],
      );
    }
  }
  // Sort every bucket alphabetically by name. The server returns no meaningful
  // order (install order is unhelpful); this matches Suwayomi-WebUI, which
  // sorts each group by name.
  for (final list in extensionMap.values) {
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return extensionListData.copyWithData((p0) => extensionMap);
}

@riverpod
List<String> extensionFilterLangList(Ref ref) {
  final extensionMap = {...?ref.watch(extensionMapProvider).value};
  extensionMap.remove("installed");
  extensionMap.remove("update");
  return [...extensionMap.keys]..sort();
}

@riverpod
class ExtensionLanguageFilter extends _$ExtensionLanguageFilter
    with SharedPreferenceClientMixin<List<String>> {
  @override
  List<String>? build() => initialize(DBKeys.extensionLanguageFilter);
}

@riverpod
AsyncValue<Map<String, List<Extension>>> extensionMapFiltered(Ref ref) {
  final extensionMapFiltered = <String, List<Extension>>{};
  final extensionMapData = ref.watch(extensionMapProvider);
  final extensionMap = {...?extensionMapData.value};
  final enabledLangList = [...?ref.watch(extensionLanguageFilterProvider)];
  for (final e in enabledLangList) {
    if (extensionMap.containsKey(e)) extensionMapFiltered[e] = extensionMap[e]!;
  }
  return extensionMapData.copyWithData((p0) => extensionMapFiltered);
}

@riverpod
AsyncValue<Map<String, List<Extension>>> extensionMapFilteredAndQueried(
  Ref ref,
) {
  final extensionMapData = ref.watch(extensionMapFilteredProvider);
  final extensionMap = {...?extensionMapData.value};
  final query = ref.watch(extensionQueryProvider);
  if (query.isBlank) return extensionMapData;
  return extensionMapData.copyWithData(
    (e) => extensionMap.map<String, List<Extension>>(
      (key, value) => MapEntry(
        key,
        value.where((element) => element.name.query(query)).toList(),
      ),
    ),
  );
}

@riverpod
class ExtensionQuery extends _$ExtensionQuery with StateProviderMixin<String?> {
  @override
  String? build() => null;
}
