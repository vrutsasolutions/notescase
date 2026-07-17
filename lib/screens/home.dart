import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../providers.dart';
import 'delete_account_screen.dart';
import 'editor.dart';
import 'trash.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: purge trash older than 30 days.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noteActionsProvider).purgeOldTrash().catchError((_) {});
    });
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(existing: note)),
    );
  }

  void _newNote(NoteType type) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorScreen(
        existing: Note(id: const Uuid().v4(), type: type),
        isNew: true,
      ),
    ));
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child:
                    Text('New note', style: Theme.of(ctx).textTheme.titleLarge),
              ),
              for (final t in NoteType.values)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.secondaryContainer,
                    child: Icon(noteTypeMeta[t]!.icon,
                        color: Theme.of(ctx).colorScheme.onSecondaryContainer),
                  ),
                  title: Text(noteTypeMeta[t]!.label),
                  subtitle: Text(noteTypeMeta[t]!.blurb),
                  onTap: () {
                    Navigator.pop(ctx);
                    _newNote(t);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  IconData _themeIcon(ThemeMode m) => switch (m) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final notes = ref.watch(visibleNotesProvider);
    final filter = ref.watch(homeFilterProvider);
    final tags = ref.watch(allTagsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

    final usedTypes = <NoteType>{
      for (final n in ref.watch(notesProvider))
        if (!n.deleted && !n.archived) n.type
    };

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('NotesCase'),
              actions: [
                IconButton(
                  tooltip: 'Theme: ${themeMode.name}',
                  icon: Icon(_themeIcon(themeMode)),
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).cycle(),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'archive':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                const TrashScreen(mode: BinMode.archive)));
                        break;
                      case 'trash':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                const TrashScreen(mode: BinMode.trash)));
                        break;
                      case 'signout':
                        ref.read(authServiceProvider).signOut();
                        break;
                      case 'delete_account':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DeleteAccountScreen()));
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'archive', child: Text('Archive')),
                    const PopupMenuItem(value: 'trash', child: Text('Trash')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'signout', child: Text('Sign out')),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete_account',
                      child: Text(
                        'Delete my account & data',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SearchBar(
                  hintText: 'Search titles, content, tags…',
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).state = v,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip(filter, 'all', 'All'),
                    _chip(filter, 'fav', 'Favorites',
                        icon: Icons.star_rounded),
                    for (final t in NoteType.values)
                      if (usedTypes.contains(t))
                        _chip(filter, 'type:${t.name}', noteTypeMeta[t]!.label,
                            icon: noteTypeMeta[t]!.icon),
                    for (final tag in tags) _chip(filter, 'tag:$tag', '#$tag'),
                  ],
                ),
              ),
            ),

            // ---- realtime stream states: never silent ----
            if (notesAsync.isLoading && ref.watch(notesProvider).isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (notesAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 40, color: cs.error),
                        const SizedBox(height: 10),
                        const Text('Could not load notes'),
                        const SizedBox(height: 6),
                        Text(
                          '${notesAsync.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: cs.outline),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'If this mentions PERMISSION_DENIED, deploy the Firestore rules (see README).',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (notes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 48, color: cs.outline),
                        const SizedBox(height: 12),
                        Text('Your notebook is empty',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Add your first entry — a thought, a Wi-Fi password, anything worth keeping.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 700 ? 3 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childCount: notes.length,
                  itemBuilder: (ctx, i) => NoteCard(
                    note: notes[i],
                    onTap: () => _openNote(notes[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTemplatePicker,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
    );
  }

  Widget _chip(String current, String value, String label, {IconData? icon}) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        avatar: icon != null && !selected ? Icon(icon, size: 16) : null,
        onSelected: (_) => ref.read(homeFilterProvider.notifier).state =
            selected ? 'all' : value,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Note card
/// ---------------------------------------------------------------------------

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = noteTypeMeta[note.type]!;
    final tint = noteColors[note.colorIndex >= 0 &&
            note.colorIndex < noteColors.length
        ? note.colorIndex
        : 0];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = tint == null
        ? cs.surfaceContainerLow
        : Color.alphaBlend(
            tint.withValues(alpha: isDark ? 0.16 : 0.45), cs.surfaceContainerLow);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meta.icon, size: 15, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meta.label.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.favorite)
                    Icon(Icons.star_rounded, size: 15, color: cs.tertiary),
                  if (note.pinned)
                    Icon(Icons.push_pin_rounded, size: 14, color: cs.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (note.preview().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    note.preview(),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: cs.onSurfaceVariant),
                  ),
                ),
              if (note.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final t in note.tags.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('#$t',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: cs.onSecondaryContainer)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(relativeTime(note.updatedAt),
                  style: TextStyle(fontSize: 11, color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }
}