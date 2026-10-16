// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../../../widgets/server_image.dart';
import '../domain/collection_model.dart';
import '../../library/domain/category/category_model.dart';
import '../../library/presentation/category/controller/edit_category_controller.dart';
import '../../library/presentation/library/controller/library_manga_list.dart';
import '../../manga_book/domain/manga/manga_model.dart';
import 'collection_controller.dart';

/// Create (collectionId == null) or edit a collection. Members are picked from
/// the user's library and each can be given a custom in-collection name.
class CollectionEditorScreen extends ConsumerStatefulWidget {
  const CollectionEditorScreen({super.key, this.collectionId});

  final String? collectionId;

  @override
  ConsumerState<CollectionEditorScreen> createState() =>
      _CollectionEditorScreenState();
}

class _CollectionEditorScreenState
    extends ConsumerState<CollectionEditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();

  // mangaId -> member snapshot (keeps title/thumbnailUrl/sourceId + custom name)
  final Map<int, CollectionMember> _selected = {};
  int? _coverMemberMangaId;

  /// Library category this collection is filed under (null = all categories).
  int? _categoryId;
  bool _loaded = false;

  /// Whether the user has typed a name of their own. Until they do, the name
  /// tracks the cover manga's title.
  bool _nameEdited = false;

  bool get _isEditing => widget.collectionId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  /// Defaults the collection's name to the cover manga's name — the common
  /// "these belong together" case then needs no typing. Stops as soon as the
  /// user types their own name (see [_nameEdited]).
  void _syncNameWithCover() {
    if (_nameEdited) return;
    final coverId = _coverMemberMangaId;
    _nameController.text = coverId == null
        ? ''
        : (_selected[coverId]?.displayName ?? '');
  }

  void _loadExisting() {
    if (_loaded || !_isEditing) {
      return;
    }
    _loaded = true;
    final existing = ref
        .read(collectionsProvider.notifier)
        .byId(widget.collectionId!);
    if (existing != null) {
      _nameController.text = existing.name;
      // A saved collection already has a name of its own — never let the cover
      // picker overwrite it.
      _nameEdited = true;
      _coverMemberMangaId = existing.coverMemberMangaId;
      _categoryId = existing.categoryId;
      _coverUrlController.text = existing.coverUrl ?? '';
      for (final m in existing.members) {
        _selected[m.mangaId] = m;
      }
    }
  }

  void _toggle(MangaDto manga) {
    setState(() {
      final id = manga.id;
      if (_selected.containsKey(id)) {
        _selected.remove(id);
        if (_coverMemberMangaId == id) {
          _coverMemberMangaId = _selected.isNotEmpty
              ? _selected.keys.first
              : null;
        }
      } else {
        _selected[id] = CollectionMember(
          mangaId: id,
          title: manga.title,
          displayName: manga.title,
          thumbnailUrl: manga.thumbnailUrl,
          sourceId: manga.sourceId ?? '',
          inLibrary: manga.inLibrary,
        );
        _coverMemberMangaId ??= id;
      }
      _syncNameWithCover();
    });
  }

  Future<void> _rename(int mangaId) async {
    final current = _selected[mangaId];
    if (current == null) {
      return;
    }
    final controller = TextEditingController(text: current.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.nameInCollection),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _selected[mangaId] = current.copyWith(displayName: result.trim());
        // The cover's title feeds the collection's default name, so keep them
        // in step while the name is still automatic.
        if (_coverMemberMangaId == mangaId) _syncNameWithCover();
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pleaseEnterName)));
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pickAtLeastOneManga)));
      return;
    }

    final notifier = ref.read(collectionsProvider.notifier);
    final members = _selected.values.toList();
    final coverUrl = _coverUrlController.text.trim();

    if (_isEditing) {
      final existing = notifier.byId(widget.collectionId!)!;
      await notifier.update(
        existing.copyWith(
          name: name,
          members: members,
          categoryId: _categoryId,
          coverMemberMangaId: _coverMemberMangaId,
          coverUrl: coverUrl.isEmpty ? null : coverUrl,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else {
      await notifier.add(
        notifier.newCollection(
          name: name,
          members: members,
          categoryId: _categoryId,
          coverMemberMangaId: _coverMemberMangaId,
          coverUrl: coverUrl.isEmpty ? null : coverUrl,
        ),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();
    final libraryAsync = ref.watch(libraryMangaListProvider);
    final library = libraryAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? context.l10n.editCollection : context.l10n.newCollection,
        ),
        actions: [TextButton(onPressed: _save, child: Text(context.l10n.save))],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameController,
              // Any typing means the name is the user's from now on, so the
              // cover picker stops rewriting it.
              onChanged: (value) => _nameEdited = value.trim().isNotEmpty,
              decoration: InputDecoration(
                labelText: context.l10n.collectionName,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          _SectionHeader(context.l10n.categories),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
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
          ),
          if (_selected.isNotEmpty) ...[
            _SectionHeader(context.l10n.cover),
            _CoverPicker(
              members: _selected.values.toList(),
              coverMemberMangaId: _coverMemberMangaId,
              coverUrlController: _coverUrlController,
              onPick: (id) => setState(() {
                _coverMemberMangaId = id;
                _coverUrlController.clear();
                _syncNameWithCover();
              }),
            ),
          ],
          _SectionHeader(context.l10n.addMangaFromLibrary),
          if (library == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (library.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(context.l10n.libraryIsEmpty)),
            )
          else
            ...library
                .where((m) => m.inLibrary)
                .map(
                  (manga) => _MangaPickRow(
                    manga: manga,
                    member: _selected[manga.id],
                    onToggle: () => _toggle(manga),
                    onRename: () => _rename(manga.id),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.members,
    required this.coverMemberMangaId,
    required this.coverUrlController,
    required this.onPick,
  });

  final List<CollectionMember> members;
  final int? coverMemberMangaId;
  final TextEditingController coverUrlController;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final m = members[index];
              final selected = m.mangaId == coverMemberMangaId;
              return GestureDetector(
                onTap: () => onPick(m.mangaId),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 60,
                      height: 84,
                      child: (m.thumbnailUrl == null || m.thumbnailUrl!.isEmpty)
                          ? const ColoredBox(color: Colors.grey)
                          : ServerImage(
                              imageUrl: m.thumbnailUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: coverUrlController,
            decoration: InputDecoration(
              labelText: context.l10n.orCoverImageUrl,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _MangaPickRow extends StatelessWidget {
  const _MangaPickRow({
    required this.manga,
    required this.member,
    required this.onToggle,
    required this.onRename,
  });

  final MangaDto manga;
  final CollectionMember? member;
  final VoidCallback onToggle;
  final VoidCallback onRename;

  bool get _isSelected => member != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Checkbox(value: _isSelected, onChanged: (_) => onToggle()),
          title: Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: member == null
              ? null
              : IconButton(
                  tooltip: context.l10n.rename,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onRename,
                ),
          onTap: onToggle,
        ),
        if (_isSelected)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.shownAs(member!.displayName),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}
