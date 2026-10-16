// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../domain/collection_model.dart';
import 'collection_controller.dart';
import 'collection_details_screen.dart';
import 'collection_editor_screen.dart';

/// Lists the user's collections and lets them create/edit/delete them.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    final notifier = ref.read(collectionsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.collections)),
      body: collections.isEmpty
          ? const _EmptyCollections()
          : ListView.separated(
              itemCount: collections.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final collection = collections[index];
                return _CollectionTile(
                  collection: collection,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CollectionDetailsScreen(collectionId: collection.id),
                    ),
                  ),
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CollectionEditorScreen(collectionId: collection.id),
                    ),
                  ),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.l10n.deleteCollectionQuestion),
                        content: Text(
                          context.l10n.deleteCollectionConfirm(collection.name),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(context.l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(context.l10n.delete),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await notifier.remove(collection.id);
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CollectionEditorScreen(collectionId: null),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.noCollectionsYet,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.noCollectionsHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Collection collection;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cover = collection.effectiveCoverUrl;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 56,
          child: (cover == null || cover.isEmpty)
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.collections_bookmark, size: 20),
                )
              : Image.network(
                  cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
                ),
        ),
      ),
      title: Text(collection.name),
      subtitle: Text('${collection.members.length} manga'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
          PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
        ],
      ),
      onTap: onOpen,
    );
  }
}
