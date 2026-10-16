// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/collection_model.dart';

/// Persists the user's [Collection]s locally as a single JSON blob in
/// SharedPreferences. Collections are a purely on-device concept, so there is
/// no server round-trip and it works offline by construction.
class CollectionRepository {
  static const String _key = 'tsumiru.collections.v1';

  Future<List<Collection>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return decoded.map(Collection.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<Collection> collections) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(collections.map((c) => c.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
