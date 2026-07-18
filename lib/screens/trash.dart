import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../providers.dart';
import 'editor.dart';

enum BinMode { archive, trash }

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key, required this.mode});

  final BinMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrash = mode == BinMode.trash;
    final notes =
        ref.watch(isTrash ? trashedNotesProvider : archivedNotesProvider);
    final actions = ref.read(noteActionsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTrash ? 'Trash' : 'Archive'),
        actions: [
          if (isTrash && notes.isNotEmpty)
            IconButton(
              tooltip: 'Empty trash',
              icon: const Icon(Icons.delete_forever_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Empty trash?'),
                    content: const Text(
                        'All notes in the trash will be deleted permanently. This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete all')),
                    ],
                  ),
                );
                if (ok == true) actions.emptyTrash();
              },
            ),
        ],
      ),
      body: notes.isEmpty
          ? Center(
              child: Text(
                isTrash ? 'Trash is empty' : 'Nothing archived',
                style: TextStyle(color: cs.outline),
              ),
            )
          : ListView.separated(
              itemCount: notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final n = notes[i];
                return ListTile(
                  leading: Icon(noteTypeMeta[n.type]!.icon),
                  title: Text(n.title.isEmpty ? 'Untitled' : n.title),
                  subtitle: Text(
                    isTrash
                        ? 'Deleted ${relativeTime(n.updatedAt)} · auto-purges after 30 days'
                        : relativeTime(n.updatedAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: isTrash
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EditorScreen(existing: n))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isTrash ? 'Restore' : 'Unarchive',
                        icon: const Icon(Icons.restore_rounded),
                        onPressed: () => isTrash
                            ? actions.restore(n)
                            : actions.setFlags(n, archived: false),
                      ),
                      if (isTrash)
                        IconButton(
                          tooltip: 'Delete forever',
                          icon: Icon(Icons.delete_forever_outlined,
                              color: cs.error),
                          onPressed: () => actions.deleteForever(n.id),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
