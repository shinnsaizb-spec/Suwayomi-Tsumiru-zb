// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';

/// A single manga that lives inside a [Collection]. `displayName` is what the
/// user renamed it to inside the collection (falls back to `title`). The
/// metadata (`title`, `thumbnailUrl`, `sourceId`) is a snapshot taken when the
/// manga is added, so the collection can render even before the library is
/// (re)fetched from the server.
@immutable
class CollectionMember {
  const CollectionMember({
    required this.mangaId,
    required this.title,
    required this.displayName,
    required this.thumbnailUrl,
    required this.sourceId,
    required this.inLibrary,
  });

  final int mangaId;
  final String title;
  final String displayName;
  final String? thumbnailUrl;
  final String sourceId;
  final bool inLibrary;

  CollectionMember copyWith({String? displayName}) => CollectionMember(
        mangaId: mangaId,
        title: title,
        displayName: displayName ?? this.displayName,
        thumbnailUrl: thumbnailUrl,
        sourceId: sourceId,
        inLibrary: inLibrary,
      );

  Map<String, dynamic> toJson() => {
        'mangaId': mangaId,
        'title': title,
        'displayName': displayName,
        'thumbnailUrl': thumbnailUrl,
        'sourceId': sourceId,
        'inLibrary': inLibrary,
      };

  static CollectionMember fromJson(Map<String, dynamic> json) => CollectionMember(
        mangaId: (json['mangaId'] as num).toInt(),
        title: (json['title'] as String?) ?? '',
        displayName: (json['displayName'] as String?) ?? (json['title'] as String? ?? ''),
        thumbnailUrl: json['thumbnailUrl'] as String?,
        sourceId: (json['sourceId'] as String?) ?? '',
        inLibrary: (json['inLibrary'] as bool?) ?? true,
      );
}

/// A user-made bundle of several mangas. Shown in the library/settings as one
/// entry; opening it reveals the member mangas as a horizontal row of covers
/// (see the collection details screen).
/// Sentinel so [Collection.copyWith] can tell "leave the category alone" from
/// "clear the category" — a plain `int?` can't express both.
const Object _unsetCategory = Object();

@immutable
class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.coverUrl,
    this.coverMemberMangaId,
  });

  final String id;
  final String name;
  final List<CollectionMember> members;
  final int createdAt;
  final int updatedAt;

  /// The library category this collection lives in, so it shows up inside that
  /// category alongside the manga. `null` means "no category chosen yet" and is
  /// treated as visible in every category (also how pre-existing collections
  /// saved before this field existed are read).
  final int? categoryId;

  /// Optional explicit cover override (e.g. an image URL). When null, the
  /// cover comes from [coverMemberMangaId], else the first member.
  final String? coverUrl;
  final int? coverMemberMangaId;

  String? get effectiveCoverUrl {
    if (coverUrl != null && coverUrl!.isNotEmpty) return coverUrl;
    if (members.isEmpty) return null;
    final match = members.where((m) => m.mangaId == coverMemberMangaId);
    final m = match.isNotEmpty ? match.first : members.first;
    return m.thumbnailUrl;
  }

  Collection copyWith({
    String? name,
    List<CollectionMember>? members,
    Object? categoryId = _unsetCategory,
    String? coverUrl,
    int? coverMemberMangaId,
    int? updatedAt,
  }) =>
      Collection(
        id: id,
        name: name ?? this.name,
        members: members ?? this.members,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        categoryId: categoryId == _unsetCategory
            ? this.categoryId
            : categoryId as int?,
        coverUrl: coverUrl ?? this.coverUrl,
        coverMemberMangaId: coverMemberMangaId ?? this.coverMemberMangaId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'categoryId': categoryId,
        'coverUrl': coverUrl,
        'coverMemberMangaId': coverMemberMangaId,
      };

  static Collection fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Collection(
      id: (json['id'] as String?) ?? '$now',
      name: (json['name'] as String?) ?? 'Collection',
      members: ((json['members'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CollectionMember.fromJson)
          .toList(),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? now,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? now,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      coverUrl: json['coverUrl'] as String?,
      coverMemberMangaId: (json['coverMemberMangaId'] as num?)?.toInt(),
    );
  }
}
