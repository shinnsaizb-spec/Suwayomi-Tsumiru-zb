// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../../../widgets/server_image.dart';
import '../../library/domain/category/category_model.dart';
import '../../library/presentation/category/controller/edit_category_controller.dart';
import '../../manga_book/domain/manga/manga_model.dart';
import '../domain/collection_model.dart';
import 'collection_controller.dart';

/// Bottom sheet opened from the library's multi-select bar: either create a
/// brand-new collection from the selected manga (with a cover picked from
/// their thumbnails) or add them to an existing collection.
///
/// [initialCategoryId] files a newly created collection into the category the
/// user opened the sheet from, so it lands where they are browsing.
Future<bool?> showAddToCollectionSheet(
  BuildContext context,
  List<MangaDto> selected, {
  int? initialCategoryId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddToCollectionSheet(
      selected: selected,
      initialCategoryId: initialCategoryId,
    ),
  );
}

class AddToCollectionSheet extends ConsumerStatefulWidget {
  const AddToCollectionSheet({
    super.key,
    required this.selected,
    this.initialCategoryId,
  });

  final List<MangaDto> selected;
  final int? initialCategoryId;

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  final TextEditingController _nameController = TextEditingController();

  /// 0 = menu, 1 = create new, 2 = add to existing.
  int _mode = 0;

  /// Manga picked as the new collection's cover; defaults to the first of the
  /// selection.
  int? _coverMangaId;

  /// Library category the new collection is filed under; `null` = no category,
  /// which shows the collection in every category.
  int? _categoryId;

  /// Whether the user typed a name of their own. Until they do, the name tracks
  /// the cover manga's title (see [_syncNameWithCover]).
  bool _nameEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.selected.isNotEmpty) {
      _coverMangaId = widget.selected.first.id;
      _syncNameWithCover();
    }
    _categoryId = widget.initialCategoryId;
  }

  /// Defaults the collection's name to the cover manga's name, so creating one
  /// needs no typing. Stops once the user types their own name.
  void _syncNameWithCover() {
    if (_nameEdited) return;
    final coverId = _coverMangaId;
    for (final manga in widget.selected) {
      if (manga.id == coverId) {
        _nameController.text = manga.title;
        return;
      }
    }
    _nameController.text = '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<CollectionMember> _membersFromSelection() => [
    for (final m in widget.selected)
      CollectionMember(
        mangaId: m.id,
        title: m.title,
        displayName: m.title,
        thumbnailUrl: m.thumbnailUrl,
        sourceId: m.sourceId ?? '',
        inLibrary: m.inLibrary,
      ),
  ];

  Future<void> _create() async {
    final members = _membersFromSelection();
    if (members.isEmpty) return;
    final notifier = ref.read(collectionsProvider.notifier);
    final coverId = _coverMangaId ?? members.first.mangaId;
    final name = _nameController.text.trim();
    final collection = notifier.newCollection(
      name: name.isEmpty
          ? '${context.l10n.collection} '
                '${ref.read(collectionsProvider).length + 1}'
          : name,
      members: members,
      categoryId: _categoryId,
      coverMemberMangaId: coverId,
    );
    await notifier.add(collection);
    if (!mounted) return;
    // Grab the messenger before popping: the sheet's context is defunct the
    // moment the route is popped, and ScaffoldMessenger.of() would throw.
    final messenger = ScaffoldMessenger.of(context);
    final created = context.l10n.createdCollection(collection.name);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(content: Text(created)));
  }

  Future<void> _addToExisting(Collection target) async {
    final have = target.members.map((m) => m.mangaId).toSet();
    final toAdd = _membersFromSelection()
        .where((m) => !have.contains(m.mangaId))
        .toList();
    if (toAdd.isEmpty) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.alreadyInCollection)));
      return;
    }
    await ref
        .read(collectionsProvider.notifier)
        .update(
          target.copyWith(
            members: [...target.members, ...toAdd],
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final added = context.l10n.addedMangaToCollection(
      toAdd.length,
      target.name,
    );
    Navigator.of(context).pop(true);
    messenger.showSnackBar(SnackBar(content: Text(added)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collections = ref.watch(collectionsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (_mode == 0) _menu(theme, collections.isEmpty),
            if (_mode == 1) _createForm(theme),
            if (_mode == 2) _existingList(theme, collections),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _menu(ThemeData theme, bool noCollections) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          context.l10n.addNMangaTo(widget.selected.length),
          style: theme.textTheme.titleMedium,
        ),
      ),
      ListTile(
        leading: const Icon(Icons.add_circle_outline_rounded),
        title: Text(context.l10n.createNewCollection),
        subtitle: Text(context.l10n.createNewCollectionSubtitle),
        onTap: () => setState(() => _mode = 1),
      ),
      ListTile(
        leading: const Icon(Icons.playlist_add_rounded),
        title: Text(context.l10n.addToExistingCollection),
        subtitle: noCollections ? Text(context.l10n.noCollectionsYet) : null,
        enabled: !noCollections,
        onTap: () => setState(() => _mode = 2),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _createForm(ThemeData theme) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            context.l10n.newCollection,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (value) => _nameEdited = value.trim().isNotEmpty,
            decoration: InputDecoration(
              labelText: context.l10n.collectionName,
              hintText: context.l10n.collectionNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        // Which library category the collection is filed under: the same
        // place a manga's categories decide where it shows up.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.categories, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(context.l10n.allCategories),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                  for (final c
                      in ref.watch(visibleCategoryListProvider).value ??
                          const <CategoryDto>[])
                    ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id.getValueOnNullOrNegative(),
                      onSelected: (_) => setState(
                        () => _categoryId = c.id.getValueOnNullOrNegative(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(context.l10n.pickTheCover),
        ),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.selected.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final manga = widget.selected[index];
              final picked = manga.id == _coverMangaId;
              return GestureDetector(
                onTap: () => setState(() {
                  _coverMangaId = manga.id;
                  _syncNameWithCover();
                }),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: picked
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 60,
                          height: 84,
                          child:
                              (manga.thumbnailUrl == null ||
                                  manga.thumbnailUrl!.isEmpty)
                              ? ColoredBox(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                    ),
                                  ),
                                )
                              : ServerImage(
                                  imageUrl: manga.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    if (picked)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: Text(context.l10n.create),
                onPressed: _create,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _existingList(ThemeData theme, List<Collection> collections) =>
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                context.l10n.addToCollection,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final c = collections[index];
                  final cover = c.effectiveCoverUrl;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 36,
                        height: 52,
                        child: (cover == null || cover.isEmpty)
                            ? ColoredBox(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(
                                  Icons.collections_bookmark,
                                  size: 18,
                                ),
                              )
                            : ServerImage(imageUrl: cover, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(c.name),
                    subtitle: Text('${c.members.length} manga'),
                    onTap: () => _addToExisting(c),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
}
