import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/note.dart';
import 'services/auth_service.dart';
import 'services/note_repository.dart';

/// ----------------------------------------------------------------------
/// Services
/// ----------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final noteRepositoryProvider = Provider<NoteRepository>(
      (ref) => NoteRepository(
    FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    ),
  ),
);
/// ----------------------------------------------------------------------
/// Auth state
/// ----------------------------------------------------------------------

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authServiceProvider).authStateChanges);

final uidProvider =
    Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

/// ----------------------------------------------------------------------
/// Notes (realtime Firestore stream)
/// ----------------------------------------------------------------------

final notesStreamProvider = StreamProvider<List<Note>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <Note>[]);
  return ref.watch(noteRepositoryProvider).watchAll(uid);
});

/// Convenience synchronous view (empty while loading).
final notesProvider = Provider<List<Note>>(
    (ref) => ref.watch(notesStreamProvider).value ?? const <Note>[]);

/// ----------------------------------------------------------------------
/// Write actions
/// ----------------------------------------------------------------------

class NoteActions {
  NoteActions(this._ref);
  final Ref _ref;

  String get _uid {
    final uid = _ref.read(uidProvider);
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  NoteRepository get _repo => _ref.read(noteRepositoryProvider);

  Future<void> upsert(Note n) {
    n.updatedAt = DateTime.now();
    return _repo.upsert(_uid, n);
  }

  Future<void> setFlags(
    Note n, {
    bool? favorite,
    bool? pinned,
    bool? archived,
    bool? deleted,
  }) {
    final c = n.copy();
    if (favorite != null) c.favorite = favorite;
    if (pinned != null) c.pinned = pinned;
    if (archived != null) c.archived = archived;
    if (deleted != null) c.deleted = deleted;
    return upsert(c);
  }

  Future<void> moveToTrash(Note n) => setFlags(n, deleted: true, pinned: false);
  Future<void> restore(Note n) => setFlags(n, deleted: false);
  Future<void> deleteForever(String id) => _repo.deleteForever(_uid, id);
  Future<void> emptyTrash() => _repo.emptyTrash(_uid);
  Future<void> purgeOldTrash() => _repo.purgeOldTrash(_uid);
}

final noteActionsProvider = Provider<NoteActions>((ref) => NoteActions(ref));

/// ----------------------------------------------------------------------
/// Home filters & search
/// ----------------------------------------------------------------------

/// 'all' | 'fav' | 'type:<name>' | 'tag:<tag>'
final homeFilterProvider = StateProvider<String>((ref) => 'all');
final searchQueryProvider = StateProvider<String>((ref) => '');

final allTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(notesProvider);
  final tags = <String>{};
  for (final n in notes.where((n) => !n.deleted && !n.archived)) {
    tags.addAll(n.tags);
  }
  final list = tags.toList()..sort();
  return list;
});

final visibleNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(notesProvider);
  final filter = ref.watch(homeFilterProvider);
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();

  var list = notes.where((n) => !n.deleted && !n.archived);

  if (filter == 'fav') {
    list = list.where((n) => n.favorite);
  } else if (filter.startsWith('type:')) {
    final t = filter.substring(5);
    list = list.where((n) => n.type.name == t);
  } else if (filter.startsWith('tag:')) {
    final t = filter.substring(4);
    list = list.where((n) => n.tags.contains(t));
  }

  if (q.isNotEmpty) {
    list = list.where((n) => n.searchable().contains(q));
  }

  final out = list.toList()
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  return out;
});

final archivedNotesProvider = Provider<List<Note>>((ref) {
  final out = ref
      .watch(notesProvider)
      .where((n) => n.archived && !n.deleted)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return out;
});

final trashedNotesProvider = Provider<List<Note>>((ref) {
  final out = ref.watch(notesProvider).where((n) => n.deleted).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return out;
});

/// ----------------------------------------------------------------------
/// Theme (persisted with shared_preferences — works on all platforms)
/// ----------------------------------------------------------------------

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final i = p.getInt('themeMode');
    if (i != null && i >= 0 && i < ThemeMode.values.length) {
      state = ThemeMode.values[i];
    }
  }

  Future<void> cycle() async {
    final next = ThemeMode
        .values[(state.index + 1) % ThemeMode.values.length];
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setInt('themeMode', next.index);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) => ThemeNotifier());
