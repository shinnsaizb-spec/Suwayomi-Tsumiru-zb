// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../../../widgets/emoticons.dart';
import '../../../widgets/manga_cover/list/manga_cover_list_tile.dart';
import '../../../widgets/server_image.dart';
import '../../library/presentation/library/controller/library_manga_list.dart';
import '../../manga_book/domain/manga/manga_model.dart';
import '../../manga_book/presentation/manga_details/controller/manga_details_controller.dart';
import '../../manga_book/presentation/manga_details/widgets/add_to_library_category.dart';
import '../../manga_book/presentation/manga_details/widgets/manga_description.dart';
import '../../offline/data/offline_download_providers.dart';
import '../domain/collection_model.dart';
import 'collection_controller.dart';
import 'collection_editor_screen.dart';

/// A collection rendered as the cover manga's detail page: the same header
/// (cover, title, author, actions, rating, tags) of the manga chosen as the
/// collection's cover, with the collection's mangas listed where the chapter
/// list would be — as the library's own list rows.
///
/// Members are picked out of the collection by long-pressing one (or tapping
/// once a selection is active) and then using the remove action in the app bar,
/// the same shape the library uses for multi-select.
class CollectionDetailsScreen extends HookConsumerWidget {
  const CollectionDetailsScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    Collection? found;
    for (final c in collections) {
      if (c.id == collectionId) {
        found = c;
        break;
      }
    }

    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.collection)),
        body: Center(child: Text(context.l10n.collectionNotFound)),
      );
    }
    final collection = found;

    // The header belongs to the manga picked as the cover (falling back to the
    // first member), so the page reads exactly like that manga's own page.
    final coverMangaId =
        collection.coverMemberMangaId ??
        (collection.members.isNotEmpty
            ? collection.members.first.mangaId
            : null);
    if (coverMangaId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(collection.name)),
        body: Center(child: Text(context.l10n.noMangaInCollection)),
      );
    }

    final mangaAsync = ref.watch(mangaWithIdProvider(mangaId: coverMangaId));
    final library =
        ref.watch(libraryMangaListProvider).value ?? const <MangaDto>[];

    // Selection holds member mangaIds; empty means "no selection", in which
    // state a tap opens the manga instead.
    final selected = useState(<int>{});
    final selectionActive = selected.value.isNotEmpty;

    void toggleSelect(int mangaId) =>
        selected.value = selected.value.contains(mangaId)
        ? (selected.value..remove(mangaId))
        : {...selected.value, mangaId};

    Future<void> removeSelected() async {
      final doomed = selected.value;
      if (doomed.isEmpty) return;
      final remaining = [
        for (final m in collection.members)
          if (!doomed.contains(m.mangaId)) m,
      ];
      await ref
          .read(collectionsProvider.notifier)
          .update(
            collection.copyWith(
              members: remaining,
              // A removed cover re-points at the first survivor, or to none.
              coverMemberMangaId: doomed.contains(collection.coverMemberMangaId)
                  ? (remaining.isNotEmpty ? remaining.first.mangaId : null)
                  : collection.coverMemberMangaId,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      selected.value = const {};
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Removed ${doomed.length} manga from "${collection.name}"',
          ),
        ),
      );
    }

    void openEditor() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CollectionEditorScreen(collectionId: collection.id),
      ),
    );

    return Scaffold(
      appBar: selectionActive
          ? AppBar(
              leading: IconButton(
                tooltip: context.l10n.clearSelection,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => selected.value = const {},
              ),
              title: Text(context.l10n.nSelected(selected.value.length)),
              actions: [
                IconButton(
                  tooltip: context.l10n.selectAll,
                  icon: const Icon(Icons.select_all_rounded),
                  onPressed: () => selected.value = {
                    for (final m in collection.members) m.mangaId,
                  },
                ),
                IconButton(
                  tooltip: context.l10n.removeFromCollection,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: removeSelected,
                ),
              ],
            )
          : AppBar(
              title: Text(collection.name),
              actions: [
                IconButton(
                  tooltip: context.l10n.edit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: openEditor,
                ),
              ],
            ),
      body: mangaAsync.showUiWhenData(context, (manga) {
        if (manga == null) {
          return Emoticons(
            title: context.l10n.noMangaFound,
            button: TextButton(
              onPressed: () =>
                  ref.invalidate(mangaWithIdProvider(mangaId: coverMangaId)),
              child: Text(context.l10n.refresh),
            ),
          );
        }
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                child: MangaDescription(
                  manga: manga,
                  refresh: () async => ref.invalidate(
                    mangaWithIdProvider(mangaId: coverMangaId),
                  ),
                  removeMangaFromLibrary: () => removeMangaFromLibraryAndPurge(
                    ProviderScope.containerOf(context, listen: false),
                    coverMangaId,
                  ),
                  addMangaToLibrary: () =>
                      addMangaToLibraryWithCategory(ref, context, manga),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                title: Text('${collection.members.length} manga'),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final member = collection.members[index];
                final dto = library
                    .where((m) => m.id == member.mangaId)
                    .firstOrNull;
                if (dto == null) {
                  return _MemberSnapshotTile(
                    member: member,
                    selected:
                        selectionActive &&
                        selected.value.contains(member.mangaId),
                    onPressed: selectionActive
                        ? () => toggleSelect(member.mangaId)
                        : () => context.push('/manga/${member.mangaId}'),
                    onLongPress: () => toggleSelect(member.mangaId),
                  );
                }
                // The library's own row: cover, title, unread/download
                // badges. Long-press — or a tap once a selection is active —
                // picks the member out for removal.
                return MangaCoverListTile(
                  key: ValueKey<int>(dto.id),
                  manga: dto,
                  selected: selected.value.contains(dto.id),
                  showBadges: true,
                  showCountBadges: true,
                  onPressed: selectionActive
                      ? () => toggleSelect(dto.id)
                      : () => context.push('/manga/${dto.id}'),
                  onLongPress: () => toggleSelect(dto.id),
                  trailing: member.displayName != member.title
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            member.displayName,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      : null,
                );
              }, childCount: collection.members.length),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        );
      }),
    );
  }
}

/// A member the library no longer holds (removed, or the library has not
/// loaded): rendered from the snapshot taken when it was added.
class _MemberSnapshotTile extends StatelessWidget {
  const _MemberSnapshotTile({
    required this.member,
    required this.selected,
    required this.onPressed,
    required this.onLongPress,
  });

  final CollectionMember member;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = member.thumbnailUrl;
    return ListTile(
      selected: selected,
      trailing: const Icon(Icons.remove_circle_outline),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 56,
          child: (thumbnail == null || thumbnail.isEmpty)
              ? ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                )
              : ServerImage(imageUrl: thumbnail, fit: BoxFit.cover),
        ),
      ),
      title: Text(
        member.displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(context.l10n.notInLibrary),
      onTap: onPressed,
      onLongPress: onLongPress,
    );
  }
}
