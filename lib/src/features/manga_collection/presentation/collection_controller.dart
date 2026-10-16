// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/collection_repository.dart';
import '../domain/collection_model.dart';

class CollectionsNotifier extends Notifier<List<Collection>> {
  final CollectionRepository _repo = CollectionRepository();
  bool _loaded = false;

  @override
  List<Collection> build() {
    if (!_loaded) {
      _loaded = true;
      // Load persisted collections into state on first access.
      Future.microtask(_load);
    }
    return const [];
  }

  Future<void> _load() async {
    final loaded = await _repo.load();
    // The provider may be disposed before the async load resolves; assigning
    // to a disposed notifier is a no-op/throw depending on the Riverpod
    // version, so guard defensively.
    try {
      state = loaded;
    } catch (_) {}
  }

  Future<void> _persist() => _repo.save(state);

  Collection? byId(String id) {
    for (final c in state) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> add(Collection collection) async {
    state = [...state, collection];
    await _persist();
  }

  Future<void> update(Collection collection) async {
    state = [for (final c in state) c.id == collection.id ? collection : c];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _persist();
  }

  /// Builds a brand new collection with a stable local id.
  Collection newCollection({
    required String name,
    required List<CollectionMember> members,
    int? categoryId,
    String? coverUrl,
    int? coverMemberMangaId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Collection(
      id: 'col_$now',
      name: name.trim().isEmpty ? 'Collection' : name.trim(),
      members: members,
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
      coverUrl: coverUrl,
      coverMemberMangaId: coverMemberMangaId,
    );
  }
}

/// The collections that belong in [categoryId]'s library tab.
///
/// A collection with no category yet (`null`) is shown everywhere, which also
/// keeps collections saved before the field existed visible.
List<Collection> collectionsForCategory(List<Collection> all, int categoryId) =>
    [
      for (final c in all)
        if (c.categoryId == null || c.categoryId == categoryId) c,
    ];

/// The collections with no category, for the grouped (by source/status) views
/// that have no category to attach them to.
List<Collection> uncategorizedCollections(List<Collection> all) => [
      for (final c in all)
        if (c.categoryId == null) c,
    ];

final collectionsProvider =
    NotifierProvider<CollectionsNotifier, List<Collection>>(CollectionsNotifier.new);
